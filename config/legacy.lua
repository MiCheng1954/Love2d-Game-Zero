--[[
    config/legacy.lua
    传承技能候选池配置
    Phase 10：按大类（伤害/科技/生存/爆发/经济）分类，各类 2~3 个候选
    传承效果在下局开始时由 legacyManager 应用到 player 基础属性
]]

-- 大类与武器 Tag 的对应关系（用于匹配本局激活的羁绊）
-- 武器 tags: 速射/精准/重型/爆炸/科技/游击
-- 技能 tags: 防御/爆发/辅助/精准
local CATEGORY_TAG_MAP = {
    ["伤害"] = { "精准", "重型", "爆炸" },   -- 武器：精准/重型/爆炸
    ["科技"] = { "科技" },                    -- 武器：科技
    ["生存"] = { "防御", "游击" },            -- 技能：防御 / 武器：游击
    ["爆发"] = { "爆发", "速射" },            -- 技能：爆发 / 武器：速射
    ["经济"] = { "辅助" },                    -- 技能：辅助
}

-- 传承技能候选池
-- 每项字段：
--   id       : 唯一标识，对应 legacy.json 存储的 key
--   category : 所属大类（伤害/科技/生存/爆发/经济）
--   nameKey  : i18n 名称 key
--   descKey  : i18n 描述 key
--   effect   : 效果表，应用时由 legacyManager 读取
--              支持字段：attack / critRate / critDamage / bulletSpeed /
--                        cdReduce / attackSpeed / maxHP / defense / speed /
--                        expMult / pickupRange / soulsMult
local LEGACY_POOL = {
    -- ============ 伤害类 ============
    {
        id       = "legacy_attack",
        category = "伤害",
        nameKey  = "legacy.attack.name",
        descKey  = "legacy.attack.desc",
        effect   = { attack = 8 },
    },
    {
        id       = "legacy_crit_rate",
        category = "伤害",
        nameKey  = "legacy.crit_rate.name",
        descKey  = "legacy.crit_rate.desc",
        effect   = { critRate = 0.05 },   -- 0.05 = +5%
    },
    {
        id       = "legacy_crit_dmg",
        category = "伤害",
        nameKey  = "legacy.crit_dmg.name",
        descKey  = "legacy.crit_dmg.desc",
        effect   = { critDamage = 0.20 },   -- +20%
    },

    -- ============ 科技类 ============
    {
        id       = "legacy_bullet_speed",
        category = "科技",
        nameKey  = "legacy.bullet_speed.name",
        descKey  = "legacy.bullet_speed.desc",
        effect   = { bulletSpeed = 40 },
    },
    {
        id       = "legacy_cooldown",
        category = "科技",
        nameKey  = "legacy.cooldown.name",
        descKey  = "legacy.cooldown.desc",
        effect   = { cdReduce = 10 },   -- 缩短 10%（与现有 cdReduce 单位一致）
    },
    {
        id       = "legacy_attack_speed",
        category = "科技",
        nameKey  = "legacy.attack_speed.name",
        descKey  = "legacy.attack_speed.desc",
        effect   = { attackSpeed = 0.10 },   -- +10%（乘数）
    },

    -- ============ 生存类 ============
    {
        id       = "legacy_hp",
        category = "生存",
        nameKey  = "legacy.hp.name",
        descKey  = "legacy.hp.desc",
        effect   = { maxHP = 30 },
    },
    {
        id       = "legacy_defense",
        category = "生存",
        nameKey  = "legacy.defense.name",
        descKey  = "legacy.defense.desc",
        effect   = { defense = 0.03 },   -- +3%（0~1 小数）
    },
    {
        id       = "legacy_speed",
        category = "生存",
        nameKey  = "legacy.speed.name",
        descKey  = "legacy.speed.desc",
        effect   = { speed = 15 },
    },

    -- ============ 爆发类 ============
    {
        id       = "legacy_cooldown",   -- 科技/爆发共享
        category = "爆发",
        nameKey  = "legacy.cooldown.name",
        descKey  = "legacy.cooldown.desc",
        effect   = { cdReduce = 10 },
    },

    -- ============ 经济类 ============
    {
        id       = "legacy_exp",
        category = "经济",
        nameKey  = "legacy.exp.name",
        descKey  = "legacy.exp.desc",
        effect   = { expMult = 20 },   -- +20%（与现有 expMult 单位一致）
    },
    {
        id       = "legacy_pickup",
        category = "经济",
        nameKey  = "legacy.pickup.name",
        descKey  = "legacy.pickup.desc",
        effect   = { pickupRange = 40 },
    },
    {
        id       = "legacy_souls",
        category = "经济",
        nameKey  = "legacy.souls.name",
        descKey  = "legacy.souls.desc",
        effect   = { soulsMult = 20 },   -- +20%（用于未来灵魂加成系统）
    },
}

return {
    pool            = LEGACY_POOL,
    categoryTagMap  = CATEGORY_TAG_MAP,
}
