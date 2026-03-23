--[[
    config/characters.lua
    角色配置表 — Phase 13
    定义所有可选角色的基础属性、专属技能、里程碑目标、局外技能树结构
]]

local CharacterConfig = {

    -- ============================================================
    -- 工程师（原 default）— 科技 / 超载风格
    -- ============================================================
    engineer = {
        id          = "engineer",
        nameKey     = "char.engineer.name",
        descKey     = "char.engineer.desc",
        color       = { 0.2, 0.6, 1.0 },   -- 蓝色

        -- 基础属性（标准，沿用原 default 数值）
        stats = {
            maxHp        = 100,
            speed        = 300,
            attack       = 10,
            critRate     = 0.05,
            critDamage   = 1.5,
            defense      = 0,
            pickupRadius = 1000,
            expBonus     = 2.0,
        },

        -- 专属 F 槽技能
        exclusiveSkill = "overload",

        -- 专属升级选项池（升级奖励额外出现这些大类倾向）
        upgradeAffinity = { "weapon", "stat" },

        -- 局外技能树：分支树结构
        -- 每个节点：id / nameKey / descKey / cost（里程碑点数）/ requires（前置节点id列表）/ effect（onApply函数）
        skillTree = {
            -- === 主干 A：超载强化 ===
            {
                id       = "eng_overload_duration",
                nameKey  = "char.engineer.node.overload_duration.name",
                descKey  = "char.engineer.node.overload_duration.desc",
                cost     = 3,
                requires = {},
                trunk    = "A",
                effect   = function(player)
                    -- 超载时长 +1s（修改 skills.lua overload 的 duration 加成由 game.lua 读取）
                    player._eng_overloadDuration = (player._eng_overloadDuration or 0) + 1
                end,
            },
            {
                id       = "eng_overload_shield",
                nameKey  = "char.engineer.node.overload_shield.name",
                descKey  = "char.engineer.node.overload_shield.desc",
                cost     = 5,
                requires = { "eng_overload_duration" },
                trunk    = "A",
                effect   = function(player)
                    -- 超载激活时自动触发一次 mana_shield
                    player._eng_overloadShield = true
                end,
            },
            {
                id       = "eng_overload_cooldown",
                nameKey  = "char.engineer.node.overload_cooldown.name",
                descKey  = "char.engineer.node.overload_cooldown.desc",
                cost     = 6,
                requires = { "eng_overload_shield" },
                trunk    = "A",
                effect   = function(player)
                    -- 超载冷却缩短 30%
                    player._eng_overloadCdReduce = (player._eng_overloadCdReduce or 0) + 0.3
                end,
            },

            -- === 主干 B：武器强化 ===
            {
                id       = "eng_weapon_slots",
                nameKey  = "char.engineer.node.weapon_slots.name",
                descKey  = "char.engineer.node.weapon_slots.desc",
                cost     = 3,
                requires = {},
                trunk    = "B",
                effect   = function(player)
                    -- 背包初始尺寸 +1 行
                    player._bag:expand(1, 0)
                end,
            },
            {
                id       = "eng_weapon_adj",
                nameKey  = "char.engineer.node.weapon_adj.name",
                descKey  = "char.engineer.node.weapon_adj.desc",
                cost     = 5,
                requires = { "eng_weapon_slots" },
                trunk    = "B",
                effect   = function(player)
                    -- 相邻增益效果 +25%
                    player._eng_adjBonus = (player._eng_adjBonus or 0) + 0.25
                end,
            },
        },

        -- 里程碑定义（达成条件 → 获得里程碑点数）
        milestones = {
            {
                id        = "eng_overload_10",
                nameKey   = "char.engineer.ms.overload_10.name",
                descKey   = "char.engineer.ms.overload_10.desc",
                points    = 3,
                event     = "skill_activated",
                condition = function(data, progress)
                    if data.skillId == "overload" then
                        progress.count = (progress.count or 0) + 1
                        return progress.count >= 10
                    end
                end,
            },
            {
                id        = "eng_weapons_6",
                nameKey   = "char.engineer.ms.weapons_6.name",
                descKey   = "char.engineer.ms.weapons_6.desc",
                points    = 5,
                event     = "weapon_placed",
                condition = function(data, progress)
                    progress.max = math.max(progress.max or 0, data.weaponCount or 0)
                    return progress.max >= 6
                end,
            },
            {
                id        = "eng_survive_20min",
                nameKey   = "char.engineer.ms.survive_20min.name",
                descKey   = "char.engineer.ms.survive_20min.desc",
                points    = 8,
                event     = "game_end",
                condition = function(data, progress)
                    return (data.surviveTime or 0) >= 1200
                end,
            },
        },
    },

    -- ============================================================
    -- 狂战士 — 近身爆发 / 高风险高回报
    -- ============================================================
    berserker = {
        id          = "berserker",
        nameKey     = "char.berserker.name",
        descKey     = "char.berserker.desc",
        color       = { 0.9, 0.25, 0.2 },  -- 血红色

        -- 基础属性（高HP高攻，低速）
        stats = {
            maxHp        = 150,
            speed        = 270,
            attack       = 14,
            critRate     = 0.08,
            critDamage   = 1.8,
            defense      = 0,
            pickupRadius = 1000,
            expBonus     = 2.0,
        },

        exclusiveSkill  = "battle_cry",
        upgradeAffinity = { "stat", "weapon" },

        skillTree = {
            -- === 主干 A：血怒 ===
            {
                id       = "ber_bloodrage_1",
                nameKey  = "char.berserker.node.bloodrage_1.name",
                descKey  = "char.berserker.node.bloodrage_1.desc",
                cost     = 3,
                requires = {},
                trunk    = "A",
                effect   = function(player)
                    -- HP < 50% 时攻击 +15%
                    player._ber_bloodRage1 = true
                end,
            },
            {
                id       = "ber_bloodrage_2",
                nameKey  = "char.berserker.node.bloodrage_2.name",
                descKey  = "char.berserker.node.bloodrage_2.desc",
                cost     = 5,
                requires = { "ber_bloodrage_1" },
                trunk    = "A",
                effect   = function(player)
                    -- HP < 30% 时攻击额外 +30%
                    player._ber_bloodRage2 = true
                end,
            },
            {
                id       = "ber_last_stand",
                nameKey  = "char.berserker.node.last_stand.name",
                descKey  = "char.berserker.node.last_stand.desc",
                cost     = 8,
                requires = { "ber_bloodrage_2" },
                trunk    = "A",
                effect   = function(player)
                    -- 致命伤害时触发一次 1s 无敌（每局1次）
                    player._ber_lastStand = true
                end,
            },

            -- === 主干 B：冲刺强化 ===
            {
                id       = "ber_dash_dmg",
                nameKey  = "char.berserker.node.dash_dmg.name",
                descKey  = "char.berserker.node.dash_dmg.desc",
                cost     = 3,
                requires = {},
                trunk    = "B",
                effect   = function(player)
                    -- 冲刺经过敌人时造成 30 点伤害
                    player._ber_dashDmg = (player._ber_dashDmg or 0) + 30
                end,
            },
            {
                id       = "ber_dash_cd",
                nameKey  = "char.berserker.node.dash_cd.name",
                descKey  = "char.berserker.node.dash_cd.desc",
                cost     = 5,
                requires = { "ber_dash_dmg" },
                trunk    = "B",
                effect   = function(player)
                    -- 冲刺 CD 缩短 30%
                    player._ber_dashCdReduce = (player._ber_dashCdReduce or 0) + 0.3
                end,
            },
        },

        milestones = {
            {
                id        = "ber_kill_500",
                nameKey   = "char.berserker.ms.kill_500.name",
                descKey   = "char.berserker.ms.kill_500.desc",
                points    = 3,
                event     = "enemy_killed",
                condition = function(data, progress)
                    progress.count = (progress.count or 0) + 1
                    return progress.count >= 500
                end,
            },
            {
                id        = "ber_low_hp_survive",
                nameKey   = "char.berserker.ms.low_hp_survive.name",
                descKey   = "char.berserker.ms.low_hp_survive.desc",
                points    = 5,
                event     = "tick",
                condition = function(data, progress)
                    if data.hpRatio and data.hpRatio < 0.3 then
                        progress.time = (progress.time or 0) + (data.dt or 0)
                        return progress.time >= 300   -- 5分钟
                    end
                end,
            },
            {
                id        = "ber_kill_boss",
                nameKey   = "char.berserker.ms.kill_boss.name",
                descKey   = "char.berserker.ms.kill_boss.desc",
                points    = 6,
                event     = "boss_killed",
                condition = function(data, progress)
                    progress.count = (progress.count or 0) + 1
                    return progress.count >= 1
                end,
            },
        },
    },

    -- ============================================================
    -- 幽灵 — 速度 / 闪避
    -- ============================================================
    phantom = {
        id          = "phantom",
        nameKey     = "char.phantom.name",
        descKey     = "char.phantom.desc",
        color       = { 0.5, 0.9, 0.8 },   -- 青绿色

        -- 基础属性（高速低血）
        stats = {
            maxHp        = 80,
            speed        = 420,
            attack       = 9,
            critRate     = 0.10,
            critDamage   = 1.6,
            defense      = 0,
            pickupRadius = 1200,
            expBonus     = 2.0,
        },

        exclusiveSkill  = "blink",
        upgradeAffinity = { "skill", "stat" },

        skillTree = {
            -- === 主干 A：疾影（闪现强化）===
            {
                id       = "pha_blink_range",
                nameKey  = "char.phantom.node.blink_range.name",
                descKey  = "char.phantom.node.blink_range.desc",
                cost     = 3,
                requires = {},
                trunk    = "A",
                effect   = function(player)
                    -- 闪现距离 +30%
                    player._pha_blinkRange = (player._pha_blinkRange or 0) + 0.3
                end,
            },
            {
                id       = "pha_blink_atk",
                nameKey  = "char.phantom.node.blink_atk.name",
                descKey  = "char.phantom.node.blink_atk.desc",
                cost     = 5,
                requires = { "pha_blink_range" },
                trunk    = "A",
                effect   = function(player)
                    -- 闪现后 2s 内攻速 +50%
                    player._pha_blinkAtkBuff = true
                end,
            },
            {
                id       = "pha_blink_cd",
                nameKey  = "char.phantom.node.blink_cd.name",
                descKey  = "char.phantom.node.blink_cd.desc",
                cost     = 6,
                requires = { "pha_blink_atk" },
                trunk    = "A",
                effect   = function(player)
                    -- 闪现 CD 缩短 40%
                    player._pha_blinkCdReduce = (player._pha_blinkCdReduce or 0) + 0.4
                end,
            },

            -- === 主干 B：减速领域扩大 ===
            {
                id       = "pha_slow_range",
                nameKey  = "char.phantom.node.slow_range.name",
                descKey  = "char.phantom.node.slow_range.desc",
                cost     = 3,
                requires = {},
                trunk    = "B",
                effect   = function(player)
                    -- time_slow 减速范围 +40%
                    player._pha_slowRange = (player._pha_slowRange or 0) + 0.4
                end,
            },
            {
                id       = "pha_slow_rate",
                nameKey  = "char.phantom.node.slow_rate.name",
                descKey  = "char.phantom.node.slow_rate.desc",
                cost     = 5,
                requires = { "pha_slow_range" },
                trunk    = "B",
                effect   = function(player)
                    -- time_slow 减速倍率提升（0.3 → 0.15）
                    player._pha_slowRate = (player._pha_slowRate or 0) + 0.15
                end,
            },
        },

        milestones = {
            {
                id        = "pha_blink_20",
                nameKey   = "char.phantom.ms.blink_20.name",
                descKey   = "char.phantom.ms.blink_20.desc",
                points    = 3,
                event     = "skill_activated",
                condition = function(data, progress)
                    if data.skillId == "blink" then
                        progress.count = (progress.count or 0) + 1
                        return progress.count >= 20
                    end
                end,
            },
            {
                id        = "pha_arena_survive",
                nameKey   = "char.phantom.ms.arena_survive.name",
                descKey   = "char.phantom.ms.arena_survive.desc",
                points    = 5,
                event     = "game_end",
                condition = function(data, progress)
                    return data.sceneId == "arena" and (data.surviveTime or 0) >= 900
                end,
            },
            {
                id        = "pha_no_damage_1min",
                nameKey   = "char.phantom.ms.no_damage_1min.name",
                descKey   = "char.phantom.ms.no_damage_1min.desc",
                points    = 6,
                event     = "tick",
                condition = function(data, progress)
                    if data.tookDamage then
                        progress.time = 0
                    else
                        progress.time = (progress.time or 0) + (data.dt or 0)
                        return progress.time >= 60
                    end
                end,
            },
        },
    },
}

return CharacterConfig
