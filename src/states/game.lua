--[[
    src/states/game.lua
    游戏主状态，局内核心玩法的入口
    目前为占位实现，后续各 Phase 逐步填充内容
]]

local Timer = require("src.utils.timer")

local Game = {}

-- 进入游戏状态时调用，负责初始化所有局内数据
function Game:enter()
    Timer.clear()   -- 清空上一局残留的计时器
end

-- 退出游戏状态时调用
function Game:exit()
    Timer.clear()
end

-- 每帧更新游戏逻辑
-- @param dt: 距上一帧的时间间隔（秒）
function Game:update(dt)
    Timer.update(dt)
end

-- 每帧绘制游戏画面
function Game:draw()
    love.graphics.setBackgroundColor(0.05, 0.05, 0.08)

    -- 占位文字，Phase 2 起替换为实际游戏内容
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("游戏进行中... (Phase 1 占位)", 0, 340, 1280, "center")
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.printf("按 ESC 返回菜单", 0, 380, 1280, "center")
end

-- 键盘按下事件
-- @param key: 按下的键名
function Game:keypressed(key)
    if key == "escape" then
        local StateManager = require("src.states.stateManager")
        StateManager.switch("menu")
    end
end

return Game
