--[[
    tests/entities/test_weapon.lua
    武器实体单元测试
    覆盖：getEffective* 系列方法、tickAttack 使用有效射速
]]

require("tests.helper")
local Weapon = require("src.entities.weapon")

describe("Weapon", function()

    before_each(function()
        Weapon.resetIdCounter()
    end)

    -- ============================================================
    -- 构造
    -- ============================================================
    describe("new()", function()
        it("从合法 configId 创建实例", function()
            local w = Weapon.new("pistol")
            assert.is_not_nil(w)
            assert.equals("pistol", w.configId)
            assert.equals(1, w.level)
        end)

        it("初始化 _adjBonus 为零", function()
            local w = Weapon.new("pistol")
            assert.equals(0, w._adjBonus.damage)
            assert.equals(0, w._adjBonus.attackSpeed)
            assert.equals(0, w._adjBonus.range)
            assert.equals(0, w._adjBonus.bulletSpeed)
        end)

        it("初始化 _synergyBonus 为零", function()
            local w = Weapon.new("smg")
            assert.equals(0, w._synergyBonus.damage)
            assert.equals(0, w._synergyBonus.attackSpeed)
            assert.equals(0, w._synergyBonus.range)
        end)

        it("未知 configId 抛出错误", function()
            assert.has_error(function()
                Weapon.new("nonexistent_weapon")
            end)
        end)
    end)

    -- ============================================================
    -- getEffectiveDamage
    -- ============================================================
    describe("getEffectiveDamage()", function()
        it("无加成时 = base damage + playerAttack", function()
            local w = Weapon.new("pistol")  -- damage=20
            assert.equals(20, w:getEffectiveDamage(0))
            assert.equals(30, w:getEffectiveDamage(10))
        end)

        it("含 adjBonus.damage", function()
            local w = Weapon.new("pistol")
            w._adjBonus.damage = 8
            assert.equals(28, w:getEffectiveDamage(0))
            assert.equals(38, w:getEffectiveDamage(10))
        end)

        it("含 synergyBonus.damage", function()
            local w = Weapon.new("pistol")
            w._synergyBonus.damage = 5
            assert.equals(25, w:getEffectiveDamage(0))
        end)

        it("adj + synergy 叠加", function()
            local w = Weapon.new("pistol")
            w._adjBonus.damage     = 8
            w._synergyBonus.damage = 5
            assert.equals(33, w:getEffectiveDamage(0))
        end)

        it("playerAttack 为 nil 时不报错", function()
            local w = Weapon.new("pistol")
            assert.equals(20, w:getEffectiveDamage(nil))
        end)
    end)

    -- ============================================================
    -- getEffectiveAttackSpeed
    -- ============================================================
    describe("getEffectiveAttackSpeed()", function()
        it("无加成时 = base attackSpeed", function()
            local w = Weapon.new("pistol")  -- attackSpeed=1.0
            assert.is_near(1.0, w:getEffectiveAttackSpeed(), 1e-6)
        end)

        it("含 adjBonus.attackSpeed", function()
            local w = Weapon.new("pistol")
            w._adjBonus.attackSpeed = 0.4
            assert.is_near(1.4, w:getEffectiveAttackSpeed(), 1e-6)
        end)

        it("含 synergyBonus.attackSpeed", function()
            local w = Weapon.new("pistol")
            w._synergyBonus.attackSpeed = 0.5
            assert.is_near(1.5, w:getEffectiveAttackSpeed(), 1e-6)
        end)

        it("adj + synergy 叠加", function()
            local w = Weapon.new("pistol")
            w._adjBonus.attackSpeed     = 0.4
            w._synergyBonus.attackSpeed = 0.5
            assert.is_near(1.9, w:getEffectiveAttackSpeed(), 1e-6)
        end)
    end)

    -- ============================================================
    -- getEffectiveRange
    -- ============================================================
    describe("getEffectiveRange()", function()
        it("无加成时 = base range", function()
            local w = Weapon.new("sniper")  -- range=700
            assert.equals(700, w:getEffectiveRange())
        end)

        it("含 adjBonus.range", function()
            local w = Weapon.new("sniper")
            w._adjBonus.range = 60
            assert.equals(760, w:getEffectiveRange())
        end)

        it("含 synergyBonus.range", function()
            local w = Weapon.new("sniper")
            w._synergyBonus.range = 100
            assert.equals(800, w:getEffectiveRange())
        end)
    end)

    -- ============================================================
    -- getEffectiveBulletSpeed
    -- ============================================================
    describe("getEffectiveBulletSpeed()", function()
        it("无加成时 = base bulletSpeed", function()
            local w = Weapon.new("pistol")  -- bulletSpeed=450
            assert.equals(450, w:getEffectiveBulletSpeed())
        end)

        it("含 adjBonus.bulletSpeed", function()
            local w = Weapon.new("pistol")
            w._adjBonus.bulletSpeed = 50
            assert.equals(500, w:getEffectiveBulletSpeed())
        end)
    end)

    -- ============================================================
    -- tickAttack：使用有效射速
    -- ============================================================
    describe("tickAttack()", function()
        it("基础射速下正确返回发射次数", function()
            local w = Weapon.new("pistol")  -- attackSpeed=1.0，interval=1s
            assert.equals(0, w:tickAttack(0.5))
            assert.equals(1, w:tickAttack(0.5))  -- 累计 1.0s → 1发
        end)

        it("加成后射速加快（interval 缩短）", function()
            local w = Weapon.new("pistol")  -- attackSpeed=1.0
            w._adjBonus.attackSpeed = 1.0   -- 有效 2.0/s，interval=0.5s
            assert.equals(0, w:tickAttack(0.3))
            assert.equals(1, w:tickAttack(0.2))  -- 累计 0.5s → 1发
        end)

        it("计时器跨多帧累积正确", function()
            local w = Weapon.new("smg")  -- attackSpeed=3.0，interval≈0.333s
            local total = 0
            for _ = 1, 30 do
                total = total + w:tickAttack(0.1)  -- 3s 总共应发射约9发
            end
            assert.equals(9, total)
        end)
    end)

    -- ============================================================
    -- rotate / getCells
    -- ============================================================
    describe("rotate()", function()
        it("1×1 武器旋转后形状不变", function()
            local w = Weapon.new("pistol")
            w:rotate()
            local cells = w:getCells(1, 1)
            assert.equals(1, #cells)
            assert.equals(1, cells[1].row)
            assert.equals(1, cells[1].col)
        end)

        it("1×2 武器旋转后变为 2×1", function()
            local w = Weapon.new("smg")  -- shape={{0,0},{0,1}}
            local r1, c1 = w:getBounds()
            assert.equals(1, r1)
            assert.equals(2, c1)
            w:rotate()
            local r2, c2 = w:getBounds()
            assert.equals(2, r2)
            assert.equals(1, c2)
        end)
    end)

end)
