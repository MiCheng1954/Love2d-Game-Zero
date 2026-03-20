#!/usr/bin/env python3
"""
tests/run_lupa.py
用 lupa（Python 的 Lua 5.4 绑定）运行 busted 风格的测试文件。
自实现最小的 describe/it/before_each/assert 框架。
"""

import sys
import os
from lupa import LuaRuntime

# 项目根目录（此脚本在 tests/ 下，root = 上一级）
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

PASS  = "[PASS]"
FAIL  = "[FAIL]"

results = {"pass": 0, "fail": 0, "errors": []}

def make_runtime():
    """每个测试文件创建一个新的 Lua runtime，隔离状态"""
    lua = LuaRuntime(unpack_returned_tuples=True)

    # 修正 package.path，指向项目根目录
    lua.execute(f"""
        package.path = [[{ROOT}/?.lua;{ROOT}/?/init.lua;]] .. package.path
    """)

    # 注入 love stub（最小版本）
    lua.execute("""
        love = {}
        local noop = function() end
        local noop_mt = { __index = function() return noop end }
        love.graphics = setmetatable({}, noop_mt)
        love.timer    = { getFPS=function() return 60 end, getTime=function() return 0 end }
        love.keyboard = { isDown=function() return false end }
        love.window   = setmetatable({}, noop_mt)
        love.filesystem = setmetatable({}, noop_mt)
        love.math     = { random=math.random, randomseed=math.randomseed }
        love.audio    = setmetatable({}, noop_mt)
    """)

    # 注入 T() i18n stub
    lua.execute("T = function(key, ...) return key end")

    # ── 自实现 busted 风格框架 ──────────────────────────────────────
    lua.execute("""
        -- 测试状态
        _test_results  = { pass=0, fail=0, errors={} }
        _describe_stack = {}
        _before_each_stack = {}
        _current_before_each = {}

        function describe(name, fn)
            table.insert(_describe_stack, name)
            table.insert(_before_each_stack, _current_before_each)
            _current_before_each = {}
            fn()
            _current_before_each = table.remove(_before_each_stack)
            table.remove(_describe_stack)
        end

        function before_each(fn)
            table.insert(_current_before_each, fn)
        end

        function it(name, fn)
            -- 构造完整测试名
            local parts = {}
            for _, s in ipairs(_describe_stack) do table.insert(parts, s) end
            table.insert(parts, name)
            local full = table.concat(parts, " > ")

            -- 运行所有 before_each（按栈顺序）
            for _, beFns in ipairs(_before_each_stack) do
                for _, beFn in ipairs(beFns) do beFn() end
            end
            for _, beFn in ipairs(_current_before_each) do beFn() end

            -- 运行测试
            local ok, err = pcall(fn)
            if ok then
                _test_results.pass = _test_results.pass + 1
                io.write("  PASS  " .. full .. "\\n")
            else
                _test_results.fail = _test_results.fail + 1
                table.insert(_test_results.errors, {name=full, err=tostring(err)})
                io.write("  FAIL  " .. full .. "\\n")
                io.write("        " .. tostring(err) .. "\\n")
            end
            io.flush()
        end

        -- ── assert 扩展 ──────────────────────────────────────────────
        -- 保留原生 assert 函数，并扩展为同时支持函数调用和方法调用
        local _native_assert = assert  -- 保存 Lua 内置 assert

        local _assert_methods = {
            is_true = function(v, msg)
                if v ~= true then error(msg or ("expected true, got " .. tostring(v)), 2) end
            end,
            is_false = function(v, msg)
                if v ~= false then error(msg or ("expected false, got " .. tostring(v)), 2) end
            end,
            is_nil = function(v, msg)
                if v ~= nil then error(msg or ("expected nil, got " .. tostring(v)), 2) end
            end,
            is_not_nil = function(v, msg)
                if v == nil then error(msg or "expected non-nil, got nil", 2) end
            end,
            equals = function(expected, actual, msg)
                if expected ~= actual then
                    error(msg or ("expected " .. tostring(expected) .. ", got " .. tostring(actual)), 2)
                end
            end,
            is_near = function(expected, actual, eps, msg)
                eps = eps or 1e-6
                if math.abs(expected - actual) > eps then
                    error(msg or string.format("expected ~%.6f, got %.6f (eps=%.6f)", expected, actual, eps), 2)
                end
            end,
            has_error = function(fn, msg)
                local ok = pcall(fn)
                if ok then error(msg or "expected an error but none was raised", 2) end
            end,
            has_no_error = function(fn, msg)
                local ok, err = pcall(fn)
                if not ok then error(msg or ("expected no error, got: " .. tostring(err)), 2) end
            end,
        }

        -- 设置 __call 元方法让 assert(v, msg) 仍然可用
        setmetatable(_assert_methods, {
            __call = function(_, v, msg)
                return _native_assert(v, msg)
            end
        })

        assert = _assert_methods
    """)

    return lua


TEST_FILES = [
    "tests/entities/test_weapon.lua",
    "tests/systems/test_bag.lua",
    "tests/systems/test_adjacency.lua",
    "tests/systems/test_synergy.lua",
    "tests/systems/test_fusion.lua",
]

total_pass = 0
total_fail = 0
all_errors = []

for rel_path in TEST_FILES:
    path = os.path.join(ROOT, rel_path)
    print(f"\n{'='*60}")
    print(f"  {rel_path}")
    print('='*60)

    lua = make_runtime()
    try:
        with open(path, "r", encoding="utf-8") as f:
            src = f.read()
        lua.execute(src)
        p       = lua.eval("_test_results.pass")
        f_count = lua.eval("_test_results.fail")
        err_len = lua.eval("#_test_results.errors")
        total_pass += p
        total_fail += f_count
        for i in range(1, err_len + 1):
            name = lua.eval(f"_test_results.errors[{i}].name")
            err  = lua.eval(f"_test_results.errors[{i}].err")
            all_errors.append(f"[{rel_path}] {name}\n  {err}")
        print(f"  --> {p} passed, {f_count} failed")
    except Exception as ex:
        total_fail += 1
        msg = f"[{rel_path}] RUNTIME ERROR: {ex}"
        all_errors.append(msg)
        print(f"  RUNTIME ERROR: {ex}")

print(f"\n{'='*60}")
print(f"  TOTAL: {total_pass} passed, {total_fail} failed")
print('='*60)

if all_errors:
    print("\nFailed tests:")
    for e in all_errors:
        print(f"  {FAIL} {e}")
    sys.exit(1)
else:
    print(f"\n  {PASS} All tests passed!")
    sys.exit(0)
