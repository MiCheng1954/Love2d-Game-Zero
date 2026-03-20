--[[
    src/systems/synergy.lua
    武器羁绊计算系统
    Phase 7.2：重设计为 Tag 驱动的全局被动技能系统

    规则：
        遍历背包中所有非融合武器（isFused ~= true）的 tags，统计每个 tag 的数量
        根据 SynergyConfig 每个 tag 的 tiers，找到最高满足的档位
        将激活的档位记录到 bag._activeSynergies
        将档位 effect 累加到 bag._playerSynergyBonus（作用于玩家全局属性）
        bag._tagCounts 记录每个 tag 的武器数量（供 UI 显示进度条）
]]

local SynergyConfig = require("config.synergies")
local WeaponConfig  = require("config.weapons")

local Synergy = {}

-- 重新计算背包中激活的 Tag 羁绊
-- @param bag: Bag 实例
function Synergy.recalculate(bag)
    -- 步骤1：清空旧数据
    bag._activeSynergies    = {}
    bag._tagCounts          = {}
    bag._playerSynergyBonus = {
        speed       = 0,
        damage      = 0,
        critChance  = 0,
        critMult    = 0,
        maxHP       = 0,
        bulletSpeed = 0,
        pickupRange = 0,
        expMult     = 0,
    }

    -- 步骤2：遍历背包中所有武器，跳过融合武器（isFused=true），统计 tag 数量
    local weapons = bag:getAllWeapons()
    for _, w in ipairs(weapons) do
        local cfg = WeaponConfig[w.configId]
        -- 跳过融合武器
        if cfg and not cfg.isFused and cfg.tags then
            for _, tag in ipairs(cfg.tags) do
                bag._tagCounts[tag] = (bag._tagCounts[tag] or 0) + 1
            end
        end
    end

    -- 步骤3：遍历 SynergyConfig 每个 tag 条目，找最高满足的档位
    for _, tagEntry in ipairs(SynergyConfig) do
        local tag      = tagEntry.tag
        local tagCount = bag._tagCounts[tag] or 0

        -- 找最高满足的档位（tiers 已按 count 升序排列）
        local activeTier = nil
        for _, tier in ipairs(tagEntry.tiers) do
            if tagCount >= tier.count then
                activeTier = tier
            else
                break
            end
        end

        -- 步骤4：将激活档位加入 activeSynergies，累加 effect 到 playerSynergyBonus
        if activeTier then
            table.insert(bag._activeSynergies, activeTier)

            local psb = bag._playerSynergyBonus
            local eff = activeTier.effect
            if eff.speed       then psb.speed       = psb.speed       + eff.speed       end
            if eff.damage      then psb.damage      = psb.damage      + eff.damage      end
            if eff.critChance  then psb.critChance  = psb.critChance  + eff.critChance  end
            if eff.critMult    then psb.critMult    = psb.critMult    + eff.critMult    end
            if eff.maxHP       then psb.maxHP       = psb.maxHP       + eff.maxHP       end
            if eff.bulletSpeed then psb.bulletSpeed = psb.bulletSpeed + eff.bulletSpeed end
            if eff.pickupRange then psb.pickupRange = psb.pickupRange + eff.pickupRange end
            if eff.expMult     then psb.expMult     = psb.expMult     + eff.expMult     end
        end
    end
end

return Synergy
