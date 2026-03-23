--[[
    main.lua
    程序入口文件，只负责初始化和 Love2D 回调注册
    不包含任何游戏逻辑，所有逻辑委托给 StateManager
    Phase 5.1：注入全局 T()、注册 console/bugReport 状态、添加 textinput/功能键回调
]]

local StateManager = require("src.states.stateManager")
local I18n         = require("src.utils.i18n")
local Log          = require("src.utils.log")
local Menu         = require("src.states.menu")
local Game         = require("src.states.game")
local Upgrade      = require("src.states.upgrade")
local Gameover     = require("src.states.gameover")
local Console      = require("src.states.console")
local DevReport    = require("src.states.devReport")   -- [可剔除] 注释此行+register+F12分支即可移除
local BagUI        = require("src.states.bagUI")
local SkillSelectUI    = require("src.states.skillSelectUI")    -- Phase 8
local SkillConflictUI  = require("src.states.skillConflictUI")  -- Phase 8
local ReviveUI     = require("src.states.reviveUI")     -- Phase 10
local LegacySelect = require("src.states.legacySelect") -- Phase 10
local TriggerUI    = require("src.ui.triggerUI")        -- Phase 11
local SceneSelect  = require("src.states.sceneSelect")  -- Phase 12
local SceneManager = require("src.systems.sceneManager") -- Phase 12
local CharacterSelect = require("src.states.characterSelect") -- Phase 13
local Progression     = require("src.states.progression")     -- Phase 13
local Achievements    = require("src.states.achievements")    -- Phase 13
local Plains       = require("src.scenes.plains")        -- Phase 12
local Arena        = require("src.scenes.arena")         -- Phase 12

-- 游戏初始化，Love2D 启动后调用一次
function love.load()
    -- 初始化日志系统（写入项目 data/ 目录）
    Log.init(love.filesystem.getSource())
    Log.info("love.load() 开始")

    -- 初始化 i18n，加载中文语言表
    I18n.load("zh")
    -- 注入全局 T() 函数，所有模块均可直接使用 T("key")
    _G.T = I18n.get

    -- 禁用文字输入模式，防止中文输入法（IME）拦截 WASD 等游戏按键
    -- 需要文字输入的界面（如控制台、Bug 反馈）再单独开启
    love.keyboard.setTextInput(false)

    -- 注册所有游戏状态
    StateManager.register("menu",          Menu)
    StateManager.register("game",          Game)
    StateManager.register("upgrade",       Upgrade)
    StateManager.register("gameover",      Gameover)
    StateManager.register("console",       Console)
    StateManager.register("devReport",     DevReport)        -- [可剔除] 注释此行+require+F12分支即可移除
    StateManager.register("bagUI",         BagUI)
    StateManager.register("skillSelectUI",   SkillSelectUI)    -- Phase 8
    StateManager.register("skillConflictUI", SkillConflictUI)  -- Phase 8
    StateManager.register("reviveUI",        ReviveUI)         -- Phase 10
    StateManager.register("legacySelect",    LegacySelect)     -- Phase 10
    StateManager.register("triggerUI",       TriggerUI)        -- Phase 11
    StateManager.register("sceneSelect",     SceneSelect)      -- Phase 12

    StateManager.register("characterSelect", CharacterSelect)  -- Phase 13
    StateManager.register("progression",     Progression)      -- Phase 13
    StateManager.register("achievements",    Achievements)     -- Phase 13

    -- 注册场景实例到 SceneManager（Phase 12）
    SceneManager.register("plains",  Plains.new())
    SceneManager.register("arena",   Arena.new())
    SceneManager.set("plains")  -- 默认场景：平原

    -- 设置默认字体抗锯齿过滤
    love.graphics.setDefaultFilter("nearest", "nearest")

    -- 进入初始状态：主菜单
    Log.info("进入主菜单")
    StateManager.switch("menu")
end

-- 每帧更新，Love2D 自动调用
-- @param dt: 距上一帧的时间间隔（秒）
function love.update(dt)
    StateManager.update(dt)
end

-- 每帧绘制，Love2D 自动调用
function love.draw()
    StateManager.draw()
end

-- 键盘按下事件，Love2D 自动调用
-- @param key:      按下的键名
-- @param scancode: 物理按键码
-- @param isrepeat: 是否为长按重复触发
function love.keypressed(key, scancode, isrepeat)
    -- 开发者功能键（任意状态下均可触发，优先于当前状态处理）
    local curState = StateManager.current()

    -- ` 键：呼出开发者控制台（仅在游戏状态下可用，避免嵌套打开）
    if key == "`" then
        local Game = require("src.states.game")
        if curState == Game then
            StateManager.push("console", {
                player    = Game._getPlayer(),
                enemies   = Game._getEnemies(),
                spawner   = Game._getSpawner(),
                onLevelUp = Game._triggerLevelUp,
                onVictory = Game._triggerVictory,
            })
            return
        end
    end

    -- F12 键：先截图，截图回调完成后再弹出反馈面板（[可剔除] 注释此块即可移除）
    if key == "f12" then
        local Console = require("src.states.console")
        if curState ~= Console then
            local DevReport = require("src.states.devReport")
            if curState ~= DevReport then
                local Game = require("src.states.game")
                -- 收集上下文数据（在回调前先收集，防止回调时状态已变化）
                local reportData = {
                    player  = Game._getPlayer(),
                    spawner = Game._getSpawner(),
                    enemies = Game._getEnemies(),
                }
                -- 截图当前帧（captureScreenshot 是异步的，回调在下一帧渲染后执行）
                -- 截图完成后才 push 面板，确保面板本身不出现在截图里
                love.graphics.captureScreenshot(function(imageData)
                    -- 保存截图到 data/logs/
                    local screenshotPath = Log.saveScreenshot(imageData)
                    reportData.screenshotPath = screenshotPath
                    StateManager.push("devReport", reportData)
                end)
                return
            end
        end
    end

    StateManager.keypressed(key)
end

-- 键盘释放事件，Love2D 自动调用
-- @param key:      释放的键名
-- @param scancode: 物理按键码
function love.keyreleased(key, scancode)
    StateManager.keyreleased(key)
end

-- 文字输入事件，Love2D 自动调用（仅在 setTextInput(true) 时触发）
-- @param text: 输入的文字字符串
function love.textinput(text)
    StateManager.textinput(text)
end

-- 游戏退出时调用，关闭日志文件句柄
function love.quit()
    Log.info("love.quit()")
    Log.close()
end
