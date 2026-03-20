--[[
    src/states/upgrade.lua
    升级奖励选择状态，玩家升级时暂停游戏并弹出此界面
    目前为占位实现，后续 Phase 5 完善
]]

local Upgrade = {}

-- 进入升级状态时调用
-- @param data: 传入的升级上下文数据（如可选奖励列表）
function Upgrade:enter(data)
    self._data = data   -- 升级上下文数据
end

-- 退出升级状态时调用
function Upgrade:exit()
    self._data = nil
end

-- 每帧更新升级界面逻辑
-- @param dt: 距上一帧的时间间隔（秒）
function Upgrade:update(dt)
end

-- 每帧绘制升级界面
function Upgrade:draw()
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, 1280, 720)

    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("升级！选择奖励 (Phase 5 占位)", 0, 340, 1280, "center")
end

-- 键盘按下事件
-- @param key: 按下的键名
function Upgrade:keypressed(key)
end

return Upgrade
