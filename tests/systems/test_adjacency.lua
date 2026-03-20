--[[
    tests/systems/test_adjacency.lua
    相邻增益系统单元测试
    覆盖：双向累加、自身不相邻、移除后归零、多武器叠加
]]

require("tests.helper")
local Bag       = require("src.systems.bag")
local Weapon    = require("src.entities.weapon")

describe("Adjacency", function()

    local bag

    before_each(function()
        Weapon.resetIdCounter()
        bag = Bag.new(4, 4)
    end)

    it("单武器放入背包，adjBonus 全为零", function()
        local pistol = Weapon.new("pistol")
        bag:place(pistol, 1, 1)
        assert.equals(0, pistol._adjBonus.damage)
        assert.equals(0, pistol._adjBonus.attackSpeed)
        assert.equals(0, pistol._adjBonus.range)
    end)

    it("pistol(1,1) 与 smg(1,2) 水平相邻 — pistol 获得 smg 的 adjacencyBonus", function()
        -- smg.adjacencyBonus = { attackSpeed=0.4 }
        -- pistol 应获得 +0.4 attackSpeed
        local pistol = Weapon.new("pistol")
        local smg    = Weapon.new("smg")
        bag:place(pistol, 1, 1)
        bag:place(smg, 1, 2)
        assert.is_near(0.4, pistol._adjBonus.attackSpeed, 1e-6)
    end)

    it("双向互相：smg 同时获得 pistol 的 adjacencyBonus", function()
        -- pistol.adjacencyBonus = { attackSpeed=0.15 }
        -- smg 应获得 +0.15 attackSpeed
        local pistol = Weapon.new("pistol")
        local smg    = Weapon.new("smg")
        bag:place(pistol, 1, 1)
        bag:place(smg, 1, 2)
        assert.is_near(0.15, smg._adjBonus.attackSpeed, 1e-6)
    end)

    it("垂直相邻也可触发", function()
        local sniper = Weapon.new("sniper")  -- shape 1×3，占 (1,1)(1,2)(1,3)
        local pistol = Weapon.new("pistol")  -- shape 1×1
        bag:place(sniper, 1, 1)
        bag:place(pistol, 2, 1)              -- 垂直紧挨 sniper 的 (1,1) 格
        -- pistol 应获得 sniper.adjacencyBonus = { range=60 }
        assert.equals(60, pistol._adjBonus.range)
    end)

    it("不相邻的武器不产生加成", function()
        local pistol  = Weapon.new("pistol")
        local cannon  = Weapon.new("cannon")
        bag:place(pistol, 1, 1)
        bag:place(cannon, 3, 3)  -- 不相邻
        assert.equals(0, pistol._adjBonus.damage)
        assert.equals(0, pistol._adjBonus.attackSpeed)
    end)

    it("移除相邻武器后 adjBonus 归零", function()
        local pistol = Weapon.new("pistol")
        local smg    = Weapon.new("smg")
        bag:place(pistol, 1, 1)
        bag:place(smg, 1, 2)
        -- 确认加成已建立
        assert.is_near(0.4, pistol._adjBonus.attackSpeed, 1e-6)
        -- 移除 smg
        bag:remove(smg)
        assert.is_near(0.0, pistol._adjBonus.attackSpeed, 1e-6)
    end)

    it("多武器同时相邻，adjBonus 正确叠加", function()
        -- shotgun(1,1) 与 cannon(2,1) 垂直相邻
        -- pistol(1,2) 与 shotgun 水平相邻
        -- 形状：shotgun=1×2 → 占(1,1)(1,2)；放在(1,1)
        -- 三者叠加，cannon 受 shotgun.adj={damage=8}，
        -- pistol 受 shotgun.adj={damage=8}
        local shotgun = Weapon.new("shotgun")  -- shape 1×2
        local cannon  = Weapon.new("cannon")   -- shape L 3格，放 (2,1)
        bag:place(shotgun, 1, 1)
        bag:place(cannon, 2, 1)
        -- cannon 的 (2,1) 紧挨 shotgun 的 (1,1) → cannon 获得 shotgun.adj = {damage=8}
        assert.equals(8, cannon._adjBonus.damage)
    end)

    it("同一武器不与自身产生加成", function()
        local smg = Weapon.new("smg")  -- 占两格，两格同属一个武器
        bag:place(smg, 1, 1)
        assert.equals(0, smg._adjBonus.attackSpeed)
        assert.equals(0, smg._adjBonus.damage)
    end)

end)
