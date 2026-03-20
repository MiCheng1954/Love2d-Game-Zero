--[[
    src/entities/weapon.lua
    武器实例类
    Phase 6：武器背包系统

    每把武器有独立的实例 ID、当前旋转形状、等级、攻击计时器。
    放入背包即生效，自动对最近敌人独立开火。
]]

local WeaponConfig = require("config.weapons")

local Weapon = {}
Weapon.__index = Weapon

-- 全局实例 ID 计数器（本局内单调递增）
local _nextId = 1

-- ============================================================
-- 构造 / 销毁
-- ============================================================

-- 从配置 ID 创建武器实例
-- @param configId: 武器配置 key，如 "pistol"
-- @return Weapon 实例
function Weapon.new(configId)
    local cfg = WeaponConfig[configId]
    assert(cfg, "Weapon.new: 未知武器 ID [" .. tostring(configId) .. "]")

    local self  = setmetatable({}, Weapon)
    self.configId    = configId
    self.instanceId  = _nextId
    _nextId          = _nextId + 1

    -- 从配置拷贝属性（运行时可被 levelBonus 修改）
    self.damage      = cfg.damage
    self.attackSpeed = cfg.attackSpeed
    self.bulletSpeed = cfg.bulletSpeed
    self.range       = cfg.range
    self.color       = cfg.color
    self.nameKey     = cfg.nameKey
    self.descKey     = cfg.descKey
    self.maxLevel    = cfg.maxLevel
    self.levelBonus  = cfg.levelBonus

    self.level       = 1
    self._shape      = self:_copyShape(cfg.shape)  -- 当前旋转后的形状
    self._attackTimer = 0                           -- 独立攻击冷却计时器

    return self
end

-- 重置全局 ID 计数器（新局开始时调用）
function Weapon.resetIdCounter()
    _nextId = 1
end

-- ============================================================
-- 形状 / 旋转
-- ============================================================

-- 深拷贝形状数组
function Weapon:_copyShape(shape)
    local copy = {}
    for _, cell in ipairs(shape) do
        table.insert(copy, { cell[1], cell[2] })
    end
    return copy
end

-- 旋转 90°（顺时针）：(r,c) → (c, maxR-r) 为逆时针，顺时针为 (r,c) → (maxC-c, r)
-- 旋转后重新对齐到原点（最小 row/col 归 0）
function Weapon:rotate()
    -- 找最大 col（顺时针公式需要）
    local maxC = 0
    for _, cell in ipairs(self._shape) do
        if cell[2] > maxC then maxC = cell[2] end
    end

    local rotated = {}
    for _, cell in ipairs(self._shape) do
        -- 顺时针 90°：新row = maxC - oldCol，新col = oldRow
        table.insert(rotated, { maxC - cell[2], cell[1] })
    end

    -- 对齐到原点：找 minRow, minCol
    local minR, minC = math.huge, math.huge
    for _, cell in ipairs(rotated) do
        if cell[1] < minR then minR = cell[1] end
        if cell[2] < minC then minC = cell[2] end
    end
    for _, cell in ipairs(rotated) do
        cell[1] = cell[1] - minR
        cell[2] = cell[2] - minC
    end

    self._shape = rotated
end

-- 获取包围盒大小
-- @return rows（行数）, cols（列数）
function Weapon:getBounds()
    local maxR, maxC = 0, 0
    for _, cell in ipairs(self._shape) do
        if cell[1] > maxR then maxR = cell[1] end
        if cell[2] > maxC then maxC = cell[2] end
    end
    return maxR + 1, maxC + 1
end

-- 获取放置在 (originRow, originCol) 时所有占格坐标
-- @param originRow: 放置锚点行
-- @param originCol: 放置锚点列
-- @return {{row, col}, ...} 列表
function Weapon:getCells(originRow, originCol)
    local cells = {}
    for _, cell in ipairs(self._shape) do
        table.insert(cells, {
            row = originRow + cell[1],
            col = originCol + cell[2],
        })
    end
    return cells
end

-- 获取形状的只读副本（供 UI 绘制用）
function Weapon:getShape()
    return self:_copyShape(self._shape)
end

-- ============================================================
-- 战斗
-- ============================================================

-- 获取有效伤害（武器伤害 + 玩家基础攻击加成）
-- @param playerAttack: 玩家基础攻击力
-- @return 实际伤害值
function Weapon:getEffectiveDamage(playerAttack)
    return self.damage + (playerAttack or 0)
end

-- 每帧推进攻击计时器，返回本帧应发射的次数（通常 0 或 1）
-- @param dt: 帧时间（秒）
-- @return 发射次数（integer）
function Weapon:tickAttack(dt)
    self._attackTimer = self._attackTimer + dt
    local interval = 1.0 / self.attackSpeed
    local shots = 0
    while self._attackTimer >= interval do
        self._attackTimer = self._attackTimer - interval
        shots = shots + 1
    end
    return shots
end

-- ============================================================
-- 升级
-- ============================================================

-- 武器升级，应用 levelBonus
-- @return 是否升级成功（已满级则返回 false）
function Weapon:levelUp()
    if self.level >= self.maxLevel then return false end
    self.level = self.level + 1
    if self.levelBonus then
        if self.levelBonus.damage then
            self.damage = self.damage + self.levelBonus.damage
        end
        if self.levelBonus.attackSpeed then
            self.attackSpeed = self.attackSpeed + self.levelBonus.attackSpeed
        end
        if self.levelBonus.range then
            self.range = self.range + self.levelBonus.range
        end
    end
    return true
end

return Weapon
