--[[
    config/weapons.lua
    武器配置表，定义游戏中所有武器的基础属性
    Phase 6：武器背包系统

    shape 说明：
        用 {row, col} 坐标数组描述武器占格（左上角为 {0,0}）
        例：{{0,0},{0,1}} = 横向 1×2
]]

return {
    pistol = {
        id          = "pistol",
        nameKey     = "weapon.pistol.name",
        descKey     = "weapon.pistol.desc",
        shape       = {{0,0}},                          -- 1×1 单格
        color       = {0.5, 0.8, 1.0},
        damage      = 20,
        attackSpeed = 1.0,     -- 每秒发射次数
        bulletSpeed = 450,     -- 子弹飞行速度（像素/秒）
        range       = 350,     -- 索敌范围（像素）
        maxLevel    = 3,
        levelBonus  = { damage = 10 },
    },

    shotgun = {
        id          = "shotgun",
        nameKey     = "weapon.shotgun.name",
        descKey     = "weapon.shotgun.desc",
        shape       = {{0,0},{0,1}},                    -- 横向 1×2
        color       = {1.0, 0.6, 0.2},
        damage      = 45,
        attackSpeed = 0.4,
        bulletSpeed = 380,
        range       = 220,
        maxLevel    = 3,
        levelBonus  = { damage = 15 },
    },

    smg = {
        id          = "smg",
        nameKey     = "weapon.smg.name",
        descKey     = "weapon.smg.desc",
        shape       = {{0,0},{0,1}},                    -- 横向 1×2
        color       = {0.4, 1.0, 0.6},
        damage      = 8,
        attackSpeed = 3.0,
        bulletSpeed = 500,
        range       = 300,
        maxLevel    = 3,
        levelBonus  = { damage = 4 },
    },

    sniper = {
        id          = "sniper",
        nameKey     = "weapon.sniper.name",
        descKey     = "weapon.sniper.desc",
        shape       = {{0,0},{0,1},{0,2}},              -- 横向 1×3
        color       = {1.0, 0.9, 0.2},
        damage      = 120,
        attackSpeed = 0.25,
        bulletSpeed = 700,
        range       = 700,
        maxLevel    = 3,
        levelBonus  = { damage = 40 },
    },

    cannon = {
        id          = "cannon",
        nameKey     = "weapon.cannon.name",
        descKey     = "weapon.cannon.desc",
        shape       = {{0,0},{1,0},{1,1}},              -- L形 3格
        color       = {1.0, 0.3, 0.3},
        damage      = 80,
        attackSpeed = 0.5,
        bulletSpeed = 350,
        range       = 400,
        maxLevel    = 3,
        levelBonus  = { damage = 25 },
    },

    laser = {
        id          = "laser",
        nameKey     = "weapon.laser.name",
        descKey     = "weapon.laser.desc",
        shape       = {{0,1},{1,0},{1,1},{1,2}},        -- T形 4格
        color       = {0.8, 0.3, 1.0},
        damage      = 12,
        attackSpeed = 4.0,
        bulletSpeed = 600,
        range       = 320,
        maxLevel    = 3,
        levelBonus  = { damage = 5 },
    },
}
