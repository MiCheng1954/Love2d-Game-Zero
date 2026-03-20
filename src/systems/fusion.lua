--[[
    src/systems/fusion.lua
    武器融合系统
    Phase 7.1：武器融合

    提供两个接口：
        Fusion.findRecipe(configIdA, configIdB) → recipe 或 nil
        Fusion.apply(bag, weaponA, weaponB, recipe) → 新武器实例 或 nil

    融合规则：
        - 无序匹配：A+B 等同于 B+A
        - 消耗两把原材料武器，生成一把结果武器
        - 结果武器尽量放在原材料之一的位置，放不下则扫描第一个空位
]]

local FusionConfig = require("config.fusion")
local Weapon       = require("src.entities.weapon")

local Fusion = {}

-- 查找两把武器是否存在融合配方
-- @param configIdA, configIdB: 两把武器的 configId（顺序无关）
-- @return 匹配的 recipe 表，或 nil
function Fusion.findRecipe(configIdA, configIdB)
    for _, recipe in ipairs(FusionConfig) do
        local a, b = recipe.ingredients[1], recipe.ingredients[2]
        if (a == configIdA and b == configIdB)
        or (a == configIdB and b == configIdA) then
            return recipe
        end
    end
    return nil
end

-- 执行武器融合
-- 1. 从背包移除 weaponA 和 weaponB
-- 2. 创建结果武器实例
-- 3. 优先放入 weaponA 的原位置，放不下则扫描第一个空位
-- @param bag     : Bag 实例
-- @param weaponA : 第一把原材料（已从背包拾起、尚未放回）
-- @param weaponB : 第二把原材料（仍在背包中）
-- @param recipe  : Fusion.findRecipe 返回的配方
-- @return 生成的新 Weapon 实例（已放入背包），或 nil（放不下）
function Fusion.apply(bag, weaponA, weaponB, recipe)
    -- 记录 B 的位置作为备选放置点
    local fallbackRow = weaponB._bagRow
    local fallbackCol = weaponB._bagCol

    -- 移除 B（A 此时已被调用方从背包拾起，未在网格中）
    bag:remove(weaponB)

    -- 创建结果武器
    local result = Weapon.new(recipe.result)

    -- 优先尝试 B 的原位置
    local placed = bag:place(result, fallbackRow, fallbackCol)

    -- 扫描第一个可用空位
    if not placed then
        for r = 1, bag.rows do
            for c = 1, bag.cols do
                if bag:place(result, r, c) then
                    placed = true
                    break
                end
            end
            if placed then break end
        end
    end

    if placed then
        return result
    else
        -- 背包完全放不下（极罕见），把 B 放回原位并返回 nil
        bag:place(weaponB, fallbackRow, fallbackCol)
        return nil
    end
end

return Fusion
