--[[
    config/skill_synergies.lua
    技能 Tag 羁绊配置表 — Phase 8
    与武器羁绊（config/synergies.lua）相同结构，但完全独立计数

    Tag 说明：
        防御 — iron_body、iron_will、mana_shield、heal_pulse、thorns
        爆发 — dash、blink、bomb_throw、battle_cry、explosion、counter_shot、rage、swift_feet、overload
        辅助 — time_slow、emp_burst、soul_drain、energy_field
        精准 — sharpshooter、ammo_supply

    effect 字段（累加到 psb）：
        defense   — 受到伤害减免百分比（0~1）
        cdReduce  — 技能冷却缩短百分比（0~1，如 0.2 = CD×0.8）
        damage    — 攻击力加成
        expMult   — 经验倍率加成（百分比，+30 = +0.30）
        pickupRange — 拾取范围加成
        critChance  — 暴击率加成（百分比，+8 = +0.08）
        critMult    — 暴击伤害加成（百分比，+40 = +0.40）
]]

return {
    {
        tag   = "防御",
        tiers = {
            {
                count   = 2,
                id      = "skill_防御_t2",
                nameKey = "syn.skill.防御.t2.name",
                descKey = "syn.skill.防御.t2.desc",
                effect  = { defense = 0.10 },
            },
            {
                count   = 3,
                id      = "skill_防御_t3",
                nameKey = "syn.skill.防御.t3.name",
                descKey = "syn.skill.防御.t3.desc",
                effect  = { defense = 0.20, maxHP = 30 },
            },
        },
    },
    {
        tag   = "爆发",
        tiers = {
            {
                count   = 2,
                id      = "skill_爆发_t2",
                nameKey = "syn.skill.爆发.t2.name",
                descKey = "syn.skill.爆发.t2.desc",
                effect  = { cdReduce = 0.20 },
            },
            {
                count   = 3,
                id      = "skill_爆发_t3",
                nameKey = "syn.skill.爆发.t3.name",
                descKey = "syn.skill.爆发.t3.desc",
                effect  = { cdReduce = 0.35, damage = 10 },
            },
        },
    },
    {
        tag   = "辅助",
        tiers = {
            {
                count   = 2,
                id      = "skill_辅助_t2",
                nameKey = "syn.skill.辅助.t2.name",
                descKey = "syn.skill.辅助.t2.desc",
                effect  = { expMult = 30 },
            },
            {
                count   = 3,
                id      = "skill_辅助_t3",
                nameKey = "syn.skill.辅助.t3.name",
                descKey = "syn.skill.辅助.t3.desc",
                effect  = { expMult = 50, pickupRange = 60 },
            },
        },
    },
    {
        tag   = "精准",
        tiers = {
            {
                count   = 2,
                id      = "skill_精准_t2",
                nameKey = "syn.skill.精准.t2.name",
                descKey = "syn.skill.精准.t2.desc",
                effect  = { critChance = 8 },
            },
            {
                count   = 3,
                id      = "skill_精准_t3",
                nameKey = "syn.skill.精准.t3.name",
                descKey = "syn.skill.精准.t3.desc",
                effect  = { critChance = 15, critMult = 40 },
            },
        },
    },
}
