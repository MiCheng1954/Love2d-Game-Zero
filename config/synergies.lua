--[[
    config/synergies.lua
    武器羁绊配置表
    Phase 7.2：重设计为 Tag 驱动的全局被动技能系统

    结构说明：
        tag     — 流派标识符（与 weapons.lua 中的 tags 字段对应）
        tiers   — 档位数组，按 count 升序排列
          count   — 触发该档位所需的同 tag 武器数量（不含 isFused=true）
          id      — 档位唯一标识符（用于 activeSynergies 去重）
          nameKey — 名称 i18n key
          descKey — 描述 i18n key
          effect  — 玩家全局属性加成（累加到 bag._playerSynergyBonus）

    effect 字段说明：
        speed       → player.speed 加成
        damage      → player.attack 加成
        critChance  → player.critRate 百分比加成（+8 = +0.08）
        critMult    → player.critDamage 百分比加成（+40 = +0.40）
        maxHP       → player.maxHp 加成
        bulletSpeed → 弹速加成（存入 _playerSynergyBonus，通过 getEffectiveBulletSpeed 传入）
        pickupRange → player.pickupRadius 加成
        expMult     → player.expBonus 百分比加成（+25 = +0.25）
]]

return {
    {
        tag = "速射",
        tiers = {
            {
                count   = 2,
                id      = "速射_t2",
                nameKey = "syn.速射.t2.name",
                descKey = "syn.速射.t2.desc",
                effect  = { speed = 25 },
            },
            {
                count   = 3,
                id      = "速射_t3",
                nameKey = "syn.速射.t3.name",
                descKey = "syn.速射.t3.desc",
                effect  = { speed = 50, damage = 8 },
            },
        },
    },
    {
        tag = "精准",
        tiers = {
            {
                count   = 2,
                id      = "精准_t2",
                nameKey = "syn.精准.t2.name",
                descKey = "syn.精准.t2.desc",
                effect  = { critChance = 8 },
            },
            {
                count   = 3,
                id      = "精准_t3",
                nameKey = "syn.精准.t3.name",
                descKey = "syn.精准.t3.desc",
                effect  = { critChance = 15, critMult = 40 },
            },
        },
    },
    {
        tag = "重型",
        tiers = {
            {
                count   = 2,
                id      = "重型_t2",
                nameKey = "syn.重型.t2.name",
                descKey = "syn.重型.t2.desc",
                effect  = { damage = 15 },
            },
            {
                count   = 3,
                id      = "重型_t3",
                nameKey = "syn.重型.t3.name",
                descKey = "syn.重型.t3.desc",
                effect  = { damage = 30, maxHP = 30 },
            },
        },
    },
    {
        tag = "爆炸",
        tiers = {
            {
                count   = 2,
                id      = "爆炸_t2",
                nameKey = "syn.爆炸.t2.name",
                descKey = "syn.爆炸.t2.desc",
                effect  = { bulletSpeed = 80 },
            },
            {
                count   = 3,
                id      = "爆炸_t3",
                nameKey = "syn.爆炸.t3.name",
                descKey = "syn.爆炸.t3.desc",
                effect  = { bulletSpeed = 160, damage = 10 },
            },
        },
    },
    {
        tag = "科技",
        tiers = {
            {
                count   = 2,
                id      = "科技_t2",
                nameKey = "syn.科技.t2.name",
                descKey = "syn.科技.t2.desc",
                effect  = { pickupRange = 60 },
            },
            {
                count   = 3,
                id      = "科技_t3",
                nameKey = "syn.科技.t3.name",
                descKey = "syn.科技.t3.desc",
                effect  = { pickupRange = 120, expMult = 25 },
            },
        },
    },
    {
        tag = "游击",
        tiers = {
            {
                count   = 2,
                id      = "游击_t2",
                nameKey = "syn.游击.t2.name",
                descKey = "syn.游击.t2.desc",
                effect  = { maxHP = 25 },
            },
            {
                count   = 3,
                id      = "游击_t3",
                nameKey = "syn.游击.t3.name",
                descKey = "syn.游击.t3.desc",
                effect  = { maxHP = 50, speed = 20 },
            },
        },
    },
}
