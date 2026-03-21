--[[
    src/systems/rhythmController.lua
    节奏控制器 — Phase 9
    统一管理敌人生成节奏、难度曲线和 Boss 触发信号
    Spawner 每帧向此模块查询当前参数，无需自行计算难度

    输出接口：
      :getSpawnParams()  → { interval, batchSize, eliteChance, rangerChance }
      :getPendingBosses() → 待触发的 Boss 配置列表（消费后清空）
      :getElapsed()      → 当前游戏已进行时间（秒）
      :getPhaseName()    → 当前节奏阶段名称（供 HUD 显示）
]]

local BossConfig = require("config.bosses")

local RhythmController = {}
RhythmController.__index = RhythmController

-- Boss 触发时间点（秒）：4/8/12/18 分钟
local BOSS_TIMES = {}
for _, cfg in ipairs(BossConfig) do
    table.insert(BOSS_TIMES, { time = cfg.phase * 60, cfg = cfg })
end

-- 构造函数
function RhythmController.new()
    local self = setmetatable({}, RhythmController)

    self._elapsed       = 0        -- 游戏已进行时间（秒）
    self._pendingBosses = {}       -- 待消费的 Boss 触发列表
    self._bossTriggered = {}       -- 记录已触发的 Boss（防重复）

    -- 当前缓存的生成参数（每帧重算）
    self._interval     = 1.5
    self._batchSize    = 1
    self._eliteChance  = 0.0
    self._rangerChance = 0.0

    -- 当前节奏阶段名（供 HUD）
    self._phaseName    = "calm"

    return self
end

-- 每帧更新
-- @param dt: 帧时间（秒）
function RhythmController:update(dt)
    self._elapsed = self._elapsed + dt

    -- 检测 Boss 触发
    for _, entry in ipairs(BOSS_TIMES) do
        if not self._bossTriggered[entry.cfg.id] and self._elapsed >= entry.time then
            self._bossTriggered[entry.cfg.id] = true
            table.insert(self._pendingBosses, entry.cfg)
        end
    end

    -- 更新生成参数
    self:_recalcParams()
end

-- 内部：重算当前生成参数
function RhythmController:_recalcParams()
    local t = self._elapsed

    -- ── 节奏阶段设计 ──────────────────────────────────────────
    -- 每 120 秒为一个"小节"，共 8 小节（16 分钟），之后持续加速
    -- 每小节内分 4 段：
    --   0%~30%  warm  : 低密度恢复
    --   30%~60% rising: 中密度攀升
    --   60%~85% peak  : 高密度压迫
    --   85%~100% rest : 低密度喘息（Boss 前）

    if t < 960 then
        local cycle    = math.floor(t / 120)
        local progress = (t % 120) / 120

        local intensity, phase
        if progress < 0.30 then
            intensity = 0.2
            phase     = "calm"
        elseif progress < 0.60 then
            intensity = 0.6
            phase     = "rising"
        elseif progress < 0.85 then
            intensity = 1.0
            phase     = "peak"
        else
            intensity = 0.2
            phase     = "rest"
        end

        local cycleScale = 1 + cycle * 0.18

        self._interval    = math.max(0.35, 1.5 - intensity * 0.85) / cycleScale
        self._batchSize   = math.floor(1 + intensity * 2.5 + cycle * 0.6)
        self._eliteChance = math.min(0.30, 0.02 + cycle * 0.04 + intensity * 0.04)
        self._rangerChance = math.min(0.25, 0.0  + cycle * 0.03 + intensity * 0.03)
        self._phaseName   = phase

    else
        -- 后段（16 分钟后）：持续加速
        local t2 = t - 960
        self._interval     = math.max(0.12, 0.35 - t2 / 1500)
        self._batchSize    = math.floor(4 + t2 / 25)
        self._eliteChance  = 0.35
        self._rangerChance = 0.28
        self._phaseName    = "surge"
    end
end

-- 获取当前生成参数
-- @return table: { interval, batchSize, eliteChance, rangerChance }
function RhythmController:getSpawnParams()
    return {
        interval     = self._interval,
        batchSize    = self._batchSize,
        eliteChance  = self._eliteChance,
        rangerChance = self._rangerChance,
    }
end

-- 消费待触发的 Boss 列表
-- @return list: Boss cfg 列表（取走后清空）
function RhythmController:getPendingBosses()
    local list = self._pendingBosses
    self._pendingBosses = {}
    return list
end

-- 获取已进行时间（秒）
function RhythmController:getElapsed()
    return self._elapsed
end

-- 获取当前节奏阶段名称
function RhythmController:getPhaseName()
    return self._phaseName
end

-- 重置（新的一局开始）
function RhythmController:reset()
    self._elapsed       = 0
    self._pendingBosses = {}
    self._bossTriggered = {}
    self._interval      = 1.5
    self._batchSize     = 1
    self._eliteChance   = 0.0
    self._rangerChance  = 0.0
    self._phaseName     = "calm"
end

return RhythmController
