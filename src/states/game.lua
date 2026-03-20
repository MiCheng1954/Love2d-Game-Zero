--[[
    src/states/game.lua
    游戏主状态，局内核心玩法的入口
    Phase 4：接入掉落物、吸附、经验升级系统
]]

local Timer      = require("src.utils.timer")
local MathUtils  = require("src.utils.math")
local Font       = require("src.utils.font")
local Input      = require("src.systems.input")
local Camera     = require("src.systems.camera")
local Collision  = require("src.systems.collision")
local Spawner    = require("src.systems.spawner")
local Experience = require("src.systems.experience")
local Player     = require("src.entities.player")
local Projectile = require("src.entities.projectile")

local Game = {}

local _player      = nil   -- 玩家实例
local _camera      = nil   -- 摄像机实例
local _enemies     = {}    -- 当前场景所有敌人列表
local _projectiles = {}    -- 当前场景所有投射物列表
local _pickups     = {}    -- 当前场景所有掉落物列表
local _spawner     = nil   -- 敌人生成系统实例
local _experience  = nil   -- 经验升级系统实例
local _pendingUpgrade = nil  -- 待处理的升级跳转数据（当帧 update 结束后再切换，防止 exit 破坏帧内状态）

-- 自动攻击配置
local AUTO_ATTACK_INTERVAL = 0.5   -- 自动攻击间隔（秒）
local AUTO_ATTACK_DAMAGE   = 20    -- 每发子弹伤害
local AUTO_ATTACK_SPEED    = 450   -- 子弹飞行速度（像素/秒）
local AUTO_ATTACK_RANGE    = 350   -- 自动锁定的最大距离（像素）

local _attackTimer = 0             -- 攻击冷却计时器（秒）

-- 升级提示浮窗状态
local _levelUpNotice = {
    active   = false,  -- 是否显示中
    level    = 0,      -- 升级后的等级
    timer    = 0,      -- 剩余显示时间（秒）
    duration = 2.5,    -- 总显示时长（秒）
}

-- 进入游戏状态时调用，负责初始化所有局内数据
function Game:enter()
    Timer.clear()

    -- 初始化列表
    _enemies     = {}
    _projectiles = {}
    _pickups     = {}
    _attackTimer = 0

    -- 初始化玩家
    _player = Player.new(0, 0)

    -- 初始化摄像机
    _camera = Camera.new(1280, 720)
    _camera:setTarget(_player)

    -- 初始化生成系统
    _spawner = Spawner.new(_enemies)
    _spawner:setTarget(_player)

    -- 初始化经验系统，注册升级回调
    _experience = Experience.new(_player)
    _experience:onLevelUp(function(player, newLevel)
        -- 不立即切换，先记录待处理数据，等当帧 update 结束后再跳转
        -- 防止 StateManager.switch 触发 exit() 清空 _spawner 等变量，导致帧内后续逻辑崩溃
        _pendingUpgrade = {
            player = player,
            newLevel = newLevel,
        }
    end)
end

-- 退出游戏状态时调用
function Game:exit()
    Timer.clear()
    _player          = nil
    _camera          = nil
    _enemies         = {}
    _projectiles     = {}
    _pickups         = {}
    _spawner         = nil
    _experience      = nil
    _pendingUpgrade  = nil
end

-- 每帧更新游戏逻辑
-- @param dt: 距上一帧的时间间隔（秒）
function Game:update(dt)
    Input.update()
    Timer.update(dt)

    -- 更新玩家
    _player:update(dt)

    -- 更新升级提示倒计时
    if _levelUpNotice.active then
        _levelUpNotice.timer = _levelUpNotice.timer - dt
        if _levelUpNotice.timer <= 0 then
            _levelUpNotice.active = false
        end
    end

    -- 更新经验系统（检测升级）
    _experience:update(dt)

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

    -- 更新所有掉落物（含吸附逻辑）
    for _, pickup in ipairs(_pickups) do
        pickup:update(dt, _player)
    end

    -- 自动攻击
    Game._updateAutoAttack(dt)

    -- 碰撞检测：子弹 vs 敌人，获取击杀列表（含掉落物）
    local kills = Collision.projectilesVsEnemies(_projectiles, _enemies)
    for _, killData in ipairs(kills) do
        -- 将掉落物加入场景
        for _, pickup in ipairs(killData.pickups) do
            table.insert(_pickups, pickup)
        end
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
    Collision.clearDead(_pickups)

    -- 更新摄像机
    _camera:update(dt)

    -- TAB 呼出背包（Phase 6 接入）
    if Input.isPressed("openBag") then
        -- TODO: Phase 6
    end

    -- ESC 返回菜单：移至 keypressed 事件处理，避免控制台/面板关闭时的按键残留穿透

    -- 处理待跳转升级界面（必须放在 update 最末尾，防止 exit 破坏帧内状态）
    if _pendingUpgrade then
        local data = _pendingUpgrade
        _pendingUpgrade = nil
        local StateManager = require("src.states.stateManager")
        -- push 而非 switch：保留游戏状态不调用 exit，选完后 pop 回来不调用 enter
        StateManager.push("upgrade", {
            player = data.player,
            onDone = function()
                StateManager.pop()
            end,
        })
    end
end

