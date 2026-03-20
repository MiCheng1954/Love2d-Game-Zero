--[[
    src/entities/enemy.lua
    敌人类，继承自 Entity
    负责敌人的 AI 追踪、接触伤害、死亡掉落
]]

local Entity      = require("src.entities.entity")
local EnemyConfig = require("config.enemies")
local Pickup      = require("src.entities.pickup")

local Enemy = setmetatable({}, { __index = Entity })
Enemy.__index = Enemy

-- 构造函数，根据配置类型创建一个敌人实例
-- @param x:        初始世界坐标 X
-- @param y:        初始世界坐标 Y
-- @param typeName: 敌人类型名称（对应 config/enemies.lua 中的 key）
function Enemy.new(x, y, typeName)
    local self = setmetatable(Entity.new(x, y), Enemy)

    -- 读取配置
    local cfg = EnemyConfig[typeName or "basic"]
    assert(cfg, "Enemy: 未知的敌人类型 [" .. tostring(typeName) .. "]")

    -- 从配置写入属性
    self._typeName    = cfg.name            -- 敌人类型名
    self.maxHp        = cfg.maxHp           -- 最大生命值
    self.hp           = cfg.maxHp           -- 当前生命值
    self.attack       = cfg.attack          -- 攻击力
    self.defense      = cfg.defense         -- 防御力
    self.speed        = cfg.speed           -- 移动速度（像素/秒）
    self._radius      = cfg.radius          -- 碰撞圆半径
    self.width        = cfg.radius * 2      -- 碰撞体宽度（同步给基类）
    self.height       = cfg.radius * 2      -- 碰撞体高度（同步给基类）
    self._color       = cfg.color           -- 代码绘制颜色
    self._expDrop     = cfg.expDrop         -- 击杀经验值掉落
    self._soulDrop    = cfg.soulDrop        -- 击杀灵魂掉落
    self._damage      = cfg.damage          -- 接触伤害值
    self._contactRate = cfg.contactRate     -- 接触伤害冷却（秒）
    self._contactTimer = 0                  -- 接触伤害计时器（秒）

    -- AI 状态
    self._target      = nil                 -- 当前追踪目标（玩家）

    return self
end

-- 设置追踪目标
-- @param target: 目标实体（需含 x, y 属性）
function Enemy:setTarget(target)
    self._target = target
end

-- 每帧更新敌人逻辑
-- @param dt: 距上一帧的时间间隔（秒）
function Enemy:update(dt)
    if self._isDead then return end

    -- 更新接触伤害计时器
    if self._contactTimer > 0 then
        self._contactTimer = self._contactTimer - dt
    end

    -- AI：追踪目标
    self:_chase(dt)
end

-- 追踪目标的移动逻辑
-- @param dt: 距上一帧的时间间隔（秒）
function Enemy:_chase(dt)
    if not self._target then return end

    -- 计算朝向目标的方向向量
    local dx = self._target.x - self.x
    local dy = self._target.y - self.y
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist < 1 then return end  -- 已到达目标位置，不再移动

    -- 归一化方向并移动
    self.x = self.x + (dx / dist) * self.speed * dt
    self.y = self.y + (dy / dist) * self.speed * dt
end

-- 尝试对目标造成接触伤害（有冷却限制）
-- @param target: 被攻击的目标实体
function Enemy:tryContactDamage(target)
    if self._isDead then return end
    if self._contactTimer > 0 then return end

    -- 造成伤害
    target:takeDamage(self._damage)
    self._contactTimer = self._contactRate  -- 重置冷却
end

-- 将敌人绘制到屏幕上
function Enemy:draw()
    if not self._isVisible or self._isDead then return end

    if self._sprite then
        -- 有资产时：绘制贴图（预留接口）
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(self._sprite, self.x, self.y, 0, 1, 1,
            self._radius, self._radius)
    else
        -- 无资产时：代码绘制 fallback
        -- 身体
        love.graphics.setColor(self._color)
        love.graphics.circle("fill", self.x, self.y, self._radius)

        -- 边框
        love.graphics.setColor(
            self._color[1] * 0.5,
            self._color[2] * 0.5,
            self._color[3] * 0.5)
        love.graphics.circle("line", self.x, self.y, self._radius)

        -- HP 条（显示在敌人头顶）
        self:_drawHpBar()
    end
end

-- 绘制敌人头顶的 HP 条
function Enemy:_drawHpBar()
    local barW  = self._radius * 2     -- HP 条宽度
    local barH  = 3                    -- HP 条高度
    local bx    = self.x - self._radius  -- HP 条左上角 X
    local by    = self.y - self._radius - 6  -- HP 条左上角 Y（头顶上方）
    local ratio = self.hp / self.maxHp   -- 当前血量比例

    -- 背景
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", bx, by, barW, barH)

    -- 前景
    love.graphics.setColor(0.8, 0.2, 0.2)
    love.graphics.rectangle("fill", bx, by, barW * ratio, barH)
end

-- 死亡时回调，覆盖基类实现
-- @return pickups: 死亡时生成的掉落物列表
function Enemy:onDeath()
    self._isDead    = true
    self._isVisible = false

    -- 生成掉落物列表
    local pickups = {}

    -- 经验掉落
    if self._expDrop > 0 then
        table.insert(pickups, Pickup.new(
            self.x, self.y,
            Pickup.TYPE.EXP,
            self._expDrop))
    end

    -- 灵魂掉落
    if self._soulDrop > 0 then
        -- 灵魂掉落位置稍微偏移，避免和经验重叠
        table.insert(pickups, Pickup.new(
            self.x + math.random(-10, 10),
            self.y + math.random(-10, 10),
            Pickup.TYPE.SOUL,
            self._soulDrop))
    end

    -- 小概率掉落事件触发器（10% 概率）
    if math.random() < 0.10 then
        table.insert(pickups, Pickup.new(
            self.x + math.random(-15, 15),
            self.y + math.random(-15, 15),
            Pickup.TYPE.TRIGGER,
            1))
    end

    return pickups
end

-- 获取击杀经验值掉落量
-- @return 经验值数量（number）
function Enemy:getExpDrop()
    return self._expDrop
end

-- 获取击杀灵魂掉落量
-- @return 灵魂数量（number）
function Enemy:getSoulDrop()
    return self._soulDrop
end

return Enemy
