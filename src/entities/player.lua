--[[
    src/entities/player.lua
    玩家类，继承自 Entity
    负责处理玩家的移动、渲染以及状态管理
]]

local Entity       = require("src.entities.entity")
local Input        = require("src.systems.input")
local Bag          = require("src.systems.bag")
local Weapon       = require("src.entities.weapon")
local SkillManager = require("src.systems.skillManager")

local Player = setmetatable({}, { __index = Entity })
Player.__index = Player

-- 玩家外观配置（代码绘制 fallback 使用，替换资产时修改 _sprite 即可）
local PLAYER_RADIUS = 16            -- 玩家碰撞圆半径（像素）
local PLAYER_COLOR  = {0.2, 0.6, 1} -- 玩家颜色（蓝色）

-- 构造函数，创建一个新的玩家实例
-- @param x: 初始世界坐标 X
-- @param y: 初始世界坐标 Y
function Player.new(x, y)
    -- 调用父类构造
    local self = setmetatable(Entity.new(x, y), Player)

    -- 覆盖基类属性
    self.speed        = 300   -- 玩家移动速度（像素/秒）
    self.maxHp        = 100   -- 玩家最大生命值
    self.hp           = 100   -- 玩家当前生命值
    self.width        = PLAYER_RADIUS * 2   -- 碰撞体宽度
    self.height       = PLAYER_RADIUS * 2   -- 碰撞体高度

    -- 玩家专属属性
    self._level       = 1     -- 当前等级
    self._exp         = 0     -- 当前经验值
    self._expToNext   = 100   -- 升级所需经验值
    self._souls       = 0     -- 当前持有灵魂数量
    self._revives     = 1     -- 剩余复活次数

    -- 战斗属性（Phase 8 补全）
    self.attack       = 10    -- 基础攻击力
    self.critRate     = 0.05  -- 基础暴击率
    self.critDamage   = 1.5   -- 基础暴击倍率
    self.defense      = 0     -- 伤害减免比（0~1，Phase 8 新增）

    -- 角色身份（Phase 8 角色专属技能过滤用）
    self.characterId  = "default"

    -- 移动状态
    self._dx          = 0     -- 当前帧水平移动方向
    self._dy          = 0     -- 当前帧垂直移动方向

    -- 技能管理器（Phase 8）
    self._skillManager = SkillManager.new()

    -- 背包（初始 2×2，武器放入即视为装备）
    Weapon.resetIdCounter()
    self._bag = Bag.new(2, 2)

    -- 需求2：覆盖拾取半径和经验倍率
    self.pickupRadius = 1000
    self.expBonus     = 2.0

    -- 需求1：默认装备一把手枪放到背包 (1,1)
    local pistol = Weapon.new("pistol")
    self._bag:place(pistol, 1, 1)

    return self
end

-- 每帧更新玩家逻辑
-- @param dt: 距上一帧的时间间隔（秒）
-- @param extraSpeed: 额外移动速度加成（来自羁绊，可选）
function Player:update(dt, extraSpeed)
    self:_handleMovement(dt, extraSpeed)
end

-- 处理玩家移动逻辑
-- @param dt: 距上一帧的时间间隔（秒）
-- @param extraSpeed: 额外移动速度加成（可选）
function Player:_handleMovement(dt, extraSpeed)
    -- 从输入系统获取方向
    self._dx, self._dy = Input.getMoveDirection()

    -- 更新位置（基础速度 + 羁绊加成）
    local effectiveSpeed = self.speed + (extraSpeed or 0)
    self.x = self.x + self._dx * effectiveSpeed * dt
    self.y = self.y + self._dy * effectiveSpeed * dt
end

-- 将玩家绘制到屏幕上
function Player:draw()
    if not self._isVisible then return end

    if self._sprite then
        -- 有资产时：绘制贴图（预留接口）
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(self._sprite, self.x, self.y, 0, 1, 1,
            self.width / 2, self.height / 2)
    else
        -- 无资产时：代码绘制 fallback
        -- 身体（蓝色圆形）
        love.graphics.setColor(PLAYER_COLOR)
        love.graphics.circle("fill", self.x, self.y, PLAYER_RADIUS)

        -- 边框（深蓝色）
        love.graphics.setColor(0.1, 0.3, 0.7)
        love.graphics.circle("line", self.x, self.y, PLAYER_RADIUS)

        -- 方向指示点（朝向最后移动的方向）
        if self._dx ~= 0 or self._dy ~= 0 then
            love.graphics.setColor(1, 1, 1)
            love.graphics.circle("fill",
                self.x + self._dx * PLAYER_RADIUS * 0.6,
                self.y + self._dy * PLAYER_RADIUS * 0.6,
                3)
        end
    end
end

-- 玩家拾取经验值，只负责累加，升级检测交由 Experience 系统处理
-- @param amount: 经验值数量
function Player:gainExp(amount)
    self._exp = self._exp + math.floor(amount * self.expBonus)
end

-- 玩家拾取灵魂
-- @param amount: 灵魂数量
function Player:gainSouls(amount)
    self._souls = self._souls + math.floor(amount * self.soulBonus)
end

-- 消耗灵魂
-- @param amount: 消耗数量
-- @return 是否消耗成功（boolean）
function Player:spendSouls(amount)
    if self._souls < amount then return false end
    self._souls = self._souls - amount
    return true
end

-- 处理升级逻辑
function Player:_levelUp()
    self._exp      = self._exp - self._expToNext
    self._level    = self._level + 1
    self._expToNext = math.floor(self._expToNext * 1.2)  -- 每级所需经验递增20%

    -- 升级时基础属性自动成长
    self.maxHp  = self.maxHp  + 10
    self.hp     = math.min(self.hp + 20, self.maxHp)     -- 升级回复部分血量
    self.attack = self.attack + 2
end

-- 死亡时回调，覆盖基类实现
function Player:onDeath()
    self._isDead = true
    -- TODO: Phase 10 接入传承系统与复活逻辑
end

-- 获取当前等级
-- @return 当前等级（number）
function Player:getLevel()
    return self._level
end

-- 获取经验进度（0~1）
-- @return 经验进度比例（number）
function Player:getExpProgress()
    return self._exp / self._expToNext
end

-- 获取当前灵魂数量
-- @return 灵魂数量（number）
function Player:getSouls()
    return self._souls
end

-- 获取背包实例
-- @return Bag 实例
function Player:getBag()
    return self._bag
end

-- 获取技能管理器实例（Phase 8）
-- @return SkillManager 实例
function Player:getSkillManager()
    return self._skillManager
end

return Player
