--[[
    src/states/menu.lua
    主菜单状态，游戏启动后的第一个界面
    目前为占位实现，后续 Phase 11 完善 UI
]]

local Menu = {}

-- 进入主菜单状态时调用
function Menu:enter()
end

-- 退出主菜单状态时调用
function Menu:exit()
end

-- 每帧更新主菜单逻辑
-- @param dt: 距上一帧的时间间隔（秒）
function Menu:update(dt)
end

-- 每帧绘制主菜单界面
function Menu:draw()
    -- 背景色
    love.graphics.setBackgroundColor(0.08, 0.08, 0.12)

    -- 游戏标题
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("ZERO", 0, 260, 1280, "center")

    -- 提示文字
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.printf("按下 Enter 开始游戏", 0, 360, 1280, "center")
end

-- 键盘按下事件
-- @param key: 按下的键名
function Menu:keypressed(key)
    if key == "return" or key == "space" then
        -- 切换到游戏状态
        local StateManager = require("src.states.stateManager")
        StateManager.switch("game")
    end
end

return Menu
