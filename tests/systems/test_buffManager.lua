--[[
    tests/systems/test_buffManager.lua
    BuffManager 系统单元测试 — Phase 10.1
    覆盖：timer 增删改、刷新策略、stack 操作、getAll、clear
]]

require("tests.helper")
local BuffManager = require("src.systems.buffManager")

-- 最小玩家 stub
local function newPlayer()
    return {
        attack       = 10,
        pickupRadius = 80,
        _shieldActive   = false,
        _shieldAbsorbed = false,
    }
end

describe("BuffManager", function()

    local bm, player

    before_each(function()
        bm     = BuffManager.new()
        player = newPlayer()
    end)

    -- ============================================================
    -- 基础 Timer 型操作
    -- ============================================================
    describe("Timer 型 — add / has / remove", function()

        it("add() 激活 timer Buff，has() 返回 true", function()
            bm:add("invincible", 3.0, {}, player)
            assert.is_true(bm:has("invincible"))
        end)

        it("add() 首次激活调用 onApply（battle_cry 攻击力×2）", function()
            bm:add("battle_cry", 10.0, {}, player)
            assert.equals(20, player.attack)  -- 10 * 2
        end)

        it("remove() 立即移除，has() 返回 false", function()
            bm:add("invincible", 3.0, {}, player)
            bm:remove("invincible", player)
            assert.is_false(bm:has("invincible"))
        end)

        it("remove() 调用 onRemove（battle_cry 攻击力还原）", function()
            bm:add("battle_cry", 10.0, {}, player)
            assert.equals(20, player.attack)   -- 激活后
            bm:remove("battle_cry", player)
            assert.equals(10, player.attack)   -- 还原
        end)

        it("remove() 不存在的 Buff 不报错", function()
            bm:remove("nonexistent", player)   -- 应无错误
            assert.is_false(bm:has("nonexistent"))
        end)

        it("get() 返回 entry，包含 remaining 字段", function()
            bm:add("invincible", 5.0, {}, player)
            local entry = bm:get("invincible")
            assert.is_not_nil(entry)
            assert.is_true(entry.remaining > 0)
        end)

    end)

    -- ============================================================
    -- 刷新策略（max(remaining, duration)，不重复调用 onApply）
    -- ============================================================
    describe("Timer 型 — 刷新策略", function()

        it("刷新时取 max(remaining, duration)", function()
            bm:add("invincible", 10.0, {}, player)
            -- 过 3 秒后还剩 7 秒，再用 5s 刷新，应保持 7s（max(7, 5)=7）
            bm:update(3.0, player)
            bm:add("invincible", 5.0, {}, player)
            local entry = bm:get("invincible")
            assert.is_true(entry.remaining >= 6.9)   -- 约等于 7
        end)

        it("刷新时若新 duration 更大，则覆盖为更大值", function()
            bm:add("invincible", 5.0, {}, player)
            bm:update(2.0, player)  -- 剩 3s
            bm:add("invincible", 8.0, {}, player)  -- max(3, 8) = 8
            local entry = bm:get("invincible")
            assert.is_true(entry.remaining >= 7.9)
        end)

        it("刷新不重复调用 onApply（battle_cry 不再×2）", function()
            bm:add("battle_cry", 10.0, {}, player)
            assert.equals(20, player.attack)   -- 第一次 ×2
            bm:add("battle_cry", 10.0, {}, player)
            assert.equals(20, player.attack)   -- 不应再 ×2
        end)

    end)

    -- ============================================================
    -- Timer 型 — update 倒计时与到期
    -- ============================================================
    describe("Timer 型 — update 倒计时", function()

        it("update 后 remaining 减少", function()
            bm:add("invincible", 5.0, {}, player)
            bm:update(2.0, player)
            local entry = bm:get("invincible")
            assert.is_true(entry.remaining < 4.0)
        end)

        it("到期后 has() 返回 false", function()
            bm:add("invincible", 1.0, {}, player)
            bm:update(1.5, player)
            assert.is_false(bm:has("invincible"))
        end)

        it("到期时调用 onRemove（battle_cry 攻击力还原）", function()
            bm:add("battle_cry", 2.0, {}, player)
            assert.equals(20, player.attack)
            bm:update(2.5, player)
            assert.equals(10, player.attack)   -- 还原
        end)

        it("rage onRemove 还原 atkBonus", function()
            bm:add("rage", 3.0, { atkBonus = 50 }, player)
            assert.equals(60, player.attack)   -- 10 + 50
            bm:update(4.0, player)
            assert.equals(10, player.attack)   -- 还原
        end)

    end)

    -- ============================================================
    -- mana_shield Buff
    -- ============================================================
    describe("mana_shield Buff", function()

        it("激活后 _shieldActive = true", function()
            bm:add("mana_shield", 8.0, {}, player)
            assert.is_true(player._shieldActive)
        end)

        it("remove() 后 _shieldActive = false", function()
            bm:add("mana_shield", 8.0, {}, player)
            bm:remove("mana_shield", player)
            assert.is_false(player._shieldActive)
        end)

        it("到期后 _shieldActive = false", function()
            bm:add("mana_shield", 1.0, {}, player)
            bm:update(1.5, player)
            assert.is_false(player._shieldActive)
        end)

    end)

    -- ============================================================
    -- soul_drain_range Buff
    -- ============================================================
    describe("soul_drain_range Buff", function()

        it("激活后 pickupRadius 增加", function()
            local before = player.pickupRadius
            bm:add("soul_drain_range", 3.0, { rangeBonus = 50 }, player)
            assert.equals(before + 50, player.pickupRadius)
        end)

        it("到期后 pickupRadius 还原", function()
            local before = player.pickupRadius
            bm:add("soul_drain_range", 1.0, { rangeBonus = 50 }, player)
            bm:update(1.5, player)
            assert.equals(before, player.pickupRadius)
        end)

    end)

    -- ============================================================
    -- Stack 型操作
    -- ============================================================
    describe("Stack 型 — addStack / consumeStack / getStacks", function()

        it("addStack() 增加层数，getStacks() 返回正确值", function()
            bm:addStack("ammo_supply", 3, player)
            assert.equals(3, bm:getStacks("ammo_supply"))
        end)

        it("addStack() 多次叠加", function()
            bm:addStack("ammo_supply", 2, player)
            bm:addStack("ammo_supply", 1, player)
            assert.equals(3, bm:getStacks("ammo_supply"))
        end)

        it("has() stack 有层数时返回 true", function()
            bm:addStack("ammo_supply", 1, player)
            assert.is_true(bm:has("ammo_supply"))
        end)

        it("consumeStack() 消耗一层，返回 true", function()
            bm:addStack("ammo_supply", 2, player)
            local ok = bm:consumeStack("ammo_supply", player)
            assert.is_true(ok)
            assert.equals(1, bm:getStacks("ammo_supply"))
        end)

        it("consumeStack() 归零后 has() 返回 false", function()
            bm:addStack("ammo_supply", 1, player)
            bm:consumeStack("ammo_supply", player)
            assert.is_false(bm:has("ammo_supply"))
        end)

        it("consumeStack() 无层数时返回 false", function()
            local ok = bm:consumeStack("ammo_supply", player)
            assert.is_false(ok)
        end)

        it("getStacks() 不存在时返回 0", function()
            assert.equals(0, bm:getStacks("ammo_supply"))
        end)

    end)

    -- ============================================================
    -- getAll()
    -- ============================================================
    describe("getAll()", function()

        it("无 Buff 时返回空数组", function()
            local list = bm:getAll()
            assert.equals(0, #list)
        end)

        it("timer 型条目包含 buffType='timer'", function()
            bm:add("invincible", 3.0, {}, player)
            local list = bm:getAll()
            assert.equals(1, #list)
            assert.equals("timer", list[1].buffType)
        end)

        it("stack 型条目包含 buffType='stack'", function()
            bm:addStack("ammo_supply", 2, player)
            local list = bm:getAll()
            assert.equals(1, #list)
            assert.equals("stack", list[1].buffType)
        end)

        it("多个 Buff 按 id 字母序排序", function()
            bm:add("invincible", 3.0, {}, player)
            bm:addStack("ammo_supply", 1, player)
            local list = bm:getAll()
            assert.equals(2, #list)
            assert.equals("ammo_supply", list[1].id)
            assert.equals("invincible",  list[2].id)
        end)

    end)

    -- ============================================================
    -- clear()
    -- ============================================================
    describe("clear()", function()

        it("清除所有 timer 型 Buff，各自调用 onRemove", function()
            bm:add("battle_cry", 10.0, {}, player)
            assert.equals(20, player.attack)
            bm:clear(player)
            assert.equals(10, player.attack)   -- 属性还原
            assert.equals(0, #bm:getAll())
        end)

        it("清除所有 stack 型 Buff", function()
            bm:addStack("ammo_supply", 3, player)
            bm:clear(player)
            assert.equals(0, bm:getStacks("ammo_supply"))
            assert.is_false(bm:has("ammo_supply"))
        end)

        it("空管理器 clear() 不报错", function()
            bm:clear(player)   -- 应无错误
            assert.equals(0, #bm:getAll())
        end)

    end)

end)
