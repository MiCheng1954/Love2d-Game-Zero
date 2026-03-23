--[[
    config/scenes.lua
    场景配置表 — Phase 12
    定义所有可用场景的静态配置数据
    场景逻辑实现在 src/scenes/ 目录下
]]

local SceneConfig = {

    -- ── 场景 1：基础平原 ──────────────────────────────────────────
    plains = {
        id             = "plains",
        nameKey        = "scene.plains.name",
        descKey        = "scene.plains.desc",
        difficultyKey  = "scene.plains.difficulty",
        bounds         = nil,          -- nil = 无限延伸地图
        spawnOverride  = nil,          -- nil = 使用默认 RhythmController 参数
        bossPool       = nil,          -- nil = 使用全局 Boss 池（bosses.lua）
        dropMultiplier = { soul = 1.0, exp = 1.0 },
    },

    -- ── 场景 2：封闭竞技场 ────────────────────────────────────────
    arena = {
        id             = "arena",
        nameKey        = "scene.arena.name",
        descKey        = "scene.arena.desc",
        difficultyKey  = "scene.arena.difficulty",
        -- 以世界原点为中心的固定边界（左上角坐标 + 宽高）
        bounds         = { x = -1280, y = -720, w = 2560, h = 1440 },
        -- 节奏缩短 20%（更紧凑）
        spawnOverride  = { intervalScale = 0.8 },
        -- 专属 Boss 池，只在竞技场中出现
        bossPool       = { "charger" },
        dropMultiplier = { soul = 1.3, exp = 1.0 },
    },
}

return SceneConfig
