--[[
    tests/systems/test_progressionManager.lua
    局外成长管理器单元测试 — Phase 13
    覆盖：load/addCommonPoints/getCommonLevel/upgradeCommon/getCommonBonus
          getMilestonePoints/addMilestonePoints/isNodeUnlocked/unlockNode/getUnlockedNodes
]]

require("tests.helper")

-- ============================================================
-- Mock love.filesystem — 模拟文件不存在（无持久化副作用）
-- ============================================================
love.filesystem.read  = function() return nil end
love.filesystem.write = function() return true end

local ProgressionManager = require("src.systems.progressionManager")

-- ============================================================
-- 辅助：每个测试前重置 ProgressionManager 内部状态
-- 由于 _data 是 local，通过调用 load() 覆盖来重置
-- ============================================================
local function resetPM()
    -- read 返回 nil → load() 将使用 makeDefault()
    love.filesystem.read = function() return nil end
    ProgressionManager.load()
end

describe("ProgressionManager", function()

    before_each(function()
        resetPM()
    end)

    -- ============================================================
    -- 1. load — 文件不存在时返回默认值
    -- ============================================================
    describe("load()", function()

        it("文件不存在时 commonPoints 默认为 0", function()
            local data = ProgressionManager.load()
            assert.equals(0, data.commonPoints)
        end)

        it("文件不存在时各 commonLevels 默认为 0", function()
            local data = ProgressionManager.load()
            assert.equals(0, data.commonLevels.attack)
            assert.equals(0, data.commonLevels.speed)
            assert.equals(0, data.commonLevels.maxhp)
            assert.equals(0, data.commonLevels.critrate)
            assert.equals(0, data.commonLevels.pickup)
            assert.equals(0, data.commonLevels.expmult)
        end)

        it("文件不存在时预置角色记录存在且里程碑点数为 0", function()
            local data = ProgressionManager.load()
            assert.equals(0, data.characters.engineer.milestonePoints)
            assert.equals(0, data.characters.berserker.milestonePoints)
            assert.equals(0, data.characters.phantom.milestonePoints)
        end)

        it("损坏 JSON 时回退到默认值（commonPoints=0）", function()
            love.filesystem.read = function() return "NOT_VALID_JSON{{{{" end
            local data = ProgressionManager.load()
            assert.equals(0, data.commonPoints)
        end)

    end)

    -- ============================================================
    -- 2. addCommonPoints — 累加点数
    -- ============================================================
    describe("addCommonPoints()", function()

        it("addCommonPoints(10) 后 getCommonPoints() 返回 10", function()
            ProgressionManager.addCommonPoints(10)
            assert.equals(10, ProgressionManager.getCommonPoints())
        end)

        it("多次累加正确叠加", function()
            ProgressionManager.addCommonPoints(5)
            ProgressionManager.addCommonPoints(7)
            assert.equals(12, ProgressionManager.getCommonPoints())
        end)

    end)

    -- ============================================================
    -- 3. getCommonLevel — 初始档位
    -- ============================================================
    describe("getCommonLevel()", function()

        it("初始 attack 档位为 0", function()
            assert.equals(0, ProgressionManager.getCommonLevel("attack"))
        end)

        it("未知属性返回 0", function()
            assert.equals(0, ProgressionManager.getCommonLevel("nonexistent_attr"))
        end)

    end)

    -- ============================================================
    -- 4. upgradeCommon — 点数足够时升级成功
    -- ============================================================
    describe("upgradeCommon() 升级逻辑", function()

        it("点数足够时 upgradeCommon('attack') 返回 true，档位+1，点数减少", function()
            -- attack costPerLevel = 10
            ProgressionManager.addCommonPoints(10)
            local ok = ProgressionManager.upgradeCommon("attack")
            assert.is_true(ok)
            assert.equals(1, ProgressionManager.getCommonLevel("attack"))
            assert.equals(0, ProgressionManager.getCommonPoints())
        end)

        it("点数不足时返回 false，档位不变", function()
            -- 只有 5 点，但 attack 需要 10
            ProgressionManager.addCommonPoints(5)
            local ok = ProgressionManager.upgradeCommon("attack")
            assert.is_false(ok)
            assert.equals(0, ProgressionManager.getCommonLevel("attack"))
            assert.equals(5, ProgressionManager.getCommonPoints())
        end)

        it("达到 maxLevel(5) 时继续升级返回 false", function()
            -- attack maxLevel=5, costPerLevel=10 → 需要 50 点
            ProgressionManager.addCommonPoints(50)
            for _ = 1, 5 do
                ProgressionManager.upgradeCommon("attack")
            end
            assert.equals(5, ProgressionManager.getCommonLevel("attack"))
            -- 再升一次应失败
            ProgressionManager.addCommonPoints(10)  -- 补充点数
            local ok = ProgressionManager.upgradeCommon("attack")
            assert.is_false(ok)
            assert.equals(5, ProgressionManager.getCommonLevel("attack"))
        end)

        it("未知属性升级返回 false", function()
            ProgressionManager.addCommonPoints(100)
            local ok = ProgressionManager.upgradeCommon("unknown_attr")
            assert.is_false(ok)
        end)

        it("speed 升级逻辑正确（costPerLevel=8）", function()
            ProgressionManager.addCommonPoints(8)
            local ok = ProgressionManager.upgradeCommon("speed")
            assert.is_true(ok)
            assert.equals(1, ProgressionManager.getCommonLevel("speed"))
            assert.equals(0, ProgressionManager.getCommonPoints())
        end)

    end)

    -- ============================================================
    -- 7. getCommonBonus — 升级后返回正确加成数值
    -- ============================================================
    describe("getCommonBonus()", function()

        it("初始时所有加成均为 0", function()
            local bonus = ProgressionManager.getCommonBonus()
            assert.equals(0, bonus.attack)
            assert.equals(0, bonus.speed)
            assert.equals(0, bonus.maxhp)
            assert.equals(0, bonus.critrate)
            assert.equals(0, bonus.pickup)
            assert.equals(0, bonus.expmult)
        end)

        it("attack 升到 Lv2 后 bonus.attack = 10（bonusPerLevel=5）", function()
            -- attack costPerLevel=10, bonusPerLevel=5
            ProgressionManager.addCommonPoints(20)
            ProgressionManager.upgradeCommon("attack")
            ProgressionManager.upgradeCommon("attack")
            local bonus = ProgressionManager.getCommonBonus()
            assert.equals(10, bonus.attack)
        end)

        it("maxhp 升到 Lv1 后 bonus.maxhp = 10（bonusPerLevel=10）", function()
            -- maxhp costPerLevel=8, bonusPerLevel=10
            ProgressionManager.addCommonPoints(8)
            ProgressionManager.upgradeCommon("maxhp")
            local bonus = ProgressionManager.getCommonBonus()
            assert.equals(10, bonus.maxhp)
        end)

        it("critrate 升到满级(3) 后 bonus.critrate = 9", function()
            -- critrate maxLevel=3, costPerLevel=15, bonusPerLevel=3 → max = 9
            ProgressionManager.addCommonPoints(45)
            for _ = 1, 3 do ProgressionManager.upgradeCommon("critrate") end
            local bonus = ProgressionManager.getCommonBonus()
            assert.equals(9, bonus.critrate)
        end)

    end)

    -- ============================================================
    -- 8~9. getMilestonePoints / addMilestonePoints
    -- ============================================================
    describe("里程碑点数", function()

        it("getMilestonePoints('engineer') 初始返回 0", function()
            assert.equals(0, ProgressionManager.getMilestonePoints("engineer"))
        end)

        it("addMilestonePoints('engineer', 5) 后返回 5", function()
            ProgressionManager.addMilestonePoints("engineer", 5)
            assert.equals(5, ProgressionManager.getMilestonePoints("engineer"))
        end)

        it("多次累加正确叠加", function()
            ProgressionManager.addMilestonePoints("engineer", 3)
            ProgressionManager.addMilestonePoints("engineer", 8)
            assert.equals(11, ProgressionManager.getMilestonePoints("engineer"))
        end)

        it("未知角色自动初始化并返回 0", function()
            assert.equals(0, ProgressionManager.getMilestonePoints("phantom"))
        end)

    end)

    -- ============================================================
    -- 10~13. isNodeUnlocked / unlockNode / getUnlockedNodes
    -- ============================================================
    describe("技能树节点解锁", function()

        it("isNodeUnlocked('engineer', 'eng_overload_duration') 初始返回 false", function()
            assert.is_false(ProgressionManager.isNodeUnlocked("engineer", "eng_overload_duration"))
        end)

        it("点数足够时 unlockNode('engineer', 'eng_overload_duration') 返回 true", function()
            -- eng_overload_duration cost=3，无前置
            ProgressionManager.addMilestonePoints("engineer", 5)
            local ok = ProgressionManager.unlockNode("engineer", "eng_overload_duration")
            assert.is_true(ok)
            assert.is_true(ProgressionManager.isNodeUnlocked("engineer", "eng_overload_duration"))
        end)

        it("解锁后里程碑点数正确扣除", function()
            ProgressionManager.addMilestonePoints("engineer", 10)
            ProgressionManager.unlockNode("engineer", "eng_overload_duration")  -- cost=3
            assert.equals(7, ProgressionManager.getMilestonePoints("engineer"))
        end)

        it("前置未解锁时 unlockNode('engineer', 'eng_overload_shield') 返回 false", function()
            -- eng_overload_shield 需要前置 eng_overload_duration
            ProgressionManager.addMilestonePoints("engineer", 20)
            local ok = ProgressionManager.unlockNode("engineer", "eng_overload_shield")
            assert.is_false(ok)
        end)

        it("已解锁后重复解锁返回 false", function()
            ProgressionManager.addMilestonePoints("engineer", 20)
            ProgressionManager.unlockNode("engineer", "eng_overload_duration")
            local ok = ProgressionManager.unlockNode("engineer", "eng_overload_duration")
            assert.is_false(ok)
        end)

        it("点数不足时解锁返回 false", function()
            -- eng_overload_duration cost=3，只给 1 点
            ProgressionManager.addMilestonePoints("engineer", 1)
            local ok = ProgressionManager.unlockNode("engineer", "eng_overload_duration")
            assert.is_false(ok)
        end)

        it("getUnlockedNodes('engineer') 解锁后列表包含对应 id", function()
            ProgressionManager.addMilestonePoints("engineer", 10)
            ProgressionManager.unlockNode("engineer", "eng_overload_duration")
            local nodes = ProgressionManager.getUnlockedNodes("engineer")
            local found = false
            for _, id in ipairs(nodes) do
                if id == "eng_overload_duration" then found = true end
            end
            assert.is_true(found)
        end)

        it("getUnlockedNodes 未解锁时返回空列表", function()
            local nodes = ProgressionManager.getUnlockedNodes("engineer")
            assert.equals(0, #nodes)
        end)

        it("getUnlockedNodes 返回副本（外部修改不影响内部）", function()
            ProgressionManager.addMilestonePoints("engineer", 10)
            ProgressionManager.unlockNode("engineer", "eng_overload_duration")
            local nodes = ProgressionManager.getUnlockedNodes("engineer")
            nodes[#nodes + 1] = "fake_node"
            -- 再次获取，内部数据不受影响
            local nodes2 = ProgressionManager.getUnlockedNodes("engineer")
            assert.equals(1, #nodes2)
        end)

        it("前置满足后可正确解锁下一节点", function()
            -- 先解锁 eng_overload_duration（cost=3），再解锁 eng_overload_shield（cost=5）
            ProgressionManager.addMilestonePoints("engineer", 20)
            assert.is_true(ProgressionManager.unlockNode("engineer", "eng_overload_duration"))
            assert.is_true(ProgressionManager.unlockNode("engineer", "eng_overload_shield"))
            assert.is_true(ProgressionManager.isNodeUnlocked("engineer", "eng_overload_shield"))
        end)

    end)

end)
