--[[
    src/states/gameover.lua
    游戏结算状态，玩家死亡或完成一局后显示
    目前为占位实现，后续 Phase 10 完善
]]

local Gameover = {}

-- 进入结算状态时调用
-- @param data: 传入的结算数据（如本局时长、击杀数等）
function Gameover:enter(data)
    self._data = data   -- 本局结算数据
end

-- 退出结算状态时调用
function Gameover:exit()
    self._data = nil
end

-- 每帧更新结算界面逻辑
-- @param dt: 距上一帧的时间间隔（秒）
function Gameover:update(dt)
end

-- 每帧绘制结算界面
function Gameover:draw()
    love.graphics.setBackgroundColor(0.05, 0.05, 0.08)

    love.graphics.setColor(1, 0.3, 0.3)
    love.graphics.printf("GAME OVER", 0, 300, 1280, "center")
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.printf("按 Enter 返回菜单 (Phase 10 占位)", 0, 370, 1280, "center")
end

-- 键盘按下事件
-- @param key: 按下的键名
function Gameover:keypressed(key)
    if key == "return" then
        local StateManager = require("src.states.stateManager")
        StateManager.switch("menu")
    end
end

return Gameover
