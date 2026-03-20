--[[
    src/systems/camera.lua
    摄像机系统，负责跟随目标并将世界坐标转换为屏幕坐标
    使用 push/translate/pop 实现坐标变换，不影响 UI 绘制
]]

local Camera = {}
Camera.__index = Camera

-- 创建一个新的摄像机实例
-- @param screenW: 屏幕宽度（像素）
-- @param screenH: 屏幕高度（像素）
function Camera.new(screenW, screenH)
    local self = setmetatable({}, Camera)

    self.x       = 0           -- 摄像机当前 X 坐标（世界坐标）
    self.y       = 0           -- 摄像机当前 Y 坐标（世界坐标）
    self.screenW = screenW     -- 屏幕宽度
    self.screenH = screenH     -- 屏幕高度
    self._target = nil         -- 跟随目标实体
    self._lerp   = 0.1         -- 跟随平滑系数（0~1，越小越平滑）

    return self
end

-- 设置摄像机跟随的目标实体
-- @param target: 需要包含 x, y 属性的对象
function Camera:setTarget(target)
    self._target = target
end

-- 每帧更新摄像机位置，平滑跟随目标
-- @param dt: 距上一帧的时间间隔（秒）
function Camera:update(dt)
    if not self._target then return end

    -- 计算目标位置（让目标居中）
    local targetX = self._target.x
    local targetY = self._target.y

    -- 平滑插值跟随
    self.x = self.x + (targetX - self.x) * self._lerp
    self.y = self.y + (targetY - self.y) * self._lerp
end

-- 开始摄像机坐标变换，在绘制世界内容前调用
-- 之后所有绘制操作都处于世界坐标系中
function Camera:attach()
    love.graphics.push()
    love.graphics.translate(
        math.floor(self.screenW / 2 - self.x),
        math.floor(self.screenH / 2 - self.y)
    )
end

-- 结束摄像机坐标变换，在绘制世界内容后调用
-- 之后的绘制操作恢复为屏幕坐标系（用于绘制 UI）
function Camera:detach()
    love.graphics.pop()
end

-- 将世界坐标转换为屏幕坐标
-- @param worldX: 世界坐标 X
-- @param worldY: 世界坐标 Y
-- @return screenX, screenY: 对应的屏幕坐标
function Camera:worldToScreen(worldX, worldY)
    return worldX - self.x + self.screenW / 2,
           worldY - self.y + self.screenH / 2
end

-- 将屏幕坐标转换为世界坐标
-- @param screenX: 屏幕坐标 X
-- @param screenY: 屏幕坐标 Y
-- @return worldX, worldY: 对应的世界坐标
function Camera:screenToWorld(screenX, screenY)
    return screenX + self.x - self.screenW / 2,
           screenY + self.y - self.screenH / 2
end

return Camera
