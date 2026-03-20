--[[
    src/entities/projectile.lua
    投射物类，继承自 Entity
    负责子弹/投射物的移动、碰撞检测和绘制
]]

local Entity = require("src.entities.entity")

local Projectile = setmetatable({}, { __index = Entity })
Projectile.__index = Projectile

-- 投射物外观配置
local PROJECTILE_RADIUS = 5             -- 投射物碰撞圆半径（像素）
local PROJECTILE_COLOR  = {1, 0.9, 0.2} -- 投射物颜色（黄色）

-- 构造函数，创建一个新的投射物实例
-- @param x:      初始世界坐标 X（通常为发射者位置）
-- @param y:      初始世界坐标 Y
-- @param dirX:   移动方向 X 分量（已归一化）
-- @param dirY:   移动方向 Y 分量（已归一化）
-- @param damage: 命中时造成的伤害值
-- @param speed:  飞行速度（像素/秒）
function Projectile.new(x, y, dirX, dirY, damage, speed)
    local self = setmetatable(Entity.new(x, y), Projectile)

    self._dirX      = dirX              -- 飞行方向 X 分量（已归一化）
    self._dirY      = dirY              -- 飞行方向 Y 分量（已归一化）
    self._damage    = damage            -- 命中伤害值
    self.speed      = speed or 400      -- 飞行速度（像素/秒）
    self._radius    = PROJECTILE_RADIUS -- 碰撞圆半径
    self.width      = PROJECTILE_RADIUS * 2
    self.height     = PROJECTILE_RADIUS * 2
    self._maxRange  = 600               -- 最大飞行距离（像素）
    self._travelled = 0                 -- 已飞行距离（像素）
    self._hit       = false             -- 是否已命中目标

    return self
end

-- 每帧更新投射物逻辑
-- @param dt: 距上一帧的时间间隔（秒）
function Projectile:update(dt)
    if self._isDead then return end

    -- 按方向飞行
    local dist = self.speed * dt
    self.x = self.x + self._dirX * dist
    self.y = self.y + self._dirY * dist

    -- 累计飞行距离，超出范围则销毁
    self._travelled = self._travelled + dist
    if self._travelled >= self._maxRange then
        self._isDead = true
    end
end

-- 命中目标，造成伤害并销毁自身
-- @param target: 被命中的目标实体
-- @return 实际造成的伤害值
function Projectile:onHit(target)
    if self._isDead or self._hit then return 0 end

    self._hit    = true
    self._isDead = true

    -- 计算暴击（使用投射物自带的暴击率）
    local isCrit = math.random() < (self._critRate or 0.05)

    -- Phase 7.2：若投射物携带了自定义暴击倍率（来自玩家 critDamage + psb 加成），
    -- 临时覆盖目标的 critDamage，确保正确应用玩家羁绊加成
    local origCritDamage = nil
    if isCrit and self._critDamage and self._critDamage ~= target.critDamage then
        origCritDamage    = target.critDamage
        target.critDamage = self._critDamage
    end

    local dmg = target:takeDamage(self._damage, isCrit)

    if origCritDamage ~= nil then
        target.critDamage = origCritDamage
    end

    return dmg
end

-- 将投射物绘制到屏幕上
function Projectile:draw()
    if not self._isVisible or self._isDead then return end

    if self._sprite then
        -- 有资产时：绘制贴图（预留接口）
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(self._sprite, self.x, self.y, 0, 1, 1,
            self._radius, self._radius)
    else
        -- 无资产时：代码绘制 fallback
        love.graphics.setColor(PROJECTILE_COLOR)
        love.graphics.circle("fill", self.x, self.y, self._radius)

        -- 发光效果（外圈半透明）
        love.graphics.setColor(
            PROJECTILE_COLOR[1],
            PROJECTILE_COLOR[2],
            PROJECTILE_COLOR[3],
            0.3)
        love.graphics.circle("fill", self.x, self.y, self._radius * 2)
    end
end

return Projectile
