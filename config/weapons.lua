--[[
    config/weapons.lua
    武器配置表，定义游戏中所有武器的基础属性
    Phase 6：武器背包系统
    Phase 7.1：新增融合结果武器（dual_pistol / siege_cannon / railgun）
    Phase 7.2：为所有武器新增 tags 字段，新增 6 把基础武器

    shape 说明：
        用 {row, col} 坐标数组描述武器占格（左上角为 {0,0}）
        例：{{0,0},{0,1}} = 横向 1×2
]]

return {
    pistol = {
        id             = "pistol",
        nameKey        = "weapon.pistol.name",
        descKey        = "weapon.pistol.desc",
        passiveKey     = "weapon.pistol.passive",
        shape          = {{0,0}},                          -- 1×1 单格
        color          = {0.5, 0.8, 1.0},
        damage         = 20,
        attackSpeed    = 1.0,     -- 每秒发射次数
        bulletSpeed    = 450,     -- 子弹飞行速度（像素/秒）
        range          = 350,     -- 索敌范围（像素）
        maxLevel       = 3,
        levelBonus     = { damage = 10 },
        adjacencyBonus = { attackSpeed = 0.15 },
        tags           = { "速射", "精准" },
    },

    shotgun = {
        id             = "shotgun",
        nameKey        = "weapon.shotgun.name",
        descKey        = "weapon.shotgun.desc",
        passiveKey     = "weapon.shotgun.passive",
        shape          = {{0,0},{0,1}},                    -- 横向 1×2
        color          = {1.0, 0.6, 0.2},
        damage         = 45,
        attackSpeed    = 0.4,
        bulletSpeed    = 380,
        range          = 220,
        maxLevel       = 3,
        levelBonus     = { damage = 15 },
        adjacencyBonus = { damage = 8 },
        tags           = { "重型", "游击" },
    },

    smg = {
        id             = "smg",
        nameKey        = "weapon.smg.name",
        descKey        = "weapon.smg.desc",
        passiveKey     = "weapon.smg.passive",
        shape          = {{0,0},{0,1}},                    -- 横向 1×2
        color          = {0.4, 1.0, 0.6},
        damage         = 8,
        attackSpeed    = 3.0,
        bulletSpeed    = 500,
        range          = 300,
        maxLevel       = 3,
        levelBonus     = { damage = 4 },
        adjacencyBonus = { attackSpeed = 0.4 },
        tags           = { "速射" },
    },

    sniper = {
        id             = "sniper",
        nameKey        = "weapon.sniper.name",
        descKey        = "weapon.sniper.desc",
        passiveKey     = "weapon.sniper.passive",
        shape          = {{0,0},{0,1},{0,2}},              -- 横向 1×3
        color          = {1.0, 0.9, 0.2},
        damage         = 120,
        attackSpeed    = 0.25,
        bulletSpeed    = 700,
        range          = 700,
        maxLevel       = 3,
        levelBonus     = { damage = 40 },
        adjacencyBonus = { range = 60 },
        tags           = { "精准" },
    },

    cannon = {
        id             = "cannon",
        nameKey        = "weapon.cannon.name",
        descKey        = "weapon.cannon.desc",
        passiveKey     = "weapon.cannon.passive",
        shape          = {{0,0},{1,0},{1,1}},              -- L形 3格
        color          = {1.0, 0.3, 0.3},
        damage         = 80,
        attackSpeed    = 0.5,
        bulletSpeed    = 350,
        range          = 400,
        maxLevel       = 3,
        levelBonus     = { damage = 25 },
        adjacencyBonus = { damage = 12 },
        tags           = { "重型", "爆炸" },
    },

    laser = {
        id             = "laser",
        nameKey        = "weapon.laser.name",
        descKey        = "weapon.laser.desc",
        passiveKey     = "weapon.laser.passive",
        shape          = {{0,1},{1,0},{1,1},{1,2}},        -- T形 4格
        color          = {0.8, 0.3, 1.0},
        damage         = 12,
        attackSpeed    = 4.0,
        bulletSpeed    = 600,
        range          = 320,
        maxLevel       = 3,
        levelBonus     = { damage = 5 },
        adjacencyBonus = { attackSpeed = 0.2, range = 20 },
        tags           = { "科技" },
    },

    -- ============================================================
    -- 新增 6 把基础武器（Phase 7.2）
    -- 不可融合，可在升级中获取
    -- ============================================================

    -- 爆发手枪：速射+精准，1×1 单格
    burst_pistol = {
        id             = "burst_pistol",
        nameKey        = "weapon.burst_pistol.name",
        descKey        = "weapon.burst_pistol.desc",
        passiveKey     = "weapon.burst_pistol.passive",
        shape          = {{0,0}},                          -- 1×1 单格
        color          = {0.6, 0.9, 1.0},
        damage         = 18,
        attackSpeed    = 3.5,
        bulletSpeed    = 380,
        range          = 280,
        maxLevel       = 3,
        levelBonus     = { damage = 8 },
        adjacencyBonus = { attackSpeed = 0.3 },
        tags           = { "速射", "精准" },
    },

    -- 榴弹发射器：爆炸+重型，1×2
    grenade_launcher = {
        id             = "grenade_launcher",
        nameKey        = "weapon.grenade_launcher.name",
        descKey        = "weapon.grenade_launcher.desc",
        passiveKey     = "weapon.grenade_launcher.passive",
        shape          = {{0,0},{0,1}},                    -- 横向 1×2
        color          = {1.0, 0.5, 0.1},
        damage         = 48,
        attackSpeed    = 0.65,
        bulletSpeed    = 260,
        range          = 320,
        maxLevel       = 3,
        levelBonus     = { damage = 18 },
        adjacencyBonus = { damage = 10 },
        tags           = { "爆炸", "重型" },
    },

    -- 双管猎枪：重型+游击，1×2
    double_barrel = {
        id             = "double_barrel",
        nameKey        = "weapon.double_barrel.name",
        descKey        = "weapon.double_barrel.desc",
        passiveKey     = "weapon.double_barrel.passive",
        shape          = {{0,0},{0,1}},                    -- 横向 1×2
        color          = {0.9, 0.5, 0.2},
        damage         = 58,
        attackSpeed    = 0.75,
        bulletSpeed    = 290,
        range          = 160,
        maxLevel       = 3,
        levelBonus     = { damage = 20 },
        adjacencyBonus = { damage = 9 },
        tags           = { "重型", "游击" },
    },

    -- 加特林：速射+重型，2×2
    gatling = {
        id             = "gatling",
        nameKey        = "weapon.gatling.name",
        descKey        = "weapon.gatling.desc",
        passiveKey     = "weapon.gatling.passive",
        shape          = {{0,0},{0,1},{1,0},{1,1}},        -- 2×2 方形
        color          = {0.5, 1.0, 0.4},
        damage         = 14,
        attackSpeed    = 5.5,
        bulletSpeed    = 420,
        range          = 260,
        maxLevel       = 3,
        levelBonus     = { damage = 5, attackSpeed = 0.5 },
        adjacencyBonus = { attackSpeed = 0.5 },
        tags           = { "速射", "重型" },
    },

    -- 等离子手枪：科技+爆炸，1×1
    plasma_pistol = {
        id             = "plasma_pistol",
        nameKey        = "weapon.plasma_pistol.name",
        descKey        = "weapon.plasma_pistol.desc",
        passiveKey     = "weapon.plasma_pistol.passive",
        shape          = {{0,0}},                          -- 1×1 单格
        color          = {0.5, 0.3, 1.0},
        damage         = 30,
        attackSpeed    = 1.8,
        bulletSpeed    = 340,
        range          = 300,
        maxLevel       = 3,
        levelBonus     = { damage = 12 },
        adjacencyBonus = { attackSpeed = 0.2, range = 25 },
        tags           = { "科技", "爆炸" },
    },

    -- 磁轨步枪：精准+科技，1×3
    rail_rifle = {
        id             = "rail_rifle",
        nameKey        = "weapon.rail_rifle.name",
        descKey        = "weapon.rail_rifle.desc",
        passiveKey     = "weapon.rail_rifle.passive",
        shape          = {{0,0},{0,1},{0,2}},              -- 横向 1×3
        color          = {0.3, 0.7, 1.0},
        damage         = 82,
        attackSpeed    = 0.65,
        bulletSpeed    = 620,
        range          = 520,
        maxLevel       = 3,
        levelBonus     = { damage = 28, range = 40 },
        adjacencyBonus = { range = 50 },
        tags           = { "精准", "科技" },
    },

    -- ============================================================
    -- 融合结果武器（Phase 7.1）
    -- isFused=true：synergy 系统跳过不计数
    -- ============================================================

    -- pistol + smg → dual_pistol：极速双持，伤害中等但射速惊人
    dual_pistol = {
        id             = "dual_pistol",
        nameKey        = "weapon.dual_pistol.name",
        descKey        = "weapon.dual_pistol.desc",
        passiveKey     = "weapon.dual_pistol.passive",
        shape          = {{0,0},{0,1}},                    -- 横向 1×2
        color          = {0.3, 0.9, 1.0},
        damage         = 18,
        attackSpeed    = 5.0,
        bulletSpeed    = 520,
        range          = 330,
        maxLevel       = 3,
        levelBonus     = { damage = 8, attackSpeed = 0.5 },
        adjacencyBonus = { attackSpeed = 0.5 },            -- 双枪节奏：大幅提升邻居射速
        isFused        = true,
        tags           = { "速射", "精准" },
    },

    -- shotgun + cannon → siege_cannon：超重型炮击，单发高伤
    siege_cannon = {
        id             = "siege_cannon",
        nameKey        = "weapon.siege_cannon.name",
        descKey        = "weapon.siege_cannon.desc",
        passiveKey     = "weapon.siege_cannon.passive",
        shape          = {{0,0},{0,1},{1,0},{1,1}},        -- 2×2 方形
        color          = {1.0, 0.4, 0.1},
        damage         = 180,
        attackSpeed    = 0.3,
        bulletSpeed    = 400,
        range          = 450,
        maxLevel       = 3,
        levelBonus     = { damage = 50 },
        adjacencyBonus = { damage = 20 },                  -- 重甲威压：大幅提升邻居伤害
        isFused        = true,
        tags           = { "重型", "爆炸" },
    },

    -- sniper + laser → railgun：超远射程 + 高射速，穿透感
    railgun = {
        id             = "railgun",
        nameKey        = "weapon.railgun.name",
        descKey        = "weapon.railgun.desc",
        passiveKey     = "weapon.railgun.passive",
        shape          = {{0,0},{0,1},{0,2},{0,3}},        -- 横向 1×4
        color          = {0.9, 0.5, 1.0},
        damage         = 95,
        attackSpeed    = 1.5,
        bulletSpeed    = 800,
        range          = 800,
        maxLevel       = 3,
        levelBonus     = { damage = 30, range = 50 },
        adjacencyBonus = { range = 80, attackSpeed = 0.1 }, -- 能量场：提升邻居射程和微量射速
        isFused        = true,
        tags           = { "精准", "科技" },
    },
}
