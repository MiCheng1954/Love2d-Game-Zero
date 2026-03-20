--[[
    config/enemies.lua
    敌人属性配置表，所有敌人的基础数据都在此定义
    新增敌人类型只需在此添加配置，无需修改逻辑代码
]]

local EnemyConfig = {

    -- 普通近战小怪
    basic = {
        name        = "basic",          -- 敌人类型名称
        maxHp       = 30,               -- 最大生命值
        attack      = 8,                -- 攻击力
        defense     = 0,                -- 防御力
        speed       = 80,               -- 移动速度（像素/秒）
        radius      = 12,               -- 碰撞圆半径（像素）
        color       = {0.9, 0.2, 0.2},  -- 代码绘制颜色（红色）
        expDrop     = 5,                -- 击杀经验值掉落
        soulDrop    = 1,                -- 击杀灵魂掉落
        damage      = 10,               -- 接触玩家造成的伤害
        contactRate = 1.0,              -- 接触伤害频率（秒/次）
    },

    -- 快速近战小怪
    fast = {
        name        = "fast",
        maxHp       = 15,
        attack      = 5,
        defense     = 0,
        speed       = 140,
        radius      = 9,
        color       = {0.9, 0.5, 0.1},  -- 橙色
        expDrop     = 8,
        soulDrop    = 1,
        damage      = 6,
        contactRate = 0.8,
    },

    -- 坦克近战小怪
    tank = {
        name        = "tank",
        maxHp       = 120,
        attack      = 15,
        defense     = 5,
        speed       = 45,
        radius      = 20,
        color       = {0.5, 0.1, 0.8},  -- 紫色
        expDrop     = 20,
        soulDrop    = 3,
        damage      = 20,
        contactRate = 1.5,
    },
}

return EnemyConfig
