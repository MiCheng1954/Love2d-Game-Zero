--[[
    src/states/menu.lua
    主菜单状态，游戏启动后的第一个界面
    目前为占位实现，后续 Phase 11 完善 UI
]]

local Menu = {}

local Font = require("src.utils.font")

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

    Font.set(48)
    -- 游戏标题
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(T("menu.title"), 0, 260, 1280, "center")

    Font.set(20)
    -- 提示文字
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.printf(T("menu.start"), 0, 360, 1280, "center")

    Font.reset()
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
