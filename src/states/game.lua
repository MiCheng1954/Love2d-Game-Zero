--[[
    src/states/game.lua
    游戏主状态，局内核心玩法的入口
    Phase 6：接入武器背包系统，自动攻击由背包所有武器独立触发
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
local Weapon     = require("src.entities.weapon")
local Log        = require("src.utils.log")

local Game = {}

local _player      = nil   -- 玩家实例
local _camera      = nil   -- 摄像机实例
local _enemies     = {}    -- 当前场景所有敌人列表
local _projectiles = {}    -- 当前场景所有投射物列表
local _pickups     = {}    -- 当前场景所有掉落物列表
local _spawner     = nil   -- 敌人生成系统实例
local _experience  = nil   -- 经验升级系统实例
local _pendingUpgrade = nil  -- 待处理的升级跳转数据（当帧 update 结束后再切换，防止 exit 破坏帧内状态）

-- 自动攻击配置（无装备武器时的 fallback 参数）
local FALLBACK_ATTACK_INTERVAL = 1.0   -- fallback 攻击间隔（秒）
local FALLBACK_ATTACK_DAMAGE   = 20    -- fallback 伤害
local FALLBACK_ATTACK_SPEED    = 450   -- fallback 子弹速度
local FALLBACK_ATTACK_RANGE    = 350   -- fallback 索敌范围

local _attackTimer = 0             -- 攻击冷却计时器（秒）-- 已弃用，保留供注释参考
local _fallbackTimer = 0           -- fallback 攻击冷却计时器
local _paused = false              -- 游戏是否暂停

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
    _fallbackTimer = 0
    _paused        = false

    -- 初始化玩家
    _player = Player.new(0, 0)
    Log.info("游戏开始，玩家初始化完毕")

    -- 初始化摄像机
    _camera = Camera.new(1280, 720)
    _camera:setTarget(_player)

    -- 初始化生成系统
    _spawner = Spawner.new(_enemies)
    _spawner:setTarget(_player)

    -- 初始化经验系统，注册升级回调
    _experience = Experience.new(_player)
    _experience:onLevelUp(function(player, newLevel)
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
    _fallbackTimer   = 0
end

-- 每帧更新游戏逻辑
-- @param dt: 距上一帧的时间间隔（秒）
function Game:update(dt)
    Input.update()

    -- P 键切换暂停（不受暂停本身阻断，始终响应）
    if Input.isPressed("pause") then
        _paused = not _paused
        Log.info(_paused and "游戏暂停" or "游戏继续")
    end

    -- 暂停时跳过所有游戏逻辑，仅允许 TAB 打开背包和 ESC 返回菜单
    if _paused then
        -- TAB 暂停时也可查看背包（BROWSE 只读模式）
        if Input.isPressed("openBag") then
            local StateManager = require("src.states.stateManager")
            StateManager.push("bagUI", {
                bag     = _player:getBag(),
                mode    = "browse",
                onClose = function() StateManager.pop() end,
            })
        end
        return
    end

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
        Log.info(string.format("玩家死亡 — Lv%d  elapsed=%.1fs  enemies=%d",
            _player:getLevel(), _spawner._elapsed, #_enemies))
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

    -- TAB 呼出背包（BROWSE 模式）
    if Input.isPressed("openBag") then
        local StateManager = require("src.states.stateManager")
        StateManager.push("bagUI", {
            bag     = _player:getBag(),
            mode    = "browse",
            onClose = function()
                StateManager.pop()
            end,
        })
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
            -- 获得新武器/需选武器时推入背包界面
            -- weapon == "__select__" 时为 SELECT 模式（武器升级选择），否则为 PLACE 模式
            onWeaponDrop = function(weapon, onDone, selectOpts)
                if weapon == "__select__" then
                    -- SELECT 模式：让玩家选一把武器升级
                    StateManager.push("bagUI", {
                        bag        = _player:getBag(),
                        mode       = "select",
                        filter     = selectOpts and selectOpts.filter,
                        selectHint = selectOpts and selectOpts.hint,
                        onSelect   = function(w)
                            if selectOpts and selectOpts.onSelect then
                                selectOpts.onSelect(w)
                            end
                            StateManager.pop()         -- pop bagUI
                            if onDone then onDone() end -- pop upgrade
                        end,
                    })
                else
                    -- PLACE 模式：放置新获得的武器
                    StateManager.push("bagUI", {
                        bag       = _player:getBag(),
                        mode      = "place",
                        weapon    = weapon,
                        onPlace   = function()
                            StateManager.pop()
                            if onDone then onDone() end
                        end,
                        onDiscard = function()
                            StateManager.pop()
                            if onDone then onDone() end
                        end,
                    })
                end
            end,
            onDone = function()
                StateManager.pop()
            end,
        })
    end
end

-- 自动攻击：背包中每把武器独立计时，各自锁定最近的敌人发射子弹
-- 若背包为空则使用 fallback 参数维持基本攻击能力
-- @param dt: 距上一帧的时间间隔（秒）
function Game._updateAutoAttack(dt)
    local bag     = _player:getBag()
    local weapons = bag:getAllWeapons()

    if #weapons > 0 then
        -- 每把武器独立计时、独立索敌、独立发射
        for _, weapon in ipairs(weapons) do
            local shots = weapon:tickAttack(dt)
            if shots > 0 then
                local target = Game._findNearestEnemyInRange(weapon.range)
                if target then
                    for _ = 1, shots do
                        local dx, dy = MathUtils.normalize(
                            target.x - _player.x,
                            target.y - _player.y)
                        local proj = Projectile.new(
                            _player.x, _player.y,
                            dx, dy,
                            weapon:getEffectiveDamage(_player.attack),
                            weapon.bulletSpeed)
                        proj._critRate = _player.critRate
                        table.insert(_projectiles, proj)
                    end
                end
            end
        end
    else
        -- Fallback：无武器时维持基础攻击
        _fallbackTimer = _fallbackTimer + dt
        if _fallbackTimer >= FALLBACK_ATTACK_INTERVAL then
            _fallbackTimer = _fallbackTimer - FALLBACK_ATTACK_INTERVAL
            local target = Game._findNearestEnemyInRange(FALLBACK_ATTACK_RANGE)
            if target then
                local dx, dy = MathUtils.normalize(
                    target.x - _player.x,
                    target.y - _player.y)
                local proj = Projectile.new(
                    _player.x, _player.y,
                    dx, dy,
                    FALLBACK_ATTACK_DAMAGE,
                    FALLBACK_ATTACK_SPEED)
                proj._critRate = _player.critRate
                table.insert(_projectiles, proj)
            end
        end
    end
end

-- 在所有敌人中寻找距离玩家最近且在指定范围内的目标（索敌接口，Phase 7+ 可替换）
-- @param range: 最大索敌距离（像素）
-- @return 最近的 Enemy 实例，若无则返回 nil
function Game._findNearestEnemyInRange(range)
    local nearest = nil
    local minDist = range

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

    -- 暂停遮罩
    if _paused then
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle("fill", 0, 0, 1280, 720)
        love.graphics.setColor(1, 0.85, 0.1)
        Font.set(28)
        love.graphics.printf(T("hud.paused"), 0, 320, 1280, "center")
        Font.set(15)
        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.printf(T("hud.pause_hint"), 0, 368, 1280, "center")
        Font.set(13)
    end

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

    local bag     = _player:getBag()
    local weapons = bag:getAllWeapons()
    -- 面板高度根据武器数量动态调整
    local panelH  = lh * (11 + math.max(1, #weapons)) + 8

    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", x - 8, y - 4, 370, panelH)

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

    -- 背包信息
    love.graphics.print(string.format(
        "Bag: %dx%d  | Weapons: %d",
        bag.cols, bag.rows, #weapons), x, y + lh * 6)

    -- 每把武器独立一行
    if #weapons == 0 then
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.print("  (no weapon - fallback)", x, y + lh * 7)
    else
        for i, w in ipairs(weapons) do
            love.graphics.setColor(w.color[1], w.color[2], w.color[3])
            love.graphics.print(string.format(
                "  W%d: %-8s Lv%d  spd=%.1f tmr=%.2f",
                i, w.configId, w.level, w.attackSpeed, w._attackTimer),
                x, y + lh * (6 + i))
        end
    end

    local weaponRows = math.max(1, #weapons)
    local baseRow    = 7 + weaponRows

    love.graphics.setColor(1, 1, 0.4)
    love.graphics.print(string.format(
        "FPS: %d", love.timer.getFPS()), x, y + lh * baseRow)

    -- Spawner 信息
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(string.format(
        "Spawner: interval=%.2f  batch=%d",
        _spawner._interval, _spawner._batchSize), x, y + lh * (baseRow + 1))
    love.graphics.print(string.format(
        "Elapsed: %.1f s  | Paused: %s",
        _spawner._elapsed, tostring(_paused)), x, y + lh * (baseRow + 2))

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
