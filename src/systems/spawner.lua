--[[
    src/systems/spawner.lua
    敌人生成系统，负责在玩家周围按节奏控制器参数生成敌人
    Phase 9：接入 RhythmController，支持精英怪/远程敌人生成，注入共享投射物列表
]]

local Enemy = require("src.entities.enemy")

local Spawner = {}
Spawner.__index = Spawner

-- 生成距离范围（像素）
local SPAWN_DIST_MIN = 400
local SPAWN_DIST_MAX = 550

-- 构造函数
-- @param enemyList:      共享的敌人列表引用
-- @param projectileList: 共享的投射物列表引用（远程敌人射击用）
function Spawner.new(enemyList, projectileList)
    local self = setmetatable({}, Spawner)

    self._enemyList      = enemyList       -- 共享敌人列表
    self._projectileList = projectileList  -- 共享投射物列表
    self._target         = nil             -- 生成参考目标（玩家）
    self._timer          = 0               -- 当前生成计时器（秒）
    self._skillManager   = nil             -- 技能管理器（Bug#20 减速用）

    -- 当前节奏参数（由 RhythmController 提供）
    self._interval     = 1.5
    self._batchSize    = 1
    self._eliteChance  = 0.0
    self._rangerChance = 0.0
    self._elapsed      = 0

    return self
end

-- 设置生成参考目标（玩家）
function Spawner:setTarget(target)
    self._target = target
end

-- 设置技能管理器（Bug#20：新生成敌人受全屏减速影响）
function Spawner:setSkillManager(sm)
    self._skillManager = sm
end

-- 设置共享投射物列表（远程敌人射击注入）
function Spawner:setProjectileList(list)
    self._projectileList = list
end

-- 设置自定义生成点函数（场景覆盖用）
-- @param fn: function(target) → x, y  若为 nil 则使用默认圆圈生成逻辑
function Spawner:setSpawnOverride(fn)
    self._spawnOverrideFn = fn
end

-- 每帧更新
-- @param dt:     帧时间（秒）
-- @param params: RhythmController:getSpawnParams() 返回的参数表
-- @param elapsed: 当前游戏时间（秒），用于类型权重计算
function Spawner:update(dt, params, elapsed)
    if not self._target then return end

    -- 接受节奏控制器参数
    if params then
        self._interval     = params.interval
        self._batchSize    = params.batchSize
        self._eliteChance  = params.eliteChance  or 0
        self._rangerChance = params.rangerChance or 0
    end
    self._elapsed = elapsed or self._elapsed

    self._timer = self._timer + dt

    if self._timer >= self._interval then
        self._timer = self._timer - self._interval
        self:_spawnBatch()
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
function Spawner:_spawnOne()
    local spawnX, spawnY
    if self._spawnOverrideFn then
        -- 场景提供自定义生成点
        spawnX, spawnY = self._spawnOverrideFn(self._target)
    else
        -- 默认：在玩家周围圆圈外随机生成
        local angle = math.random() * math.pi * 2
        local dist  = SPAWN_DIST_MIN + math.random() * (SPAWN_DIST_MAX - SPAWN_DIST_MIN)
        spawnX = self._target.x + math.cos(angle) * dist
        spawnY = self._target.y + math.sin(angle) * dist
    end

    -- 决定敌人类型
    local typeName = self:_pickEnemyType()
    local enemy    = Enemy.new(spawnX, spawnY, typeName)
    enemy:setTarget(self._target)

    -- 远程敌人注入共享投射物列表
    if enemy._isRanger and self._projectileList then
        enemy:setProjectileList(self._projectileList)
    end

    -- Bug#20：新生成敌人同步全屏减速状态
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

-- 根据当前时间和节奏参数决定敌人类型
function Spawner:_pickEnemyType()
    local t = self._elapsed
    local r = math.random()

    -- 精英怪判断（优先）
    if r < self._eliteChance then
        return "elite"
    end
    r = r - self._eliteChance

    -- 远程敌人判断
    if r < self._rangerChance and t >= 60 then   -- 60 秒后才出现 ranger
        return "ranger"
    end
    r = r - self._rangerChance

    -- 普通敌人按时间权重
    if t < 60 then
        return "basic"
    elseif t < 180 then
        return r < 0.7 and "basic" or "fast"
    else
        if r < 0.5 then
            return "basic"
        elseif r < 0.8 then
            return "fast"
        else
            return "tank"
        end
    end
end

-- 重置（新的一局）
function Spawner:reset()
    self._timer        = 0
    self._interval     = 1.5
    self._batchSize    = 1
    self._eliteChance  = 0.0
    self._rangerChance = 0.0
    self._elapsed      = 0
end

return Spawner
