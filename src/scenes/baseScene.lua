--[[
    src/scenes/baseScene.lua
    场景基类 — Phase 12
    定义所有场景的通用接口，子类按需覆盖
    game.lua 通过 SceneManager 持有当前场景实例并逐帧调用
]]

local BaseScene = {}
BaseScene.__index = BaseScene

-- 构造函数
-- @param cfg: config/scenes.lua 中对应场景的配置表
function BaseScene.new(cfg)
    local self = setmetatable({}, BaseScene)
    self._cfg = cfg or {}
    return self
end

-- ============================================================
-- 生命周期钩子（子类可覆盖）
-- ============================================================

-- 场景进入时调用（game.lua 的 enter() 完成后）
-- @param player: 玩家实例
function BaseScene:onEnter(player)
    -- 默认：no-op
end

-- 场景退出时调用（game.lua 的 exit() 前）
function BaseScene:onExit()
    -- 默认：no-op
end

-- 每帧逻辑更新（在 game.lua update 主循环之后）
-- @param dt:     帧时间（秒）
-- @param player: 玩家实例
function BaseScene:update(dt, player)
    -- 默认：no-op
end

-- 绘制场景背景（在 camera:attach() 内，所有实体之前调用）
-- @param camera: 摄像机实例
function BaseScene:draw(camera)
    -- 默认：绘制参考网格（与原 game.lua 相同）
    love.graphics.setColor(0.15, 0.15, 0.15)
    local gridSize = 64
    local screenW, screenH = 1280, 720
    -- 用摄像机位置计算可见范围内的网格线
    local cx = camera and camera.x or 0
    local cy = camera and camera.y or 0
    local startX = math.floor((cx - screenW) / gridSize) * gridSize
    local startY = math.floor((cy - screenH) / gridSize) * gridSize
    local endX = startX + screenW * 3
    local endY = startY + screenH * 3
    for x = startX, endX, gridSize do
        love.graphics.line(x, startY, x, endY)
    end
    for y = startY, endY, gridSize do
        love.graphics.line(startX, y, endX, y)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================
-- 配置查询接口（子类可覆盖）
-- ============================================================

-- 返回场景边界表 {x, y, w, h}，nil = 无限延伸
function BaseScene:getBounds()
    return self._cfg.bounds
end

-- 返回专属 Boss 池（id 字符串数组），nil = 使用全局 Boss 池
function BaseScene:getBossPool()
    return self._cfg.bossPool
end

-- 返回掉落倍率表 {soul, exp}，nil = 使用标准值
function BaseScene:getDropMultiplier()
    return self._cfg.dropMultiplier
end

-- 返回生成点覆盖函数或参数表，nil = 使用默认 Spawner 逻辑
function BaseScene:getSpawnOverride()
    return self._cfg.spawnOverride
end

-- 返回场景配置 id
function BaseScene:getId()
    return self._cfg.id or "unknown"
end

return BaseScene
