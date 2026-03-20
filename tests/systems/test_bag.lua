--[[
    tests/systems/test_bag.lua
    背包系统单元测试
    覆盖：canPlace / place / remove / expand / getAllWeapons / hasSpace
]]

require("tests.helper")
local Bag    = require("src.systems.bag")
local Weapon = require("src.entities.weapon")

describe("Bag", function()

    local bag, pistol, smg

    before_each(function()
        Weapon.resetIdCounter()
        bag    = Bag.new(3, 3)
        pistol = Weapon.new("pistol")   -- 1×1
        smg    = Weapon.new("smg")      -- 1×2
    end)

    -- ============================================================
    -- canPlace
    -- ============================================================
    describe("canPlace()", function()
        it("空背包可以放置 1×1 武器", function()
            assert.is_true(bag:canPlace(pistol, 1, 1))
        end)

        it("越界返回 false", function()
            assert.is_false(bag:canPlace(pistol, 0, 1))
            assert.is_false(bag:canPlace(pistol, 4, 1))
            assert.is_false(bag:canPlace(pistol, 1, 0))
            assert.is_false(bag:canPlace(pistol, 1, 4))
        end)

        it("1×2 武器超出右边界返回 false", function()
            -- smg 占 (r,1) 和 (r,2)，放在 col=3 时 col=4 越界
            assert.is_false(bag:canPlace(smg, 1, 3))
            assert.is_true(bag:canPlace(smg, 1, 2))
        end)

        it("与已有武器冲突返回 false", function()
            bag:place(pistol, 1, 1)
            local pistol2 = Weapon.new("pistol")
            assert.is_false(bag:canPlace(pistol2, 1, 1))
        end)

        it("武器可以与自身重叠（移动预览）", function()
            bag:place(pistol, 1, 1)
            assert.is_true(bag:canPlace(pistol, 1, 1))
        end)
    end)

    -- ============================================================
    -- place
    -- ============================================================
    describe("place()", function()
        it("成功放置并在 getAllWeapons 中可见", function()
            assert.is_true(bag:place(pistol, 2, 2))
            local weapons = bag:getAllWeapons()
            assert.equals(1, #weapons)
            assert.equals(pistol.instanceId, weapons[1].instanceId)
        end)

        it("放置后 _bagRow / _bagCol 正确", function()
            bag:place(pistol, 2, 3)
            assert.equals(2, pistol._bagRow)
            assert.equals(3, pistol._bagCol)
        end)

        it("放置失败时返回 false，不修改背包", function()
            local ok = bag:place(pistol, 0, 0)
            assert.is_false(ok)
            assert.equals(0, #bag:getAllWeapons())
        end)

        it("移动：先放 A，再把 A 移到新位置", function()
            bag:place(pistol, 1, 1)
            -- 模拟移动：先 remove 再 place（bag:place 内部处理重叠）
            bag:place(pistol, 2, 2)
            assert.is_nil(bag:getWeaponAt(1, 1))
            assert.equals(pistol, bag:getWeaponAt(2, 2))
        end)
    end)

    -- ============================================================
    -- remove
    -- ============================================================
    describe("remove()", function()
        it("移除后武器不在 getAllWeapons 中", function()
            bag:place(pistol, 1, 1)
            bag:remove(pistol)
            assert.equals(0, #bag:getAllWeapons())
        end)

        it("移除后对应格子为 nil", function()
            bag:place(pistol, 1, 1)
            bag:remove(pistol)
            assert.is_nil(bag:getWeaponAt(1, 1))
        end)

        it("移除后 _bagRow / _bagCol 为 nil", function()
            bag:place(pistol, 1, 1)
            bag:remove(pistol)
            assert.is_nil(pistol._bagRow)
            assert.is_nil(pistol._bagCol)
        end)

        it("重复移除不崩溃", function()
            bag:place(pistol, 1, 1)
            bag:remove(pistol)
            assert.has_no_error(function() bag:remove(pistol) end)
        end)

        it("移除未入包的武器不崩溃", function()
            assert.has_no_error(function() bag:remove(pistol) end)
        end)
    end)

    -- ============================================================
    -- expand
    -- ============================================================
    describe("expand()", function()
        it("扩展后 rows / cols 增加", function()
            bag:expand(1, 1)
            assert.equals(4, bag.rows)
            assert.equals(4, bag.cols)
        end)

        it("扩展后旧武器位置不变", function()
            bag:place(pistol, 2, 2)
            bag:expand(1, 1)
            assert.equals(pistol, bag:getWeaponAt(2, 2))
        end)

        it("不超过最大上限", function()
            bag:expand(100, 100)
            local maxR, maxC = Bag.getMaxSize()
            assert.equals(maxR, bag.rows)
            assert.equals(maxC, bag.cols)
        end)
    end)

    -- ============================================================
    -- getAllWeapons
    -- ============================================================
    describe("getAllWeapons()", function()
        it("空背包返回空列表", function()
            assert.equals(0, #bag:getAllWeapons())
        end)

        it("多武器按 instanceId 升序排列", function()
            local w1 = Weapon.new("pistol")
            local w2 = Weapon.new("smg")
            bag:place(w2, 1, 1)
            bag:place(w1, 2, 1)
            local list = bag:getAllWeapons()
            assert.equals(2, #list)
            assert.is_true(list[1].instanceId < list[2].instanceId)
        end)

        it("同一武器不重复出现（多格武器）", function()
            bag:place(smg, 1, 1)  -- smg 占两格
            local list = bag:getAllWeapons()
            assert.equals(1, #list)
        end)
    end)

    -- ============================================================
    -- hasSpace
    -- ============================================================
    describe("hasSpace()", function()
        it("空背包对任意武器返回 true", function()
            assert.is_true(bag:hasSpace(pistol))
        end)

        it("填满后返回 false", function()
            -- 3×3 = 9 格，放 9 个 pistol（1×1）
            for r = 1, 3 do
                for c = 1, 3 do
                    local w = Weapon.new("pistol")
                    bag:place(w, r, c)
                end
            end
            local extra = Weapon.new("pistol")
            assert.is_false(bag:hasSpace(extra))
        end)
    end)

end)
