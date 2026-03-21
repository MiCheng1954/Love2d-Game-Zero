--[[
    src/states/gameover.lua
    游戏结算状态，玩家死亡或胜利后显示
    Phase 9：支持 isVictory 标记，胜利和失败显示不同画面
]]

local Gameover = {}

local Font = require("src.utils.font")

-- 进入结算状态时调用
-- @param data: 传入的结算数据（含 isVictory 标记）
function Gameover:enter(data)
    self._data      = data
    self._isVictory = data and data.isVictory or false
end

-- 退出结算状态时调用
function Gameover:exit()
    self._data      = nil
    self._isVictory = false
end

-- 每帧更新结算界面逻辑
function Gameover:update(dt)
end

-- 每帧绘制结算界面
function Gameover:draw()
    if self._isVictory then
        love.graphics.setBackgroundColor(0.03, 0.06, 0.05)

        -- 胜利标题
        Font.set(52)
        love.graphics.setColor(1.0, 0.85, 0.15)
        love.graphics.printf(T("gameover.victory_title") or "★  VICTORY  ★", 0, 260, 1280, "center")

        -- 胜利副标题
        Font.set(20)
        love.graphics.setColor(0.7, 1.0, 0.8)
        love.graphics.printf(T("gameover.victory_sub") or "你击败了虚空领主，世界得救了！", 0, 340, 1280, "center")

        -- 操作提示
        Font.set(16)
        love.graphics.setColor(0.55, 0.55, 0.55)
        love.graphics.printf(T("gameover.hint"), 0, 420, 1280, "center")
    else
        love.graphics.setBackgroundColor(0.05, 0.05, 0.08)

        -- 失败标题
        Font.set(48)
        love.graphics.setColor(1, 0.3, 0.3)
        love.graphics.printf(T("gameover.title"), 0, 300, 1280, "center")

        -- 操作提示
        Font.set(18)
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.printf(T("gameover.hint"), 0, 370, 1280, "center")
    end

    Font.reset()
end

-- 键盘按下事件
function Gameover:keypressed(key)
    if key == "return" then
        local StateManager = require("src.states.stateManager")
        StateManager.switch("menu")
    end
end

return Gameover
