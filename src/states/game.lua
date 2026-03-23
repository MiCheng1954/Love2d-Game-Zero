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
local SkillSynergy   = require("src.systems.skillSynergy")
local FX             = require("src.systems.skillEffects")   -- Phase 8 需求1
local RhythmController = require("src.systems.rhythmController")  -- Phase 9
local LegacyManager    = require("src.systems.legacyManager")      -- Phase 10
local HUD              = require("src.ui.hud")                     -- Phase 11
local SceneManager     = require("src.systems.sceneManager")       -- Phase 12
local Player     = require("src.entities.player")
local Projectile = require("src.entities.projectile")
local Weapon     = require("src.entities.weapon")
local Boss       = require("src.entities.boss")   -- Phase 9
local Log        = require("src.utils.log")

local Game = {}

local _player      = nil   -- 玩家实例
local _camera      = nil   -- 摄像机实例
local _enemies     = {}    -- 当前场景所有敌人列表
local _projectiles = {}    -- 当前场景所有投射物列表
local _pickups     = {}    -- 当前场景所有掉落物列表
local _spawner     = nil   -- 敌人生成系统实例
local _experience  = nil   -- 经验升级系统实例
local _rhythm      = nil   -- 节奏控制器实例（Phase 9）
local _boss        = nil   -- 当前活跃的 Boss 实例（Phase 9，nil=无Boss）
local _pendingUpgrade = nil  -- 待处理的升级跳转数据（当帧 update 结束后再切换，防止 exit 破坏帧内状态）

-- Phase 9：胜利状态
local _victory = false         -- 是否已触发胜利
local _victoryTimer = 0        -- 胜利画面停留计时（秒）
local VICTORY_DELAY = 4.0      -- 胜利后 N 秒跳转

-- 自动攻击配置（无装备武器时的 fallback 参数）
local FALLBACK_ATTACK_INTERVAL = 1.0   -- fallback 攻击间隔（秒）
local FALLBACK_ATTACK_DAMAGE   = 20    -- fallback 伤害
local FALLBACK_ATTACK_SPEED    = 450   -- fallback 子弹速度
local FALLBACK_ATTACK_RANGE    = 350   -- fallback 索敌范围

local _attackTimer = 0             -- 攻击冷却计时器（秒）-- 已弃用，保留供注释参考
local _fallbackTimer = 0           -- fallback 攻击冷却计时器
local _paused = false              -- 游戏是否暂停

-- Phase 10：统计数据
local _killCount    = 0    -- 本局总击杀数
local _killedBosses = {}   -- 本局击杀的 Boss 列表（id 字符串数组）

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
    _boss          = nil    -- Phase 9
    _victory       = false
    _victoryTimer  = 0

    -- Phase 10：统计数据重置
    _killCount    = 0
    _killedBosses = {}

    -- 初始化玩家
    _player = Player.new(0, 0)
    Log.info("游戏开始，玩家初始化完毕")

    -- 初始化摄像机
    _camera = Camera.new(1280, 720)
    _camera:setTarget(_player)

    -- 初始化生成系统
    _spawner = Spawner.new(_enemies, _projectiles)
    _spawner:setTarget(_player)
    _spawner:setSkillManager(_player:getSkillManager())  -- Bug#20：传入技能管理器

    -- Phase 9：初始化节奏控制器
    _rhythm = RhythmController.new()

    -- Phase 12：通知场景进入，传入 Spawner 自定义生成函数
    local scene = SceneManager.get()
    if scene then
        SceneManager.enter(_player)
        local spawnFn = scene:getSpawnOverride()
        if type(spawnFn) == "function" then
            _spawner:setSpawnOverride(spawnFn)
        end
    end

    -- 初始化经验系统，注册升级回调
    _experience = Experience.new(_player)
    _experience:onLevelUp(function(player, newLevel)
        -- Bug#40：胜利后不再弹出升级界面
        if _victory then return end
        _pendingUpgrade = {
            player = player,
            newLevel = newLevel,
        }
    end)
