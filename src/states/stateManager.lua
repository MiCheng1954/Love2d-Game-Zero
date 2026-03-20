--[[
    src/states/stateManager.lua
    状态机管理器，负责管理游戏的所有状态（菜单、游戏、升级、结算等）
    每次只有一个状态处于激活状态
]]

local StateManager = {}

-- 当前激活的状态对象
local _currentState = nil

-- 已注册的所有状态表，key 为状态名，value 为状态对象
local _states = {}

-- 注册一个状态
-- @param name:  状态名称（字符串，如 "menu"、"game"）
-- @param state: 状态对象（需包含 enter/exit/update/draw 方法）
function StateManager.register(name, state)
    _states[name] = state
end

-- 切换到指定状态
-- @param name: 目标状态名称
-- @param ...:  传递给新状态 enter() 的额外参数
function StateManager.switch(name, ...)
    -- 退出当前状态
    if _currentState and _currentState.exit then
        _currentState:exit()
    end
    -- 进入新状态
    _currentState = _states[name]
    assert(_currentState, "StateManager: 未找到状态 [" .. name .. "]")
    if _currentState.enter then
        _currentState:enter(...)
    end
end

-- 获取当前状态名称（调试用）
-- @return 当前状态对象，若无则返回 nil
function StateManager.current()
    return _currentState
end

-- 将 update 转发给当前状态
-- @param dt: 距上一帧的时间间隔（秒）
function StateManager.update(dt)
    if _currentState and _currentState.update then
        _currentState:update(dt)
    end
end

-- 将 draw 转发给当前状态
function StateManager.draw()
    if _currentState and _currentState.draw then
        _currentState:draw()
    end
end

-- 将键盘按下事件转发给当前状态
-- @param key: 按下的键名
function StateManager.keypressed(key)
    if _currentState and _currentState.keypressed then
        _currentState:keypressed(key)
    end
end

-- 将键盘释放事件转发给当前状态
-- @param key: 释放的键名
function StateManager.keyreleased(key)
    if _currentState and _currentState.keyreleased then
        _currentState:keyreleased(key)
    end
end

return StateManager
