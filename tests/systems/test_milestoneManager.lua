--[[
    tests/systems/test_milestoneManager.lua
    里程碑系统单元测试 — Phase 13
    覆盖：new/getTotalPointsEarned/notify 触发与去重/getCompletedList/不同角色隔离
]]

require("tests.helper")

-- ============================================================
-- Mock love.filesystem（milestoneManager 间接依赖 characters.lua，
-- characters.lua 本身不做文件 IO，无需额外 mock）
-- ============================================================
love.filesystem.read  = function() return nil end
love.filesystem.write = function() return true end

local MilestoneManager = require("src.systems.milestoneManager")

describe("MilestoneManager", function()

    -- ============================================================
    -- 1. new — 正常创建
    -- ============================================================
    describe("new()", function()

        it("MilestoneManager.new('engineer') 正常创建，返回实例", function()
            local mm = MilestoneManager.new("engineer")
            assert.is_true(mm ~= nil)
        end)

        it("MilestoneManager.new('berserker') 正常创建，返回实例", function()
            local mm = MilestoneManager.new("berserker")
            assert.is_true(mm ~= nil)
        end)

        it("MilestoneManager.new('unknown_char') 不报错，_trackers 为空", function()
            local mm = MilestoneManager.new("unknown_char")
            assert.is_true(mm ~= nil)
            assert.equals(0, #mm._trackers)
        end)

    end)

    -- ============================================================
    -- 2. getTotalPointsEarned — 初始为 0
    -- ============================================================
    describe("getTotalPointsEarned()", function()

        it("新建实例 getTotalPointsEarned() 初始为 0", function()
            local mm = MilestoneManager.new("engineer")
            assert.equals(0, mm:getTotalPointsEarned())
        end)

        it("berserker 新建实例初始也为 0", function()
            local mm = MilestoneManager.new("berserker")
            assert.equals(0, mm:getTotalPointsEarned())
        end)

    end)

    -- ============================================================
    -- 3. notify — berserker ber_kill_500（enemy_killed × 500）
    -- ============================================================
    describe("notify() — berserker ber_kill_500", function()

        it("notify('enemy_killed') 调用 499 次不完成里程碑", function()
            local mm = MilestoneManager.new("berserker")
            for _ = 1, 499 do
                mm:notify("enemy_killed", {})
            end
            assert.equals(0, mm:getTotalPointsEarned())
            local list = mm:getCompletedList()
            assert.equals(0, #list)
        end)

        it("notify('enemy_killed') 第 500 次触发 ber_kill_500（points=3）", function()
            local mm = MilestoneManager.new("berserker")
            for _ = 1, 500 do
                mm:notify("enemy_killed", {})
            end
            assert.equals(3, mm:getTotalPointsEarned())
        end)

    end)

    -- ============================================================
    -- 4. getCompletedList — 完成后列表包含该里程碑
    -- ============================================================
    describe("getCompletedList()", function()

        it("完成 ber_kill_500 后 getCompletedList 包含该里程碑 id", function()
            local mm = MilestoneManager.new("berserker")
            for _ = 1, 500 do
                mm:notify("enemy_killed", {})
            end
            local list = mm:getCompletedList()
            assert.equals(1, #list)
            assert.equals("ber_kill_500", list[1].id)
        end)

        it("getCompletedList 返回副本（外部修改不影响内部）", function()
            local mm = MilestoneManager.new("berserker")
            for _ = 1, 500 do mm:notify("enemy_killed", {}) end
            local list = mm:getCompletedList()
            list[1] = nil  -- 修改副本
            -- 再次获取列表，内部数据不受影响
            local list2 = mm:getCompletedList()
            assert.equals(1, #list2)
        end)

    end)

    -- ============================================================
    -- 5. 里程碑不重复完成
    -- ============================================================
    describe("里程碑不重复完成", function()

        it("ber_kill_500 完成后继续 notify 不重复增加 points", function()
            local mm = MilestoneManager.new("berserker")
            for _ = 1, 600 do
                mm:notify("enemy_killed", {})
            end
            -- 总点数仍应为 3，不是 6 或更多
            assert.equals(3, mm:getTotalPointsEarned())
        end)

        it("完成后 getCompletedList 列表长度仍为 1（不重复添加）", function()
            local mm = MilestoneManager.new("berserker")
            for _ = 1, 1000 do
                mm:notify("enemy_killed", {})
            end
            local list = mm:getCompletedList()
            assert.equals(1, #list)
        end)

    end)

    -- ============================================================
    -- 6. engineer — eng_survive_20min（game_end surviveTime >= 1200）
    -- ============================================================
    describe("notify() — engineer eng_survive_20min", function()

        it("surviveTime=1300 触发 eng_survive_20min（points=8）", function()
            local mm = MilestoneManager.new("engineer")
            mm:notify("game_end", { surviveTime = 1300 })
            assert.equals(8, mm:getTotalPointsEarned())
            local list = mm:getCompletedList()
            assert.equals(1, #list)
            assert.equals("eng_survive_20min", list[1].id)
        end)

        it("surviveTime=1200（刚好及格）也能触发", function()
            local mm = MilestoneManager.new("engineer")
            mm:notify("game_end", { surviveTime = 1200 })
            assert.equals(8, mm:getTotalPointsEarned())
        end)

        it("surviveTime=600 不触发 eng_survive_20min", function()
            local mm = MilestoneManager.new("engineer")
            mm:notify("game_end", { surviveTime = 600 })
            assert.equals(0, mm:getTotalPointsEarned())
        end)

    end)

    -- ============================================================
    -- 7. 不同角色里程碑互不干扰
    -- ============================================================
    describe("不同角色里程碑隔离", function()

        it("engineer 的 notify 不触发 berserker 的 ber_kill_500", function()
            local mmEng = MilestoneManager.new("engineer")
            -- engineer 没有 enemy_killed 类型的里程碑（它有 skill_activated / weapon_placed / game_end）
            for _ = 1, 500 do
                mmEng:notify("enemy_killed", {})
            end
            assert.equals(0, mmEng:getTotalPointsEarned())
        end)

        it("berserker 实例的 kill 事件不影响 engineer 实例", function()
            local mmBer = MilestoneManager.new("berserker")
            local mmEng = MilestoneManager.new("engineer")

            for _ = 1, 500 do
                mmBer:notify("enemy_killed", {})
            end

            -- engineer 实例应保持 0 点
            assert.equals(0, mmEng:getTotalPointsEarned())
            -- berserker 实例正常完成
            assert.equals(3, mmBer:getTotalPointsEarned())
        end)

        it("两个 berserker 实例各自独立计数", function()
            local mm1 = MilestoneManager.new("berserker")
            local mm2 = MilestoneManager.new("berserker")

            -- mm1 达成 500
            for _ = 1, 500 do mm1:notify("enemy_killed", {}) end

            -- mm2 只有 100 次，不应完成
            for _ = 1, 100 do mm2:notify("enemy_killed", {}) end

            assert.equals(3, mm1:getTotalPointsEarned())
            assert.equals(0, mm2:getTotalPointsEarned())
        end)

    end)

    -- ============================================================
    -- 8. getProgressSummary
    -- ============================================================
    describe("getProgressSummary()", function()

        it("新建 berserker 实例，summary 长度等于里程碑数量（3）", function()
            local mm = MilestoneManager.new("berserker")
            local summary = mm:getProgressSummary()
            assert.equals(3, #summary)
        end)

        it("完成里程碑后对应 summary 项 done=true", function()
            local mm = MilestoneManager.new("berserker")
            for _ = 1, 500 do mm:notify("enemy_killed", {}) end
            local summary = mm:getProgressSummary()
            local killerEntry = nil
            for _, entry in ipairs(summary) do
                if entry.id == "ber_kill_500" then
                    killerEntry = entry
                    break
                end
            end
            assert.is_true(killerEntry ~= nil)
            assert.is_true(killerEntry.done)
        end)

        it("未完成里程碑的 summary 项 done=false", function()
            local mm = MilestoneManager.new("berserker")
            for _ = 1, 100 do mm:notify("enemy_killed", {}) end
            local summary = mm:getProgressSummary()
            local killerEntry = nil
            for _, entry in ipairs(summary) do
                if entry.id == "ber_kill_500" then
                    killerEntry = entry
                    break
                end
            end
            assert.is_true(killerEntry ~= nil)
            assert.is_false(killerEntry.done)
        end)

    end)

    -- ============================================================
    -- 9. engineer — eng_overload_10（skill_activated × 10）
    -- ============================================================
    describe("notify() — engineer eng_overload_10", function()

        it("overload 激活 9 次不触发里程碑", function()
            local mm = MilestoneManager.new("engineer")
            for _ = 1, 9 do
                mm:notify("skill_activated", { skillId = "overload" })
            end
            assert.equals(0, mm:getTotalPointsEarned())
        end)

        it("overload 激活第 10 次触发 eng_overload_10（points=3）", function()
            local mm = MilestoneManager.new("engineer")
            for _ = 1, 10 do
                mm:notify("skill_activated", { skillId = "overload" })
            end
            assert.equals(3, mm:getTotalPointsEarned())
            local list = mm:getCompletedList()
            assert.equals("eng_overload_10", list[1].id)
        end)

        it("激活不同 skillId 不计入 eng_overload_10", function()
            local mm = MilestoneManager.new("engineer")
            for _ = 1, 10 do
                mm:notify("skill_activated", { skillId = "dash" })
            end
            assert.equals(0, mm:getTotalPointsEarned())
        end)

    end)

end)
