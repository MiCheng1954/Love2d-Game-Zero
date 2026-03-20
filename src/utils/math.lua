--[[
    utils/math.lua
    数学工具库，提供向量运算、角度计算等通用数学函数
]]

local MathUtils = {}

-- 计算两点之间的距离
-- @param x1: 起点 X 坐标
-- @param y1: 起点 Y 坐标
-- @param x2: 终点 X 坐标
-- @param y2: 终点 Y 坐标
-- @return 两点之间的欧氏距离
function MathUtils.distance(x1, y1, x2, y2)
    local dx = x2 - x1  -- X 轴差值
    local dy = y2 - y1  -- Y 轴差值
    return math.sqrt(dx * dx + dy * dy)
end

-- 计算从起点指向终点的角度（弧度）
-- @param x1: 起点 X 坐标
-- @param y1: 起点 Y 坐标
-- @param x2: 终点 X 坐标
-- @param y2: 终点 Y 坐标
-- @return 角度（弧度），范围 -π 到 π
function MathUtils.angle(x1, y1, x2, y2)
    return math.atan2(y2 - y1, x2 - x1)
end

-- 将向量归一化，返回单位向量
-- @param x: 向量 X 分量
-- @param y: 向量 Y 分量
-- @return 归一化后的 x, y 分量（若为零向量则返回 0, 0）
function MathUtils.normalize(x, y)
    local len = math.sqrt(x * x + y * y)
    if len == 0 then
        return 0, 0
    end
    return x / len, y / len
end

-- 线性插值
-- @param a: 起始值
-- @param b: 目标值
-- @param t: 插值系数（0~1）
-- @return 插值结果
function MathUtils.lerp(a, b, t)
    return a + (b - a) * t
end

-- 将数值限制在指定范围内
-- @param value: 原始数值
-- @param min:   最小值
-- @param max:   最大值
-- @return 限制后的数值
function MathUtils.clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

return MathUtils