-- 自动攻击：每隔一定时间向最近的敌人发射子弹
-- @param dt: 距上一帧的时间间隔（秒）
function Game._updateAutoAttack(dt)
    _attackTimer = _attackTimer + dt
    if _attackTimer < AUTO_ATTACK_INTERVAL then return end

    local nearest = Game._findNearestEnemy()
    if not nearest then return end

    _attackTimer = _attackTimer - AUTO_ATTACK_INTERVAL

    local dx, dy = MathUtils.normalize(
        nearest.x - _player.x,
        nearest.y - _player.y)

    local proj = Projectile.new(
        _player.x, _player.y,
        dx, dy,
        AUTO_ATTACK_DAMAGE,
        AUTO_ATTACK_SPEED)

    proj._critRate = _player.critRate

    table.insert(_projectiles, proj)
end

-- 在所有敌人中寻找距离玩家最近且在范围内的目标
-- @return 最近的 Enemy 实例，若无则返回 nil
function Game._findNearestEnemy()
    local nearest = nil
    local minDist = AUTO_ATTACK_RANGE

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

    -- 绘制所有掉落物（最底层）
    for _, pickup in ipairs(_pickups) do
        pickup:draw()
    end

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
    Font.set(13)
    love.graphics.print(T("hud.hp") .. " " .. _player.hp .. " / " .. _player.maxHp, 24, 22)

    -- 经验条背景
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", 20, 42, 200, 10)

    -- 经验条前景
    love.graphics.setColor(0.2, 0.8, 0.4)
    love.graphics.rectangle("fill", 20, 42, 200 * _player:getExpProgress(), 10)

    -- 等级、灵魂、敌人数、掉落物数
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(T("hud.level") .. _player:getLevel(), 20, 58)
    love.graphics.print(T("hud.souls") .. ": " .. _player:getSouls(), 20, 76)
    love.graphics.print(T("hud.enemies") .. ": " .. #_enemies, 20, 94)

    -- 操作提示
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.print(T("hud.hint"), 20, 695)

    -- 升级提示浮窗
    if _levelUpNotice.active then
        -- 计算淡出透明度（最后 0.8 秒开始淡出）
        local alpha = 1.0
        if _levelUpNotice.timer < 0.8 then
            alpha = _levelUpNotice.timer / 0.8
        end

        -- 浮窗背景
        love.graphics.setColor(0.1, 0.1, 0.1, 0.85 * alpha)
        love.graphics.rectangle("fill", 490, 280, 300, 70, 8, 8)

        -- 边框
        love.graphics.setColor(1, 0.85, 0.1, alpha)
        love.graphics.rectangle("line", 490, 280, 300, 70, 8, 8)

        -- 标题
        love.graphics.setColor(1, 0.85, 0.1, alpha)
        love.graphics.printf(T("upgrade.title"), 490, 292, 300, "center")

        -- 等级文字
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.printf(
            T("upgrade.reached", _levelUpNotice.level),
            490, 316, 300, "center")
    end

    -- 调试日志面板（右上角）
    Game._drawDebugPanel()
end

-- 绘制调试日志面板
function Game._drawDebugPanel()
    local x  = 900
    local y  = 20
    local lh = 16

    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", x - 8, y - 4, 370, 220)

    love.graphics.setColor(0.4, 1, 0.4)
    Font.set(13)
    love.graphics.print(T("debug.title"), x, y)

    love.graphics.setColor(1, 1, 1)
    love.graphics.print(string.format(
        "Pos:    (%.0f, %.0f)",
        _player.x, _player.y), x, y + lh * 1)
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
    love.graphics.print(string.format(
        "Enemies: %d  | Projs: %d  | Pickups: %d",
        #_enemies, #_projectiles, #_pickups), x, y + lh * 5)
    love.graphics.print(string.format(
        "AtkTimer: %.2f / %.2f",
        _attackTimer, AUTO_ATTACK_INTERVAL), x, y + lh * 6)
    love.graphics.print(string.format(
        "Spawner: interval=%.2f  batch=%d",
        _spawner._interval, _spawner._batchSize), x, y + lh * 7)
    love.graphics.print(string.format(
        "Elapsed: %.1f s",
        _spawner._elapsed), x, y + lh * 8)

    love.graphics.setColor(1, 1, 0.4)
    love.graphics.print(string.format(
        "FPS: %d", love.timer.getFPS()), x, y + lh * 9)

    Font.reset()
end

-- 键盘按下事件（keypressed 是一次性事件，不会被跨状态按键残留触发）
-- @param key: 按下的键名
function Game:keypressed(key)
    if key == "escape" then
        local StateManager = require("src.states.stateManager")
        StateManager.switch("menu")
    end
end

-- ============================================================
-- 外部访问器（供 main.lua 功能键注入数据给控制台/Bug反馈）
-- ============================================================

-- 返回当前玩家实例（可能为 nil，如不在游戏状态中）
function Game._getPlayer()
    return _player
end

-- 返回当前敌人列表
function Game._getEnemies()
    return _enemies
end

-- 返回当前生成系统实例
function Game._getSpawner()
    return _spawner
end

-- 触发一次升级界面（供控制台 levelup 指令使用）
function Game._triggerLevelUp()
    if _player then
        _pendingUpgrade = {
            player   = _player,
            newLevel = _player:getLevel(),
        }
    end
end

return Game
