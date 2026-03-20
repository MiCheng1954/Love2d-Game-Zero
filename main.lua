--[[
    main.lua
    程序入口文件，只负责初始化和 Love2D 回调注册
    不包含任何游戏逻辑，所有逻辑委托给 StateManager
]]

local StateManager = require("src.states.stateManager")
local Menu         = require("src.states.menu")
local Game         = require("src.states.game")
local Upgrade      = require("src.states.upgrade")
local Gameover     = require("src.states.gameover")

-- 游戏初始化，Love2D 启动后调用一次
function love.load()
    -- 注册所有游戏状态
    StateManager.register("menu",    Menu)
    StateManager.register("game",    Game)
    StateManager.register("upgrade", Upgrade)
    StateManager.register("gameover", Gameover)

    -- 设置默认字体抗锯齿过滤
    love.graphics.setDefaultFilter("nearest", "nearest")

    -- 进入初始状态：主菜单
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
    StateManager.keypressed(key)
end

-- 键盘释放事件，Love2D 自动调用
-- @param key:      释放的键名
-- @param scancode: 物理按键码
function love.keyreleased(key, scancode)
    StateManager.keyreleased(key)
end
