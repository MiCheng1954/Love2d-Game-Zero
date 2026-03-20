--[[
    src/systems/adjacency.lua
    相邻增益计算系统
    Phase 7：相邻增益 & 武器羁绊

    规则：
        两把武器的任意格子水平或垂直相邻（共享边），即视为相邻
        双向互相：A 给 B 提供 A 的 adjacencyBonus，B 给 A 提供 B 的 adjacencyBonus
        每次背包发生变化（place/remove）后重新计算
        结果缓存在 weapon._adjBonus
]]

local WeaponConfig = require("config.weapons")

local Adjacency = {}

-- 重新计算背包中所有武器的相邻增益
-- @param bag: Bag 实例
function Adjacency.recalculate(bag)
    local weapons = bag:getAllWeapons()

    -- 步骤1：重置所有武器的 _adjBonus 为零
    for _, w in ipairs(weapons) do
        w._adjBonus = { damage = 0, attackSpeed = 0, range = 0, bulletSpeed = 0 }
    end

    -- 步骤2：构建 "格子坐标 → weaponInstanceId" 映射（用于快速邻格查找）
    -- 同时构建 instanceId → Weapon 映射
    local cellMap = {}  -- "r,c" → instanceId
    local weaponMap = {}  -- instanceId → weapon
    for _, w in ipairs(weapons) do
        weaponMap[w.instanceId] = w
        local cells = w:getCells(w._bagRow, w._bagCol)
        for _, cell in ipairs(cells) do
            local key = cell.row .. "," .. cell.col
            cellMap[key] = w.instanceId
        end
    end

    -- 步骤3：遍历每对相邻武器，累加相邻增益
    -- 使用 "已处理对" 集合避免重复处理同一对
    local processedPairs = {}

    local directions = { {0, 1}, {0, -1}, {1, 0}, {-1, 0} }

    for _, wA in ipairs(weapons) do
        local cellsA = wA:getCells(wA._bagRow, wA._bagCol)
        for _, cellA in ipairs(cellsA) do
            -- 检查四个方向的邻格
            for _, dir in ipairs(directions) do
                local nr = cellA.row + dir[1]
                local nc = cellA.col + dir[2]
                local neighborKey = nr .. "," .. nc
                local neighborId = cellMap[neighborKey]

                -- 邻格有不同武器
                if neighborId and neighborId ~= wA.instanceId then
                    local wB = weaponMap[neighborId]

                    -- 构建有序对 key，避免 A-B 和 B-A 重复处理
                    local pairKey
                    if wA.instanceId < wB.instanceId then
                        pairKey = wA.instanceId .. "-" .. wB.instanceId
                    else
                        pairKey = wB.instanceId .. "-" .. wA.instanceId
                    end

                    if not processedPairs[pairKey] then
                        processedPairs[pairKey] = true

                        -- wA 的 adjacencyBonus 给 wB，wB 的 adjacencyBonus 给 wA
                        local cfgA = WeaponConfig[wA.configId]
                        local cfgB = WeaponConfig[wB.configId]

                        if cfgA and cfgA.adjacencyBonus then
                            local bonus = cfgA.adjacencyBonus
                            wB._adjBonus.damage       = wB._adjBonus.damage       + (bonus.damage       or 0)
                            wB._adjBonus.attackSpeed  = wB._adjBonus.attackSpeed  + (bonus.attackSpeed  or 0)
                            wB._adjBonus.range        = wB._adjBonus.range        + (bonus.range        or 0)
                            wB._adjBonus.bulletSpeed  = wB._adjBonus.bulletSpeed  + (bonus.bulletSpeed  or 0)
                        end

                        if cfgB and cfgB.adjacencyBonus then
                            local bonus = cfgB.adjacencyBonus
                            wA._adjBonus.damage       = wA._adjBonus.damage       + (bonus.damage       or 0)
                            wA._adjBonus.attackSpeed  = wA._adjBonus.attackSpeed  + (bonus.attackSpeed  or 0)
                            wA._adjBonus.range        = wA._adjBonus.range        + (bonus.range        or 0)
                            wA._adjBonus.bulletSpeed  = wA._adjBonus.bulletSpeed  + (bonus.bulletSpeed  or 0)
                        end
                    end
                end
            end
        end
    end
end

return Adjacency
