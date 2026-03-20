--[[
    src/entities/pickup.lua
    掉落物类，代表场景中可被玩家拾取的物品
    类型包括：经验值、灵魂、事件触发器
    所有掉落物通过吸附半径自动被玩家吸取
]]

local Entity = require("src.entities.entity")

local Pickup = setmetatable({}, { __index = Entity })
Pickup.__index = Pickup

-- 掉落物类型枚举
Pickup.TYPE = {
    EXP     = "exp",      -- 经验值
    SOUL    = "soul",     -- 灵魂
    TRIGGER = "trigger",  -- 事件触发器（属性包/武器包/技能包/背包成长）
}

-- 各类型的外观配置（代码绘制 fallback）
local APPEARANCE = {
    exp = {
        radius = 6,
        color  = {0.2, 0.9, 0.4},   -- 绿色
    },
    soul = {
        radius = 6,
        color  = {0.4, 0.7, 1.0},   -- 蓝色
    },
    trigger = {
        radius = 10,
        color  = {1.0, 0.8, 0.1},   -- 金色
    },
}

-- 构造函数，创建一个新的掉落物实例
-- @param x:      初始世界坐标 X
-- @param y:      初始世界坐标 Y
-- @param pType:  掉落物类型（Pickup.TYPE 中的值）
-- @param amount: 数量（经验值/灵魂的数值，触发器为 1）
function Pickup.new(x, y, pType, amount)
    local self = setmetatable(Entity.new(x, y), Pickup)

    self._type      = pType             -- 掉落物类型
    self._amount    = amount or 1       -- 数值（经验/灵魂）
    self._collected = false             -- 是否已被拾取

    -- 从外观配置读取半径和颜色
    local appearance   = APPEARANCE[pType] or APPEARANCE.exp
    self._radius       = appearance.radius   -- 碰撞/显示半径
    self._color        = appearance.color    -- 显示颜色
    self.width         = self._radius * 2
    self.height        = self._radius * 2

    -- 漂浮动画参数
    self._floatTimer   = math.random() * math.pi * 2  -- 随机初始相位，错开动画
    self._floatSpeed   = 2.0                           -- 漂浮频率
    self._floatAmp     = 3.0                           -- 漂浮幅度（像素）
    self._baseY        = y                             -- 漂浮基准 Y 坐标

    -- 吸附状态
    self._attracting   = false   -- 是否正在被玩家吸附
    self._attractSpeed = 300     -- 被吸附时的飞向速度（像素/秒）

    return self
end

-- 每帧更新掉落物逻辑
-- @param dt:    距上一帧的时间间隔（秒）
-- @param player: 玩家实体（用于吸附检测）
function Pickup:update(dt, player)
    if self._isDead or self._collected then return end

    -- 更新漂浮动画
    self._floatTimer = self._floatTimer + dt * self._floatSpeed
    self.y = self._baseY + math.sin(self._floatTimer) * self._floatAmp

    -- 检测是否在玩家吸附范围内
    local dx   = player.x - self.x
    local dy   = player.y - self.y
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist <= player.pickupRadius then
        self._attracting = true
    end

    -- 若在吸附中，朝玩家飞去
    if self._attracting then
        if dist < 5 then
            -- 到达玩家位置，触发拾取
            self:collect(player)
        else
            -- 归一化方向并移动
            self.x = self.x + (dx / dist) * self._attractSpeed * dt
            self.y = self.y + (dy / dist) * self._attractSpeed * dt
            self._baseY = self.y  -- 更新基准 Y，避免漂浮抖动
        end
    end
end

-- 被玩家拾取时触发
-- @param player: 拾取的玩家实体
function Pickup:collect(player)
    if self._collected then return end
    self._collected = true
    self._isDead    = true

    -- 根据类型应用效果
    if self._type == Pickup.TYPE.EXP then
        player:gainExp(self._amount)
    elseif self._type == Pickup.TYPE.SOUL then
        player:gainSouls(self._amount)
    elseif self._type == Pickup.TYPE.TRIGGER then
        -- TODO: Phase 5 接入升级奖励系统
    end
end

-- 将掉落物绘制到屏幕上
function Pickup:draw()
    if not self._isVisible or self._isDead then return end

    if self._sprite then
        -- 有资产时：绘制贴图（预留接口）
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(self._sprite, self.x, self.y, 0, 1, 1,
            self._radius, self._radius)
    else
        -- 无资产时：代码绘制 fallback

        -- 外圈光晕（半透明）
        love.graphics.setColor(
            self._color[1],
            self._color[2],
            self._color[3],
            0.25)
        love.graphics.circle("fill", self.x, self.y, self._radius * 1.8)

        -- 主体
        love.graphics.setColor(self._color)
        love.graphics.circle("fill", self.x, self.y, self._radius)

        -- 高光（白色小点）
        love.graphics.setColor(1, 1, 1, 0.7)
        love.graphics.circle("fill",
            self.x - self._radius * 0.3,
            self.y - self._radius * 0.3,
            self._radius * 0.25)
    end
end

-- 获取掉落物类型
-- @return 类型字符串
function Pickup:getType()
    return self._type
end

return Pickup
