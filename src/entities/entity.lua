--[[
    src/entities/entity.lua
    实体基类，玩家与敌人共用的底层数据和行为
    所有游戏实体都应继承自此类
]]

local Entity = {}
Entity.__index = Entity

-- 构造函数，创建一个新的实体实例
-- @param x: 初始 X 坐标
-- @param y: 初始 Y 坐标
function Entity.new(x, y)
    local self = setmetatable({}, Entity)

    -- 位置与尺寸
    self.x      = x or 0   -- 世界坐标 X
    self.y      = y or 0   -- 世界坐标 Y
    self.width  = 32        -- 碰撞体宽度（像素）
    self.height = 32        -- 碰撞体高度（像素）

    -- 基础战斗属性
    self.maxHp      = 100   -- 最大生命值
    self.hp         = 100   -- 当前生命值
    self.attack     = 10    -- 攻击力（基础伤害倍率）
    self.defense    = 0     -- 防御力（伤害减免）
    self.speed      = 150   -- 移动速度（像素/秒）
    self.attackSpeed = 1.0  -- 攻击速度（倍率，1.0 为基准）
    self.critRate   = 0.05  -- 暴击率（0~1）
    self.critDamage = 1.5   -- 暴击伤害倍率

    -- 拾取属性
    self.pickupRadius = 80  -- 自动吸附拾取半径（像素）

    -- 成长属性
    self.expBonus  = 1.0    -- 经验值获取倍率
    self.soulBonus = 1.0    -- 灵魂获取倍率

    -- 状态标记
    self._isDead    = false -- 是否已死亡
    self._isVisible = true  -- 是否可见

    -- 渲染资源（nil 时使用代码绘制作为 fallback）
    self._sprite = nil      -- 贴图资源，后期替换资产时赋值

    return self
end

-- 每帧更新实体逻辑（子类可覆盖）
-- @param dt: 距上一帧的时间间隔（秒）
function Entity:update(dt)
end

-- 将实体绘制到屏幕上（子类应覆盖此方法）
function Entity:draw()
    if not self._isVisible then return end

    if self._sprite then
        -- 有资产时：绘制贴图（预留接口）
        love.graphics.draw(self._sprite, self.x, self.y)
    else
        -- 无资产时：代码绘制 fallback，子类覆盖此分支
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle(
            "fill",
            self.x - self.width  / 2,
            self.y - self.height / 2,
            self.width,
            self.height
        )
    end
end

-- 受到伤害，计算实际伤害后扣减 HP
-- @param amount:   原始伤害值
-- @param isCrit:   是否为暴击（boolean，可选）
-- @return 实际造成的伤害值
function Entity:takeDamage(amount, isCrit)
    if self._isDead then return 0 end

    -- 防御力减免（最低造成 1 点伤害）
    local actual = math.max(1, amount - self.defense)

    -- 暴击伤害加成
    if isCrit then
        actual = math.floor(actual * self.critDamage)
    end

    self.hp = self.hp - actual

    -- 检测死亡
    if self.hp <= 0 then
        self.hp = 0
        self:onDeath()
    end

    return actual
end

-- 回复生命值
-- @param amount: 回复量
function Entity:heal(amount)
    self.hp = math.min(self.maxHp, self.hp + amount)
end

-- 死亡时回调（子类可覆盖以实现特殊死亡逻辑）
function Entity:onDeath()
    self._isDead = true
end

-- 查询实体是否已死亡
-- @return boolean
function Entity:isDead()
    return self._isDead
end

-- 获取实体中心点坐标
-- @return cx, cy: 中心点 X, Y 坐标
function Entity:getCenter()
    return self.x, self.y
end

-- 获取实体的轴对齐包围盒（AABB），用于碰撞检测
-- @return left, top, right, bottom
function Entity:getBounds()
    local hw = self.width  / 2  -- 半宽
    local hh = self.height / 2  -- 半高
    return self.x - hw, self.y - hh, self.x + hw, self.y + hh
end

return Entity
