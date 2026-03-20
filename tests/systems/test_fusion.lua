--[[
    tests/systems/test_fusion.lua
    武器融合系统单元测试
    覆盖：findRecipe 无序匹配、apply 消耗材料生成结果、背包无位置时回退
]]

require("tests.helper")
local Bag    = require("src.systems.bag")
local Weapon = require("src.entities.weapon")
local Fusion = require("src.systems.fusion")

describe("Fusion", function()

    before_each(function()
        Weapon.resetIdCounter()
    end)

    -- ============================================================
    -- findRecipe
    -- ============================================================
    describe("findRecipe()", function()
        it("正向匹配：pistol + smg → dual_pistol", function()
            local recipe = Fusion.findRecipe("pistol", "smg")
            assert.is_not_nil(recipe)
            assert.equals("dual_pistol", recipe.result)
        end)

        it("反向匹配：smg + pistol → dual_pistol（无序）", function()
            local recipe = Fusion.findRecipe("smg", "pistol")
            assert.is_not_nil(recipe)
            assert.equals("dual_pistol", recipe.result)
        end)

        it("不存在的配方返回 nil", function()
            assert.is_nil(Fusion.findRecipe("pistol", "sniper"))
        end)

        it("同武器不匹配任何配方", function()
            assert.is_nil(Fusion.findRecipe("pistol", "pistol"))
        end)

        it("shotgun + cannon → siege_cannon", function()
            local recipe = Fusion.findRecipe("shotgun", "cannon")
            assert.is_not_nil(recipe)
            assert.equals("siege_cannon", recipe.result)
        end)

        it("sniper + laser → railgun", function()
            local recipe = Fusion.findRecipe("sniper", "laser")
            assert.is_not_nil(recipe)
            assert.equals("railgun", recipe.result)
        end)
    end)

    -- ============================================================
    -- apply
    -- ============================================================
    describe("apply()", function()
        it("融合成功：消耗 A 和 B，生成结果武器", function()
            local bag    = Bag.new(4, 4)
            local pistol = Weapon.new("pistol")
            local smg    = Weapon.new("smg")

            -- 模拟 bagUI 的操作：smg 在背包中，pistol 已被拾起（从背包 remove）
            bag:place(smg, 1, 1)
            -- pistol 已拾起，未在背包中

            local recipe = Fusion.findRecipe("pistol", "smg")
            local result = Fusion.apply(bag, pistol, smg, recipe)

            assert.is_not_nil(result)
            assert.equals("dual_pistol", result.configId)
        end)

        it("融合后原材料 B 不在背包中", function()
            local bag    = Bag.new(4, 4)
            local pistol = Weapon.new("pistol")
            local smg    = Weapon.new("smg")
            bag:place(smg, 2, 2)

            local recipe = Fusion.findRecipe("pistol", "smg")
            Fusion.apply(bag, pistol, smg, recipe)

            assert.is_nil(smg._bagRow)
            assert.equals(0, (function()
                local n = 0
                for _, w in ipairs(bag:getAllWeapons()) do
                    if w.instanceId == smg.instanceId then n = n + 1 end
                end
                return n
            end)())
        end)

        it("融合后背包中有且仅有结果武器（原来只有B）", function()
            local bag    = Bag.new(4, 4)
            local pistol = Weapon.new("pistol")
            local smg    = Weapon.new("smg")
            bag:place(smg, 1, 1)

            local recipe = Fusion.findRecipe("pistol", "smg")
            local result = Fusion.apply(bag, pistol, smg, recipe)

            local all = bag:getAllWeapons()
            assert.equals(1, #all)
            assert.equals(result.instanceId, all[1].instanceId)
        end)

        it("结果武器放置后 _bagRow / _bagCol 有效", function()
            local bag    = Bag.new(4, 4)
            local pistol = Weapon.new("pistol")
            local smg    = Weapon.new("smg")
            bag:place(smg, 2, 3)

            local recipe = Fusion.findRecipe("pistol", "smg")
            local result = Fusion.apply(bag, pistol, smg, recipe)

            assert.is_not_nil(result._bagRow)
            assert.is_not_nil(result._bagCol)
        end)

        it("背包完全放不下结果武器时返回 nil 并还原 B", function()
            -- 构造 1×1 背包，放 pistol(B)；A = smg（已拾起，1×2）
            -- 融合结果 dual_pistol 是 1×2，1×1 背包放不下
            -- 移除 pistol(B) 后背包空了，dual_pistol 仍然放不下
            -- Fusion.apply 应返回 nil，并把 pistol(B) 还原到 (1,1)
            local bag2    = Bag.new(1, 1)
            local smgA    = Weapon.new("smg")      -- A：已拾起，不在背包
            local pistolB = Weapon.new("pistol")   -- B：在背包 1×1 格
            bag2:place(pistolB, 1, 1)

            local recipe = Fusion.findRecipe("smg", "pistol")
            local result = Fusion.apply(bag2, smgA, pistolB, recipe)

            -- dual_pistol（1×2）放不进 1×1 背包，应返回 nil
            assert.is_nil(result)
            -- pistol(B) 应被还原回 (1,1)
            assert.is_not_nil(bag2:getWeaponAt(1, 1))
        end)
    end)

    -- ============================================================
    -- 融合武器 shape 尺寸正确性（Bug #19）
    -- ============================================================
    -- shape 格式为 {{row,col}, …}（零起坐标数组）
    -- 正确尺寸：遍历所有格子取 maxRow/maxCol，rows=maxR+1，cols=maxC+1
    -- 旧 Bug：用 #shape 当行数、#shape[1] 当列数
    --   #shape[1] 恒为 2（因为每个格子 {r,c} 长度=2），cols 始终错误为 2
    --   #shape 当行数也错（格子数 ≠ 行数）
    describe("融合武器 shape 尺寸（Bug#19）", function()
        local WeaponConfig = require("config.weapons")

        -- 与 bagUI.lua 修复后相同的正确算法
        local function shapeSize(shape)
            local maxR, maxC = 0, 0
            for _, cell in ipairs(shape) do
                if cell[1] > maxR then maxR = cell[1] end
                if cell[2] > maxC then maxC = cell[2] end
            end
            return maxR + 1, maxC + 1
        end

        -- 同时验证旧算法确实有 Bug（保证测试有意义）
        local function shapeSizeBuggy(shape)
            return #shape, #shape[1]   -- 旧错误写法
        end

        it("dual_pistol shape → 正确尺寸 1行×2列", function()
            local cfg = WeaponConfig["dual_pistol"]
            assert.is_not_nil(cfg, "dual_pistol 配置应存在")
            local rows, cols = shapeSize(cfg.shape)
            assert.equals(1, rows)
            assert.equals(2, cols)
        end)

        it("siege_cannon shape → 正确尺寸 2行×2列", function()
            local cfg = WeaponConfig["siege_cannon"]
            assert.is_not_nil(cfg, "siege_cannon 配置应存在")
            local rows, cols = shapeSize(cfg.shape)
            assert.equals(2, rows)
            assert.equals(2, cols)
        end)

        it("railgun shape → 正确尺寸 1行×4列", function()
            local cfg = WeaponConfig["railgun"]
            assert.is_not_nil(cfg, "railgun 配置应存在")
            local rows, cols = shapeSize(cfg.shape)
            assert.equals(1, rows)
            assert.equals(4, cols)
        end)

        -- 反向验证：旧算法在所有三把融合武器上均返回错误结果
        it("旧算法 #shape[1] 对 dual_pistol 列数错误（恒为2但rows也错）", function()
            local cfg = WeaponConfig["dual_pistol"]
            -- dual_pistol shape = {{0,0},{0,1}}，共2个格子
            -- 旧算法：rows=#shape=2（错，应为1），cols=#shape[1]=2（cols巧合正确）
            local rows, cols = shapeSizeBuggy(cfg.shape)
            assert.equals(2, rows)   -- 旧算法行数错误（应为1）
            assert.equals(2, cols)   -- cols 这里巧合正确
        end)

        it("旧算法对 siege_cannon 行数错误", function()
            local cfg = WeaponConfig["siege_cannon"]
            -- siege_cannon shape = {{0,0},{0,1},{1,0},{1,1}}，共4个格子
            -- 旧算法：rows=#shape=4（错，应为2），cols=#shape[1]=2（正确）
            local rows, cols = shapeSizeBuggy(cfg.shape)
            assert.equals(4, rows)   -- 旧算法行数错误（应为2）
            assert.equals(2, cols)
        end)

        it("旧算法对 railgun 行数和列数均错误", function()
            local cfg = WeaponConfig["railgun"]
            -- railgun shape = {{0,0},{0,1},{0,2},{0,3}}，共4个格子
            -- 旧算法：rows=#shape=4（错，应为1），cols=#shape[1]=2（错，应为4）
            local rows, cols = shapeSizeBuggy(cfg.shape)
            assert.equals(4, rows)   -- 旧算法行数错误（应为1）
            assert.equals(2, cols)   -- 旧算法列数错误（应为4）
        end)
    end)

end)
