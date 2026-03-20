--[[
    config/upgrades.lua
    升级奖励配置表，定义所有可选的升级奖励内容
    结构：大类 -> 子选项列表
    新增奖励只需在此添加配置，无需修改逻辑代码
]]

local UpgradeConfig = {

    -- 大类定义（显示顺序和标签）
    categories = {
        { id = "weapon",  label = "武器强化", color = {1.0, 0.6, 0.2} },
        { id = "stat",    label = "属性提升", color = {0.2, 0.8, 1.0} },
        { id = "skill",   label = "技能获取", color = {0.7, 0.3, 1.0} },
    },

    -- 武器相关子选项
    weapon = {
        {
            id      = "weapon_new_basic",
            label   = "获得新武器",
            desc    = "获得一把随机武器加入背包",
            -- TODO: Phase 6 接入背包系统后实装
            apply   = function(player) end,
        },
        {
            id      = "weapon_upgrade",
            label   = "强化现有武器",
            desc    = "随机强化一把已装备武器的攻击力",
            -- TODO: Phase 6 接入背包系统后实装
            apply   = function(player) end,
        },
    },

    -- 属性相关子选项
    stat = {
        {
            id    = "stat_hp",
            label = "强化生命",
            desc  = "最大生命值 +30，并回复 30 点生命",
            apply = function(player)
                player.maxHp = player.maxHp + 30
                player.hp    = math.min(player.hp + 30, player.maxHp)
            end,
        },
        {
            id    = "stat_speed",
            label = "强化速度",
            desc  = "移动速度 +20",
            apply = function(player)
                player.speed = player.speed + 20
            end,
        },
        {
            id    = "stat_attack",
            label = "强化攻击",
            desc  = "攻击力 +10",
            apply = function(player)
                player.attack = player.attack + 10
            end,
        },
        {
            id    = "stat_pickup",
            label = "强化吸附",
            desc  = "拾取吸附半径 +30",
            apply = function(player)
                player.pickupRadius = player.pickupRadius + 30
            end,
        },
        {
            id    = "stat_crit",
            label = "强化暴击",
            desc  = "暴击率 +5%，暴击伤害 +20%",
            apply = function(player)
                player.critRate   = math.min(player.critRate + 0.05, 0.95)
                player.critDamage = player.critDamage + 0.2
            end,
        },
        {
            id    = "stat_exp",
            label = "强化经验",
            desc  = "经验获取倍率 +20%",
            apply = function(player)
                player.expBonus = player.expBonus + 0.2
            end,
        },
    },

    -- 技能相关子选项
    skill = {
        {
            id    = "skill_placeholder_1",
            label = "技能（待实装）",
            desc  = "Phase 8 接入技能系统后实装",
            apply = function(player) end,
        },
        {
            id    = "skill_placeholder_2",
            label = "被动技能（待实装）",
            desc  = "Phase 8 接入技能系统后实装",
            apply = function(player) end,
        },
    },
}

return UpgradeConfig
