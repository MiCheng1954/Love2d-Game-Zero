--[[
    src/systems/skillSynergy.lua
    技能 Tag 羁绊计算系统 — Phase 8

    功能：
        1. 统计 SkillManager 中技能的 Tag 数量（_skillTagCounts）
        2. 与 config/skill_synergies.lua 匹配，找到每个 tag 的最高触发档位
        3. 将对应 effect 累加到 psb（playerSynergyBonus）
        4. 返回激活羁绊列表（供 HUD 显示）

    注意：
        - 技能羁绊与武器羁绊完全独立（不合并计数）
        - defense 字段使用百分比（0~1），存入 psb.defense
        - cdReduce 字段使用百分比（0~1），存入 psb.cdReduce
]]

local SkillSynergyConfig = require("config.skill_synergies")

local SkillSynergy = {}

-- 重新计算技能羁绊并累加到 psb
-- @param skillManager  SkillManager 实例
-- @param psb           playerSynergyBonus 表（直接修改）
-- @return activeSynergies  激活的羁绊列表（每条含 nameKey / descKey）
function SkillSynergy.recalculate(skillManager, psb)
    local tagCounts      = skillManager:getTagCounts()
    local activeSynergies = {}

    for _, entry in ipairs(SkillSynergyConfig) do
        local tag   = entry.tag
        local count = tagCounts[tag] or 0
        local bestTier = nil

        -- 找到最高触发档位（tiers 按 count 升序）
        for _, tier in ipairs(entry.tiers) do
            if count >= tier.count then
                bestTier = tier
            end
        end

        if bestTier then
            -- 累加 effect 到 psb
            for k, v in pairs(bestTier.effect) do
                psb[k] = (psb[k] or 0) + v
            end
            table.insert(activeSynergies, {
                id      = bestTier.id,
                nameKey = bestTier.nameKey,
                descKey = bestTier.descKey,
                tag     = tag,
                tier    = bestTier.count,
            })
        end
    end

    return activeSynergies
end

return SkillSynergy
