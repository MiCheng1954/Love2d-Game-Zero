--[[
    src/states/game.lua
    游戏主状态，局内核心玩法的入口
    Phase 3：接入敌人、投射物、生成系统、碰撞检测、自动攻击
]]

local Timer      = require("src.utils.timer")
local MathUtils  = require("src.utils.math")
local Input      = require("src.systems.input")
local Camera     = require("src.systems.camera")
local Collision  = require("src.systems.collision")
local Spawner    = require("src.systems.spawner")
local Player     = require("src.entities.player")
local Projectile = require("src.entities.projectile")

local Game = {}

local _player      = nil   -- 玩家实例
local _camera      = nil   -- 摄像机实例
local _enemies     = {}    -- 当前场景所有敌人列表
local _projectiles = {}    -- 当前场景所有投射物列表
local _spawner     = nil   -- 敌人生成系统实例

-- 自动攻击配置
local AUTO_ATTACK_INTERVAL = 0.5   -- 自动攻击间隔（秒）
local AUTO_ATTACK_DAMAGE   = 20    -- 每发子弹伤害
local AUTO_ATTACK_SPEED    = 450   -- 子弹飞行速度（像素/秒）
local AUTO_ATTACK_RANGE    = 350   -- 自动锁定的最大距离（像素）

local _attackTimer = 0             -- 攻击冷却计时器（秒）

-- 进入游戏状态时调用，负责初始化所有局内数据
function Game:enter()
    Timer.clear()

    -- 初始化列表
    _enemies     = {}
    _projectiles = {}
    _attackTimer = 0

    -- 初始化玩家
    _player = Player.new(0, 0)

    -- 初始化摄像机
    _camera = Camera.new(1280, 720)
    _camera:setTarget(_player)

    -- 初始化生成系统
    _spawner = Spawner.new(_enemies)
    _spawner:setTarget(_player)
end

-- 退出游戏状态时调用
function Game:exit()
    Timer.clear()
    _player      = nil
    _camera      = nil
    _enemies     = {}
    _projectiles = {}
    _spawner     = nil
end

-- 每帧更新游戏逻辑
-- @param dt: 距上一帧的时间间隔（秒）
function Game:update(dt)
    Input.update()
    Timer.update(dt)

    -- 更新玩家
    _player:update(dt)

    -- 更新生成系统
    _spawner:update(dt)

    -- 更新所有敌人
    for _, enemy in ipairs(_enemies) do
        enemy:update(dt)
    end

    -- 更新所有投射物
    for _, proj in ipairs(_projectiles) do
        proj:update(dt)
    end

    -- 自动攻击
    Game._updateAutoAttack(dt)

    -- 碰撞检测：子弹 vs 敌人
    local kills = Collision.projectilesVsEnemies(_projectiles, _enemies)
    -- 发放击杀奖励
    for _, enemy in ipairs(kills) do
        _player:gainExp(enemy:getExpDrop())
        _player:gainSouls(enemy:getSoulDrop())
    end

    -- 碰撞检测：敌人 vs 玩家
    Collision.enemiesVsPlayer(_enemies, _player)

    -- 检测玩家死亡（Phase 10 接入传承系统，暂时直接跳转结算）
    if _player:isDead() then
        local StateManager = require("src.states.stateManager")
        StateManager.switch("gameover")
        return
    end

    -- 清理死亡实体
    Collision.clearDead(_enemies)
    Collision.clearDead(_projectiles)

    -- 更新摄像机
    _camera:update(dt)

    -- TAB 呼出背包（Phase 6 接入）
    if Input.isPressed("openBag") then
        -- TODO: Phase 6
    end

    -- ESC 返回菜单
    if Input.isPressed("cancel") then
        local StateManager = require("src.states.stateManager")
        StateManager.switch("menu")
    end
end

-- 自动攻击：每隔一定时间向最近的敌人发射子弹
-- @param dt: 距上一帧的时间间隔（秒）
function Game._updateAutoAttack(dt)
    _attackTimer = _attackTimer + dt
    if _attackTimer < AUTO_ATTACK_INTERVAL then return end

    -- 寻找最近的敌人
    local nearest = Game._findNearestEnemy()
    if not nearest then return end

    -- 重置攻击计时器
    _attackTimer = _attackTimer - AUTO_ATTACK_INTERVAL

    -- 计算朝向目标的方向
    local dx, dy = MathUtils.normalize(
        nearest.x - _player.x,
        nearest.y - _player.y)

    -- 创建投射物
    local proj = Projectile.new(
        _player.x, _player.y,
        dx, dy,
        AUTO_ATTACK_DAMAGE,
        AUTO_ATTACK_SPEED)

    -- 传递玩家暴击率
    proj._critRate = _player.critRate

    table.insert(_projectiles, proj)
end

