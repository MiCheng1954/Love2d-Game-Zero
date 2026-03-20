--[[
    config/upgrades.lua
    升级奖励配置表，定义所有可选的升级奖励内容
    结构：大类 -> 子选项列表
    新增奖励只需在此添加配置，无需修改逻辑代码
]]

local UpgradeConfig = {

    -- 大类定义（显示顺序和标签）
    categories = {
        { id = "weapon",  labelKey = "cat.weapon", color = {1.0, 0.6, 0.2} },
        { id = "stat",    labelKey = "cat.stat",   color = {0.2, 0.8, 1.0} },
        { id = "skill",   labelKey = "cat.skill",  color = {0.7, 0.3, 1.0} },
    },

    -- 武器相关子选项
    weapon = {
        {
            id       = "weapon_new_basic",
            labelKey = "opt.weapon_new_basic.label",
            descKey  = "opt.weapon_new_basic.desc",
            -- TODO: Phase 6 接入背包系统后实装
            apply    = function(player) end,
        },
        {
            id       = "weapon_upgrade",
            labelKey = "opt.weapon_upgrade.label",
            descKey  = "opt.weapon_upgrade.desc",
            -- TODO: Phase 6 接入背包系统后实装
            apply    = function(player) end,
        },
    },

    -- 属性相关子选项
    stat = {
        {
            id       = "stat_hp",
            labelKey = "opt.stat_hp.label",
            descKey  = "opt.stat_hp.desc",
            apply    = function(player)
                player.maxHp = player.maxHp + 30
                player.hp    = math.min(player.hp + 30, player.maxHp)
            end,
        },
        {
            id       = "stat_speed",
            labelKey = "opt.stat_speed.label",
            descKey  = "opt.stat_speed.desc",
            apply    = function(player)
                player.speed = player.speed + 20
            end,
        },
        {
            id       = "stat_attack",
            labelKey = "opt.stat_attack.label",
            descKey  = "opt.stat_attack.desc",
            apply    = function(player)
                player.attack = player.attack + 10
            end,
        },
        {
            id       = "stat_pickup",
            labelKey = "opt.stat_pickup.label",
            descKey  = "opt.stat_pickup.desc",
            apply    = function(player)
                player.pickupRadius = player.pickupRadius + 30
            end,
        },
        {
            id       = "stat_crit",
            labelKey = "opt.stat_crit.label",
            descKey  = "opt.stat_crit.desc",
            apply    = function(player)
                player.critRate   = math.min(player.critRate + 0.05, 0.95)
                player.critDamage = player.critDamage + 0.2
            end,
        },
        {
            id       = "stat_exp",
            labelKey = "opt.stat_exp.label",
            descKey  = "opt.stat_exp.desc",
            apply    = function(player)
                player.expBonus = player.expBonus + 0.2
            end,
        },
    },

    -- 技能相关子选项
    skill = {
        {
            id       = "skill_placeholder_1",
            labelKey = "opt.skill_placeholder_1.label",
            descKey  = "opt.skill_placeholder_1.desc",
            apply    = function(player) end,
        },
        {
            id       = "skill_placeholder_2",
            labelKey = "opt.skill_placeholder_2.label",
            descKey  = "opt.skill_placeholder_2.desc",
            apply    = function(player) end,
        },
    },
}

return UpgradeConfig
