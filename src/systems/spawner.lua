--[[
    src/systems/spawner.lua
    敌人生成系统，负责按时间和难度曲线在玩家周围生成敌人
    生成逻辑与敌人数据完全解耦，通过配置控制波次
]]

local Enemy = require("src.entities.enemy")

local Spawner = {}
Spawner.__index = Spawner

-- 敌人生成的最小距离（像素，不在玩家眼皮底下生成）
local SPAWN_DIST_MIN = 400
-- 敌人生成的最大距离（像素）
local SPAWN_DIST_MAX = 550

-- 构造函数，创建一个新的生成系统实例
-- @param enemyList: 共享的敌人列表引用（直接写入此表）
function Spawner.new(enemyList)
    local self = setmetatable({}, Spawner)

    self._enemyList   = enemyList   -- 共享敌人列表引用
    self._target      = nil         -- 生成参考目标（玩家）
    self._timer       = 0           -- 当前生成计时器（秒）
    self._interval    = 1.5         -- 当前生成间隔（秒）
    self._elapsed     = 0           -- 游戏已进行时间（秒）
    self._batchSize   = 1           -- 每次生成的敌人数量

    return self
end

-- 设置生成参考目标（玩家）
-- @param target: 需含 x, y 属性的实体
function Spawner:setTarget(target)
    self._target = target
end

-- 设置技能管理器引用（用于 Bug#20：新生成敌人受全屏减速影响）
function Spawner:setSkillManager(sm)
    self._skillManager = sm
end

-- 每帧更新生成逻辑
-- @param dt: 距上一帧的时间间隔（秒）
function Spawner:update(dt)
    if not self._target then return end

    self._elapsed = self._elapsed + dt
    self._timer   = self._timer   + dt

    -- 根据时间调整难度
    self:_updateDifficulty()

    -- 到达生成间隔则触发生成
    if self._timer >= self._interval then
        self._timer = self._timer - self._interval
        self:_spawnBatch()
    end
end

-- 根据已进行时间动态调整难度（生成频率和数量）
function Spawner:_updateDifficulty()
    local t = self._elapsed  -- 已进行时间（秒）

    -- 前 16 分钟（960秒）：8次慢快循环，每次约 120 秒
    -- 后 4 分钟（240秒）：持续加速
    if t < 960 then
        -- 当前处于哪个循环（0~7）
        local cycle     = math.floor(t / 120)
        -- 循环内进度（0~1）
        local progress  = (t % 120) / 120

        -- 每个循环内节奏：慢(0~0.3) 快(0.3~0.6) 非常快(0.6~0.85) 慢(0.85~1.0)
        local intensity  -- 强度系数（0~1）
        if progress < 0.3 then
            intensity = 0.2
        elseif progress < 0.6 then
            intensity = 0.6
        elseif progress < 0.85 then
            intensity = 1.0
        else
            intensity = 0.2
        end

        -- 随循环数整体变强
        local cycleScale  = 1 + cycle * 0.15

        self._interval  = math.max(0.4, 1.5 - intensity * 0.8) / cycleScale
        self._batchSize = math.floor(1 + intensity * 2 + cycle * 0.5)
    else
        -- 后 4 分钟：持续加速
        local t2 = t - 960  -- 后段已进行时间（秒）
        self._interval  = math.max(0.15, 0.4 - t2 / 1200)
        self._batchSize = math.floor(4 + t2 / 30)
    end
end

-- 生成一批敌人
function Spawner:_spawnBatch()
    for i = 1, self._batchSize do
        local enemy = self:_spawnOne()
        if enemy then
            table.insert(self._enemyList, enemy)
        end
    end
end

-- 在玩家周围随机位置生成一个敌人
-- @return Enemy 实例
function Spawner:_spawnOne()
    -- 随机角度
    local angle = math.random() * math.pi * 2
    -- 随机距离
    local dist  = SPAWN_DIST_MIN +
                  math.random() * (SPAWN_DIST_MAX - SPAWN_DIST_MIN)

    local spawnX = self._target.x + math.cos(angle) * dist
    local spawnY = self._target.y + math.sin(angle) * dist

    -- 根据时间选择敌人类型
    local typeName = self:_pickEnemyType()
    local enemy    = Enemy.new(spawnX, spawnY, typeName)
    enemy:setTarget(self._target)

    -- Bug#20 修复：如果当前有全屏减速效果激活，新生成的敌人也受到影响
    if self._skillManager then
        local slowRate = self._skillManager:getGlobalSlow()
        if slowRate > 0 then
            enemy._baseSpeed = enemy.speed
            enemy.speed      = enemy._baseSpeed * (1 - slowRate)
            enemy._slowTimer = self._skillManager._globalSlowTimer
        end
    end

    return enemy
end

-- 根据当前时间选择敌人类型
-- @return 敌人类型名称（string）
function Spawner:_pickEnemyType()
    local t = self._elapsed
    local r = math.random()

    if t < 60 then
        -- 前 1 分钟：只有 basic
        return "basic"
    elseif t < 180 then
        -- 1~3 分钟：basic + fast
        return r < 0.7 and "basic" or "fast"
    else
        -- 3 分钟后：三种都有
        if r < 0.5 then
            return "basic"
        elseif r < 0.8 then
            return "fast"
        else
            return "tank"
        end
    end
end

-- 重置生成系统（新的一局开始时调用）
function Spawner:reset()
    self._timer    = 0
    self._interval = 1.5
    self._elapsed  = 0
    self._batchSize = 1
end

return Spawner