end

-- 退出游戏状态时调用
function Game:exit()
    -- Phase 12：通知场景退出
    SceneManager.exit()

    Timer.clear()
    _player          = nil
    _camera          = nil
    _enemies         = {}
    _projectiles     = {}
    _pickups         = {}
    _spawner         = nil
    _experience      = nil
    _rhythm          = nil   -- Phase 9
    _boss            = nil   -- Phase 9
    _pendingUpgrade  = nil
    _fallbackTimer   = 0
    _victory         = false
    _killCount       = 0
    _killedBosses    = {}
    FX.clear()   -- 需求1：清除所有视觉特效
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
                player  = _player,          -- 需求4：传入 player 供技能列表展示
                mode    = "browse",
                onClose = function() StateManager.pop() end,
            })
        end
        return
    end

    Timer.update(dt)

    -- Phase 7.2：读取 playerSynergyBonus，应用到玩家全局属性
    local bag = _player:getBag()
    local psb = bag._playerSynergyBonus or {}

    -- Phase 8：纯被动技能每帧重新累加到临时 psb 副本
    -- 注意：技能 psb 是每帧临时叠加，不持久存储到 bag._playerSynergyBonus
    local sm = _player:getSkillManager()
    local skillPsb = {}
    sm:recalcPassive(skillPsb)
    local skillActiveSynergies = SkillSynergy.recalculate(sm, skillPsb)

    -- 合并技能 psb 到武器 psb（逻辑层统一用 mergedPsb）
    local mergedPsb = {}
    for k, v in pairs(psb)      do mergedPsb[k] = v end
    for k, v in pairs(skillPsb) do mergedPsb[k] = (mergedPsb[k] or 0) + v end

    -- Phase 10：叠加传承加成到 mergedPsb
    if _player._legacyBulletSpeed and _player._legacyBulletSpeed > 0 then
        mergedPsb.bulletSpeed = (mergedPsb.bulletSpeed or 0) + _player._legacyBulletSpeed
    end
    if _player._legacyCdReduce and _player._legacyCdReduce > 0 then
        mergedPsb.cdReduce = (mergedPsb.cdReduce or 0) + _player._legacyCdReduce
    end
    if _player._legacyExpMult and _player._legacyExpMult > 0 then
        mergedPsb.expMult = (mergedPsb.expMult or 0) + _player._legacyExpMult
    end

    -- maxHP 加成：检测变化并同步当前 HP（避免每帧重复叠加，用 _psbMaxHP 缓存上次值）
    local psbMaxHP = mergedPsb.maxHP or 0
    if psbMaxHP ~= (_player._psbMaxHPLast or 0) then
        local delta = psbMaxHP - (_player._psbMaxHPLast or 0)
        _player.maxHp = _player.maxHp + delta
        _player.hp    = math.min(_player.hp + math.max(0, delta), _player.maxHp)
        _player._psbMaxHPLast = psbMaxHP
    end
    -- pickupRange 加成：同样用缓存避免重复叠加
    local psbPickup = mergedPsb.pickupRange or 0
    if psbPickup ~= (_player._psbPickupLast or 0) then
        local delta = psbPickup - (_player._psbPickupLast or 0)
        _player.pickupRadius = _player.pickupRadius + delta
        _player._psbPickupLast = psbPickup
    end
    -- expMult 加成：同样用缓存（+25 = +0.25）
    local psbExpMult = (mergedPsb.expMult or 0) / 100
    if psbExpMult ~= (_player._psbExpMultLast or 0) then
        local delta = psbExpMult - (_player._psbExpMultLast or 0)
        _player.expBonus = _player.expBonus + delta
        _player._psbExpMultLast = psbExpMult
    end
    -- Phase 8：defense 加成（百分比，0~1）
    -- 直接每帧写入（不累加到基础值，避免叠加），覆盖 entity 基础 defense=0
    _player.defense = math.min(0.9, (mergedPsb.defense or 0))

    -- 更新玩家（传入 mergedPsb.speed 作为额外速度加成）
    _player:update(dt, mergedPsb.speed or 0)

    -- Phase 8：更新技能系统（定时触发、持续 buff 衰减等）
    local skillCtx = {
        dx           = _player._lastDx or _player._dx,   -- Bug#29：用最后移动方向
        dy           = _player._lastDy or _player._dy,
        enemies      = _enemies,
        projectiles  = _projectiles,
        bag          = _player:getBag(),
        skillManager = sm,    -- Bug#20：让技能 effect 能调用 setGlobalSlow
    }
    sm:update(dt, _player, skillCtx, mergedPsb.cdReduce)
    -- Bug#26：被动技能触发视觉效果
    for _, firedId in ipairs(sm._firedThisFrame or {}) do
        FX.spawn(firedId, _player, skillCtx)
    end
    FX.update(dt)   -- 需求1：更新技能视觉特效
    FX.syncBuffs(_player)   -- Bug#49：同步 Buff 持续特效（超载/战吼/狂怒/护盾）

    -- Phase 11：更新 HUD 内部动画（低血量脉冲等）
    HUD.update(dt)

    -- 更新升级提示倒计时
    if _levelUpNotice.active then
        _levelUpNotice.timer = _levelUpNotice.timer - dt
        if _levelUpNotice.timer <= 0 then
            _levelUpNotice.active = false
        end
    end

    -- 更新经验系统（检测升级）
    _experience:update(dt)

    -- Phase 9：更新节奏控制器
    _rhythm:update(dt)

    -- Phase 9：消费待触发的 Boss
    -- Phase 12：若场景有专属 bossPool，只触发 pool 内的 Boss
    local pendingBosses = _rhythm:getPendingBosses()
    local sceneBossPool = scene and scene:getBossPool()
    for _, bossCfg in ipairs(pendingBosses) do
        -- 场景 bossPool 过滤：若场景定义了专属池，跳过不在池内的 Boss
        if sceneBossPool then
            local inPool = false
            for _, poolId in ipairs(sceneBossPool) do
                if poolId == bossCfg.id then inPool = true; break end
            end
            if not inPool then goto skipBoss end
        end
        if not _boss or _boss._isDead then
            -- 在玩家周围随机方向 600px 处生成 Boss
            local angle = math.random() * math.pi * 2
            local bx    = _player.x + math.cos(angle) * 600
            local by    = _player.y + math.sin(angle) * 600
            _boss = Boss.new(bx, by, bossCfg)
            _boss:setTarget(_player)
            _boss:setProjectileList(_projectiles)
            Log.info("Boss 登场：" .. bossCfg.id .. "（phase " .. (bossCfg.phase or "?") .. "min）")
        end
        ::skipBoss::
    end

    -- Phase 9：更新 Boss
    if _boss and not _boss._isDead then
        _boss:update(dt)
        -- Boss 接触伤害
        local dx = _player.x - _boss.x
        local dy = _player.y - _boss.y
        if math.sqrt(dx*dx + dy*dy) <= (_boss._radius + 18) then
            _boss:tryContactDamage(_player)
        end
        -- Boss 召唤技能：处理 _summonPending（由技能 effect 写入）
        if _boss._summonPending and _boss._summonPending > 0 then
            local count = _boss._summonPending
            _boss._summonPending = 0
            for _ = 1, count do
                local angle  = math.random() * math.pi * 2
                local dist   = 200 + math.random() * 150
                local sx     = _boss.x + math.cos(angle) * dist
                local sy     = _boss.y + math.sin(angle) * dist
                local minion = require("src.entities.enemy").new(sx, sy, "basic")
                minion:setTarget(_player)
                if _projectiles then
                    minion:setProjectileList(_projectiles)
                end
                table.insert(_enemies, minion)
            end
            Log.info("Boss 召唤了 " .. count .. " 只小兵")
        end
    end

    -- 更新生成系统（传入节奏控制器参数）
    local spawnParams = _rhythm:getSpawnParams()
    -- Phase 12：场景可缩短生成间隔
    local scene = SceneManager.get()
    if scene then
        local so = scene._cfg and scene._cfg.spawnOverride
        if so and so.intervalScale then
            spawnParams = {
                interval     = spawnParams.interval * so.intervalScale,
                batchSize    = spawnParams.batchSize,
                eliteChance  = spawnParams.eliteChance,
                rangerChance = spawnParams.rangerChance,
            }
        end
        -- 场景逻辑更新（竞技场边界伤害等）
        scene:update(dt, _player)
    end
    _spawner:update(dt, spawnParams, _rhythm:getElapsed())

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
        -- Phase 8：通知技能系统击杀事件
        sm:onKill(_player, killData.enemy, skillCtx)
        -- Phase 10：统计击杀数
        _killCount = _killCount + 1
    end

    -- Phase 9：子弹 vs Boss 碰撞检测
    if _boss and not _boss._isDead then
        local bossPickups = Collision.projectilesVsBoss(_projectiles, _boss)
        if bossPickups then
            -- Boss 死亡：处理掉落和胜利判断
            for _, pickup in ipairs(bossPickups) do
                table.insert(_pickups, pickup)
            end
            Log.info("Boss 击败：" .. _boss._typeName .. "  isFinal=" .. tostring(_boss._isFinal))
            -- Phase 10：记录被击杀的 Boss
            table.insert(_killedBosses, _boss._typeName or _boss._bossName or "unknown")
            -- Phase 12：冲锋者死亡分裂为 6 只 fast 小兵
            if _boss._typeName == "charger" then
                local Enemy = require("src.entities.enemy")
                for i = 1, 6 do
                    local angle  = (i / 6) * math.pi * 2
                    local mx     = _boss.x + math.cos(angle) * 60
                    local my     = _boss.y + math.sin(angle) * 60
                    local minion = Enemy.new(mx, my, "fast")
                    minion:setTarget(_player)
                    table.insert(_enemies, minion)
                end
                Log.info("冲锋者分裂：生成 6 只 fast 小兵")
            end
            if _boss._isFinal then
                _victory = true
                _victoryTimer = VICTORY_DELAY
                Log.info("最终 Boss 已击败，触发胜利！")
            end
        end
    end

    -- Phase 9：敌方投射物 vs 玩家碰撞检测
    local enemyProjDmg = Collision.enemyProjectilesVsPlayer(_projectiles, _player)
    if enemyProjDmg and enemyProjDmg > 0 then
        sm:onHit(_player, enemyProjDmg, skillCtx)
    end

    -- Bug#28：扫描被技能 AOE 打死但未走击杀流水线的敌人，补全掉落和 onKill 事件
    local Pickup = require("src.entities.pickup")
    for _, enemy in ipairs(_enemies) do
        if enemy._isDead and enemy._dropProcessed == false then
            enemy._dropProcessed = true
            -- Phase 12：场景掉落倍率
            local dropMult = { soul = 1.0, exp = 1.0 }
            local activeScene = SceneManager.get()
            if activeScene then
                local dm = activeScene:getDropMultiplier()
                if dm then
                    dropMult.soul = dm.soul or 1.0
                    dropMult.exp  = dm.exp  or 1.0
                end
            end
            -- 手动生成掉落（复用 enemy 的配置值，避免重复调用 onDeath）
            if enemy._expDrop and enemy._expDrop > 0 then
                local expAmt = math.floor(enemy._expDrop * dropMult.exp)
                table.insert(_pickups, Pickup.new(enemy.x, enemy.y, Pickup.TYPE.EXP, expAmt))
            end
            if enemy._soulDrop and enemy._soulDrop > 0 then
                local soulAmt = math.floor(enemy._soulDrop * dropMult.soul)
                table.insert(_pickups, Pickup.new(
                    enemy.x + math.random(-10, 10),
                    enemy.y + math.random(-10, 10),
                    Pickup.TYPE.SOUL, soulAmt))
            end
            -- 通知技能系统击杀事件（触发 onkill 被动技能）
            sm:onKill(_player, enemy, skillCtx)
            -- Phase 10：统计击杀数
            _killCount = _killCount + 1
        end
    end

    -- 碰撞检测：敌人 vs 玩家（Phase 8：收集伤害量并通知 onHit）
    local playerDmgTaken = Collision.enemiesVsPlayer(_enemies, _player)
    if playerDmgTaken and playerDmgTaken > 0 then
        sm:onHit(_player, playerDmgTaken, skillCtx)
    end

    -- 检测玩家死亡（Phase 10：接入复活/传承系统）
    if _player:isDead() then
        -- Phase 10.1：死亡前清除所有 Buff，确保属性（attack 等）还原
        _player._buffManager:clear(_player)
        Log.info(string.format("玩家死亡 — Lv%d  elapsed=%.1fs  enemies=%d  kills=%d",
            _player:getLevel(), _rhythm:getElapsed(), #_enemies, _killCount))
        local StateManager = require("src.states.stateManager")
        -- 构建结算数据
        local summaryData = {
            isVictory    = false,
            elapsed      = _rhythm:getElapsed(),
            level        = _player:getLevel(),
            killCount    = _killCount,
            souls        = _player:getSouls(),
            activeSynergies = _player:getBag()._activeSynergies or {},
            killedBosses = _killedBosses,
        }
        -- Phase 10：检查复活次数
        if _player._revives and _player._revives > 0 then
            -- 有复活机会：弹出复活/传承二选一界面
            StateManager.push("reviveUI", {
                player      = _player,
                summaryData = summaryData,
                enemies     = _enemies,
                onRevive    = function()
                    StateManager.pop()
                    -- 复活：减少次数，清场，施加无敌
                    _player._revives = _player._revives - 1
                    _player.hp = _player.maxHp
                    _player._isDead = false   -- 重置死亡标记
                    -- 清除玩家周围的敌人
                    local clearRadius = 200
                    for i = #_enemies, 1, -1 do
                        local e = _enemies[i]
                        local dx = e.x - _player.x
                        local dy = e.y - _player.y
                        if math.sqrt(dx*dx + dy*dy) <= clearRadius then
                            e._isDead = true
                        end
                    end
                    -- 施加无敌帧（Phase 10.1：通过 BuffManager 管理）
                    _player._buffManager:add("invincible", 3.0, {}, _player)
                    Log.info("玩家复活！剩余复活次数：" .. _player._revives)
                end,
                onLegacy    = function()
                    StateManager.pop()
                    -- 选择传承：进入传承三选一界面
                    StateManager.push("legacySelect", {
                        player      = _player,
                        summaryData = summaryData,
                        activeSynergies = _player:getBag()._activeSynergies or {},
                        onDone      = function()
                            StateManager.pop()
                            StateManager.switch("gameover", summaryData)
                        end,
                    })
                end,
            })
        else
            -- 无复活机会：直接跳转死亡结算，清除传承（没有选传承机会）
            LegacyManager.clear()
            StateManager.switch("gameover", summaryData)
        end
        return
    end

    -- Phase 9：胜利倒计时（击败最终 Boss 后）
    if _victory then
        _victoryTimer = _victoryTimer - dt
        if _victoryTimer <= 0 then
            local StateManager = require("src.states.stateManager")
            -- 胜利通关：清除传承存档（胜利不触发传承选择）
            LegacyManager.clear()
            StateManager.switch("gameover", {
                isVictory    = true,
                elapsed      = _rhythm:getElapsed(),
                level        = _player:getLevel(),
                killCount    = _killCount,
                souls        = _player:getSouls(),
                activeSynergies = _player:getBag()._activeSynergies or {},
                killedBosses = _killedBosses,
            })
            return   -- 切换状态后立即返回，避免访问已被 exit() 清空的状态
        end
        -- 胜利状态：不再更新敌人/生成，直接进入最终清理和跳转
        goto continueAfterVictory
    end

    -- 清理死亡实体
    Collision.clearDead(_enemies)
    Collision.clearDead(_projectiles)
    Collision.clearDead(_pickups)

    -- Phase 9：清理死亡的 Boss 引用
    if _boss and _boss._isDead then
        _boss = nil
    end

    ::continueAfterVictory::

    -- 更新摄像机
    _camera:update(dt)

    -- TAB 呼出背包（BROWSE 模式）
    if Input.isPressed("openBag") then
        local StateManager = require("src.states.stateManager")
        StateManager.push("bagUI", {
            bag     = _player:getBag(),
            player  = _player,          -- Bug#31：传入 player 供技能列表展示
            mode    = "browse",
            onClose = function()
                StateManager.pop()
            end,
        })
    end

    -- ESC 返回菜单：移至 keypressed 事件处理，避免控制台/面板关闭时的按键残留穿透

    -- 处理待跳转升级界面（必须放在 update 最末尾，防止 exit 破坏帧内状态）
    -- Bug#40：胜利后清除待处理升级，不再弹出
    if _victory then _pendingUpgrade = nil end
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
    local psb     = bag._playerSynergyBonus or {}  -- Phase 7.2：玩家全局羁绊加成

    -- Phase 8：合并技能被动加成
    local sm = _player:getSkillManager()
    local skillPsb = {}
    sm:recalcPassive(skillPsb)
    local skillActiveSyn = SkillSynergy.recalculate(sm, skillPsb)
    local mergedPsb = {}
    for k, v in pairs(psb)      do mergedPsb[k] = v end
    for k, v in pairs(skillPsb) do mergedPsb[k] = (mergedPsb[k] or 0) + v end

    -- Phase 7.2：暴击率与暴击倍率加成（critChance 为百分比，需转换为小数）
    local effectiveCritRate   = _player.critRate   + (mergedPsb.critChance or 0) / 100
    local effectiveCritDamage = _player.critDamage + (mergedPsb.critMult   or 0) / 100

    -- Phase 10.1：弹药强化改用 BuffManager stack 型 Buff
    local ammoMultiplier = 1
    local bm = _player._buffManager
    if bm and bm:has("ammo_supply") then
        ammoMultiplier = 2
        bm:consumeStack("ammo_supply", _player)
    end

    if #weapons > 0 then
        -- 每把武器独立计时、独立索敌、独立发射
        for _, weapon in ipairs(weapons) do
            local shots = weapon:tickAttack(dt)
            if shots > 0 then
                local target = Game._findNearestEnemyInRange(weapon:getEffectiveRange())
                if target then
                    for _ = 1, shots do
                        local dx, dy = MathUtils.normalize(
                            target.x - _player.x,
                            target.y - _player.y)
                        -- Phase 7.2：伤害加上全局攻击加成；弹速加上全局弹速加成
                        local baseDmg = weapon:getEffectiveDamage(_player.attack + (mergedPsb.damage or 0))
                        local proj = Projectile.new(
                            _player.x, _player.y,
                            dx, dy,
                            baseDmg * ammoMultiplier,
                            weapon:getEffectiveBulletSpeed(mergedPsb.bulletSpeed or 0))
                        proj._critRate   = effectiveCritRate
                        proj._critDamage = effectiveCritDamage
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
                    FALLBACK_ATTACK_DAMAGE * ammoMultiplier,
                    FALLBACK_ATTACK_SPEED)
                proj._critRate   = effectiveCritRate
                proj._critDamage = effectiveCritDamage
                table.insert(_projectiles, proj)
            end
        end
    end
end

-- 在所有敌人（含 Boss）中寻找距离玩家最近且在指定范围内的目标
-- Phase 9 修复 Bug#33：Boss 不在 _enemies 列表，需单独纳入索敌范围
-- @param range: 最大索敌距离（像素）
-- @return 最近的 Enemy/Boss 实例，若无则返回 nil
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

    -- Phase 9：同时检测 Boss
    if _boss and not _boss._isDead then
        local dist = MathUtils.distance(_player.x, _player.y, _boss.x, _boss.y)
        if dist < minDist then
            nearest = _boss
        end
    end

    return nearest
end

-- 每帧绘制游戏画面
function Game:draw()
    love.graphics.setBackgroundColor(0.05, 0.05, 0.08)

    -- == 世界层（摄像机坐标系）==
    _camera:attach()

    -- Phase 12：场景背景绘制（最底层，替换/叠加默认网格）
    local scene = SceneManager.get()
    if scene then
        scene:draw(_camera)
    else
        -- 无场景时回退默认网格
        Game._drawGrid()
    end

    -- 绘制所有掉落物（最底层）
    for _, pickup in ipairs(_pickups) do
        pickup:draw()
    end

    -- 绘制所有敌人
    for _, enemy in ipairs(_enemies) do
        enemy:draw()
    end

    -- Phase 9：绘制 Boss（Boss 在世界坐标层）
    if _boss and not _boss._isDead then
        _boss:draw()
    end

    -- 绘制所有投射物
    for _, proj in ipairs(_projectiles) do
        proj:draw()
    end

    -- 绘制玩家（最上层）
    _player:draw()

    -- Bug#37：魔法护盾持续光环特效（世界坐标，叠在玩家之上）
    local bm = _player._buffManager
    if bm and bm:has("mana_shield") then
        local entry = bm:get("mana_shield")
        -- 呼吸脉冲：0.6 秒一周期
        local pulse = (math.sin(love.timer.getTime() * math.pi / 0.6) + 1) * 0.5
        local shieldR = (_player.size or 12) + 10 + pulse * 4
        -- 外圈：蓝紫色半透明
        love.graphics.setColor(0.45, 0.3, 0.95, 0.25 + 0.15 * pulse)
        love.graphics.circle("fill", _player.x, _player.y, shieldR)
        -- 圆边框
        love.graphics.setColor(0.6, 0.4, 1.0, 0.7 + 0.25 * pulse)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", _player.x, _player.y, shieldR)
        -- 旋转能量粒子（6个点均匀分布）
        local t = love.timer.getTime()
        for i = 0, 5 do
            local angle = t * 1.8 + i * math.pi / 3
            local px = _player.x + math.cos(angle) * shieldR
            local py = _player.y + math.sin(angle) * shieldR
            love.graphics.setColor(0.8, 0.6, 1.0, 0.85)
            love.graphics.circle("fill", px, py, 2.5)
        end
        love.graphics.setLineWidth(1)
        love.graphics.setColor(1, 1, 1, 1)
    end

    -- 需求#13：战吼激活期间跟随特效（红橙色能量环 + 旋转火焰粒子）
    if bm and bm:has("battle_cry") then
        local t     = love.timer.getTime()
        local pulse = (math.sin(t * math.pi / 0.4) + 1) * 0.5  -- 快速脉冲
        local baseR = (_player.size or 12) + 8
        local outerR = baseR + pulse * 5
        -- 外圈：橙红色半透明光晕
        love.graphics.setColor(1.0, 0.35, 0.0, 0.18 + 0.12 * pulse)
        love.graphics.circle("fill", _player.x, _player.y, outerR)
        -- 圆边框：红色
        love.graphics.setColor(1.0, 0.2, 0.0, 0.65 + 0.25 * pulse)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", _player.x, _player.y, outerR)
        -- 旋转火焰粒子（4个，逆时针）
        for i = 0, 3 do
            local angle = -t * 2.5 + i * math.pi / 2
            local pr = baseR + 6 + pulse * 3
            local px = _player.x + math.cos(angle) * pr
            local py = _player.y + math.sin(angle) * pr
            love.graphics.setColor(1.0, 0.5 + 0.3 * pulse, 0.0, 0.9)
            love.graphics.circle("fill", px, py, 3)
        end
        love.graphics.setLineWidth(1)
        love.graphics.setColor(1, 1, 1, 1)
    end

    -- 需求1：绘制技能视觉特效（世界坐标系，在玩家之上，screen_flash 除外）
    FX.draw(0, 0)  -- 已在 camera:attach() 内，世界坐标直接使用

    _camera:detach()

    -- == UI 层（屏幕坐标系）==
    -- 需求1：全屏闪烁特效（需在 camera 坐标之外）
    FX.drawScreenEffects()

    -- Phase 11：委托 HUD 模块绘制全部界面元素
    HUD.draw({
        player        = _player,
        skillManager  = _player:getSkillManager(),
        rhythm        = _rhythm,
        boss          = _boss,
        paused        = _paused,
        victory       = _victory,
        levelUpNotice = _levelUpNotice,
        enemies       = _enemies,
        projectiles   = _projectiles,
        pickups       = _pickups,
    })
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

-- 键盘按下事件（keypressed 是一次性事件，不会被跨状态按键残留触发）
-- @param key: 按下的键名
function Game:keypressed(key)
    if key == "escape" then
        local StateManager = require("src.states.stateManager")
        StateManager.switch("menu")
        return
    end

    -- Phase 8：主动技能按键触发（keypressed 保证单次触发，不重复激活）
    if _player then
        local sm  = _player:getSkillManager()
        local bag = _player:getBag()
        local psb = bag._playerSynergyBonus or {}
        local skillPsb = {}
        sm:recalcPassive(skillPsb)
        SkillSynergy.recalculate(sm, skillPsb)
        local mergedCdReduce = (psb.cdReduce or 0) + (skillPsb.cdReduce or 0)
        local ctx = {
            dx           = _player._lastDx or _player._dx,   -- Bug#29：用最后移动方向
            dy           = _player._lastDy or _player._dy,
            enemies      = _enemies,
            projectiles  = _projectiles,
            bag          = bag,
            skillManager = sm,
        }
        if key == "space" then
            if sm:tryActivate("skill1", _player, ctx, mergedCdReduce) then
                local inst = sm:getSlot("skill1")
                if inst then FX.spawn(inst.id, _player, ctx) end
            end
        end
        if key == "q" then
            if sm:tryActivate("skill2", _player, ctx, mergedCdReduce) then
                local inst = sm:getSlot("skill2")
                if inst then FX.spawn(inst.id, _player, ctx) end
            end
        end
        if key == "e" then
            if sm:tryActivate("skill3", _player, ctx, mergedCdReduce) then
                local inst = sm:getSlot("skill3")
                if inst then FX.spawn(inst.id, _player, ctx) end
            end
        end
        if key == "f" then
            if sm:tryActivate("skill4", _player, ctx, mergedCdReduce) then
                local inst = sm:getSlot("skill4")
                if inst then FX.spawn(inst.id, _player, ctx) end
            end
        end
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

-- Phase 10：绘制传承圆形图标（技能槽右侧）
-- @param x: 图标左边缘 X
-- @param y: 图标顶部 Y
-- Phase 9：触发胜利（供控制台 win 指令使用）
function Game._triggerVictory()
    _victory      = true
    _victoryTimer = VICTORY_DELAY
    Log.info("控制台触发胜利")
end

return Game