-- 在所有敌人中寻找距离玩家最近且在范围内的目标
-- @return 最近的 Enemy 实例，若无则返回 nil
function Game._findNearestEnemy()
    local nearest = nil      -- 最近的敌人
    local minDist = AUTO_ATTACK_RANGE  -- 最大搜索范围

    for _, enemy in ipairs(_enemies) do
        if not enemy._isDead then
            local dist = MathUtils.distance(
                _player.x, _player.y,
                enemy.x,   enemy.y)
            if dist < minDist then
                minDist = dist
                nearest = enemy
            end
        end
    end

    return nearest
end

-- 每帧绘制游戏画面
function Game:draw()
    love.graphics.setBackgroundColor(0.05, 0.05, 0.08)

    -- == 世界层（摄像机坐标系）==
    _camera:attach()

    -- 背景网格
    Game._drawGrid()

    -- 绘制所有敌人
    for _, enemy in ipairs(_enemies) do
        enemy:draw()
    end

    -- 绘制所有投射物
    for _, proj in ipairs(_projectiles) do
        proj:draw()
    end

    -- 绘制玩家（最上层）
    _player:draw()

    _camera:detach()

    -- == UI 层（屏幕坐标系）==
    Game._drawHUD()
end

-- 绘制背景参考网格
function Game._drawGrid()
    local gridSize  = 64
    local gridRange = 20

    love.graphics.setColor(0.15, 0.15, 0.2)
    for i = -gridRange, gridRange do
        love.graphics.line(
            i * gridSize, -gridRange * gridSize,
            i * gridSize,  gridRange * gridSize)
        love.graphics.line(
            -gridRange * gridSize, i * gridSize,
             gridRange * gridSize, i * gridSize)
    end

    love.graphics.setColor(0.3, 0.3, 0.4)
    love.graphics.circle("fill", 0, 0, 4)
end

-- 绘制局内 HUD
function Game._drawHUD()
    -- HP 条背景
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", 20, 20, 200, 16)

    -- HP 条前景
    local hpRatio = _player.hp / _player.maxHp
    love.graphics.setColor(0.8, 0.2, 0.2)
    love.graphics.rectangle("fill", 20, 20, 200 * hpRatio, 16)

    -- HP 条边框
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.rectangle("line", 20, 20, 200, 16)

    -- HP 文字
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("HP " .. _player.hp .. " / " .. _player.maxHp, 24, 22)

    -- 经验条背景
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", 20, 42, 200, 10)

    -- 经验条前景
    love.graphics.setColor(0.2, 0.8, 0.4)
    love.graphics.rectangle("fill", 20, 42, 200 * _player:getExpProgress(), 10)

    -- 等级、灵魂数量、敌人数量
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Lv." .. _player:getLevel(), 20, 58)
    love.graphics.print("灵魂: " .. _player:getSouls(), 20, 76)
    love.graphics.print("敌人: " .. #_enemies, 20, 94)

    -- 操作提示
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.print("WASD 移动  |  ESC 返回菜单", 20, 695)

    -- 调试日志面板（右上角）
    Game._drawDebugPanel()
end

-- 绘制调试日志面板
function Game._drawDebugPanel()
    local x   = 900   -- 面板左上角 X
    local y   = 20    -- 面板左上角 Y
    local lh  = 16    -- 行高

    -- 面板背景
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", x - 8, y - 4, 370, 200)

    love.graphics.setColor(0.4, 1, 0.4)
    love.graphics.print("[DEBUG]", x, y)

    love.graphics.setColor(1, 1, 1)
    -- 玩家坐标
    love.graphics.print(string.format(
        "Pos:    (%.0f, %.0f)",
        _player.x, _player.y), x, y + lh * 1)

    -- 玩家属性
    love.graphics.print(string.format(
        "HP:     %d / %d",
        _player.hp, _player.maxHp), x, y + lh * 2)
    love.graphics.print(string.format(
        "Speed:  %.0f  | Lv: %d  Exp: %d/%d",
        _player.speed, _player:getLevel(),
        _player._exp, _player._expToNext), x, y + lh * 3)
    love.graphics.print(string.format(
        "Souls:  %d  | PickupR: %.0f",
        _player:getSouls(), _player.pickupRadius), x, y + lh * 4)

    -- 战斗数据
    love.graphics.print(string.format(
        "Enemies: %d  | Projectiles: %d",
        #_enemies, #_projectiles), x, y + lh * 5)
    love.graphics.print(string.format(
        "AtkTimer: %.2f / %.2f",
        _attackTimer, AUTO_ATTACK_INTERVAL), x, y + lh * 6)

    -- 生成系统数据
    love.graphics.print(string.format(
        "Spawner: interval=%.2f  batch=%d",
        _spawner._interval, _spawner._batchSize), x, y + lh * 7)
    love.graphics.print(string.format(
        "Elapsed: %.1f s",
        _spawner._elapsed), x, y + lh * 8)

    -- FPS
    love.graphics.setColor(1, 1, 0.4)
    love.graphics.print(string.format(
        "FPS: %d", love.timer.getFPS()), x, y + lh * 9)
end

-- 键盘按下事件
-- @param key: 按下的键名
function Game:keypressed(key)
end

return Game
