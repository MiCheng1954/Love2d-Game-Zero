--[[
    config/enemies.lua
    敌人属性配置表，所有敌人的基础数据都在此定义
    新增敌人类型只需在此添加配置，无需修改逻辑代码
    Phase 9：新增精英怪（elite）和远程敌人（ranger）
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
        isElite     = false,
        isRanger    = false,
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
        isElite     = false,
        isRanger    = false,
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
        isElite     = false,
        isRanger    = false,
    },

    -- Phase 9：精英怪（强化版 basic，HP×3/伤害×2/速度+30%）
    elite = {
        name        = "elite",
        maxHp       = 90,               -- basic maxHp × 3
        attack      = 16,               -- basic attack × 2
        defense     = 3,
        speed       = 104,              -- basic speed × 1.3
        radius      = 15,               -- 比 basic 略大
        color       = {1.0, 0.85, 0.1}, -- 金色
        expDrop     = 30,               -- 更多经验
        soulDrop    = 5,                -- 更多灵魂
        damage      = 20,               -- basic damage × 2
        contactRate = 0.8,
        isElite     = true,             -- 标记：精英怪
        isRanger    = false,
        -- 精英怪有一定概率额外掉落背包扩展触发器（在 enemy.lua onDeath 中处理）
        eliteDropChance = 0.25,         -- 25% 概率掉落触发器
    },

    -- Phase 9：远程敌人（保持距离，定时向玩家射击）
    ranger = {
        name        = "ranger",
        maxHp       = 40,
        attack      = 12,
        defense     = 0,
        speed       = 70,               -- 慢于 basic（主要靠射击）
        radius      = 11,
        color       = {0.2, 0.7, 0.9},  -- 青色
        expDrop     = 12,
        soulDrop    = 2,
        damage      = 0,                -- 不做接触伤害（靠投射物）
        contactRate = 9999,             -- 接触伤害实际禁用
        isElite     = false,
        isRanger    = true,             -- 标记：远程敌人
        -- 远程行为参数
        keepDistMin = 150,              -- 与玩家保持的最小距离（像素）
        keepDistMax = 280,              -- 与玩家保持的最大距离（像素）
        attackInterval = 2.0,           -- 射击间隔（秒）
        projectileDamage = 15,          -- 投射物伤害
        projectileSpeed  = 200,         -- 投射物速度（像素/秒）
    },
}

return EnemyConfig
