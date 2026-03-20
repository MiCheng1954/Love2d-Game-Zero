--[[
    utils/timer.lua
    计时器工具库，提供延迟回调、周期回调等计时功能
    所有计时器需要在 update(dt) 中调用 Timer.update(dt) 才能生效
]]

local Timer = {}

-- 当前所有活跃计时器的列表
local _timers = {}

-- 创建一个延迟执行的一次性计时器
-- @param delay:    延迟时间（秒）
-- @param callback: 到时后执行的回调函数
-- @return 计时器句柄（可用于取消）
function Timer.after(delay, callback)
    local handle = {
        timeLeft   = delay,    -- 剩余时间（秒）
        callback   = callback, -- 到时回调
        isRepeating = false,   -- 是否循环
        isDone     = false,    -- 是否已完成
    }
    table.insert(_timers, handle)
    return handle
end

-- 创建一个周期执行的循环计时器
-- @param interval: 每次触发的间隔时间（秒）
-- @param callback: 每次触发时执行的回调函数
-- @return 计时器句柄（可用于取消）
function Timer.every(interval, callback)
    local handle = {
        timeLeft    = interval, -- 距下次触发的剩余时间（秒）
        interval    = interval, -- 触发间隔（秒）
        callback    = callback, -- 触发回调
        isRepeating = true,     -- 是否循环
        isDone      = false,    -- 是否已取消
    }
    table.insert(_timers, handle)
    return handle
end

-- 取消一个计时器，使其不再触发
-- @param handle: 由 Timer.after 或 Timer.every 返回的计时器句柄
function Timer.cancel(handle)
    if handle then
        handle.isDone = true
    end
end

-- 每帧更新所有计时器，需在 love.update(dt) 中调用
-- @param dt: 距上一帧的时间间隔（秒）
function Timer.update(dt)
    -- 遍历所有计时器并倒计时
    for i = #_timers, 1, -1 do
        local t = _timers[i]
        if t.isDone then
            -- 移除已完成或已取消的计时器
            table.remove(_timers, i)
        else
            t.timeLeft = t.timeLeft - dt
            if t.timeLeft <= 0 then
                t.callback()
                if t.isRepeating then
                    -- 循环计时器重置剩余时间
                    t.timeLeft = t.interval
                else
                    -- 一次性计时器标记完成
                    t.isDone = true
                end
            end
        end
    end
end

-- 清除所有活跃计时器
function Timer.clear()
    _timers = {}
end

return Timer
