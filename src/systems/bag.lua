--[[
    src/systems/bag.lua
    背包管理系统
    Phase 6：武器背包系统
    Phase 7：接入相邻增益（Adjacency）和武器羁绊（Synergy）计算

    背包是一个二维网格，每格可被武器占据。
    所有放入背包的武器均视为"装备中"，会独立触发自动攻击。

    上限：最大 6 行 × 8 列（MAX_ROWS × MAX_COLS）
]]

local Bag = {}
Bag.__index = Bag

local MAX_ROWS = 6
local MAX_COLS = 8

-- 延迟加载，避免循环依赖
local _Adjacency = nil
local _Synergy   = nil

local function getAdjacency()
    if not _Adjacency then
        _Adjacency = require("src.systems.adjacency")
    end
    return _Adjacency
end

local function getSynergy()
    if not _Synergy then
        _Synergy = require("src.systems.synergy")
    end
    return _Synergy
end

-- ============================================================
-- 构造
-- ============================================================

-- 创建背包
-- @param rows: 初始行数（默认 2）
-- @param cols: 初始列数（默认 2）
function Bag.new(rows, cols)
    local self = setmetatable({}, Bag)
    self.rows    = rows or 2
    self.cols    = cols or 2
    self._grid   = {}   -- [row][col] = instanceId 或 nil
    self._weapons = {}  -- instanceId → Weapon 实例
    self._activeSynergies    = {}  -- Phase 7：当前激活的羁绊列表（由 Synergy.recalculate 填充）
    -- Phase 7.2：Tag 羁绊系统新增字段
    self._tagCounts          = {}  -- { 速射=2, 精准=1, … } 用于 UI 显示进度
    self._playerSynergyBonus = {   -- 玩家全局属性加成（作用于 game.lua 各系统）
        speed       = 0,
        damage      = 0,
        critChance  = 0,
        critMult    = 0,
        maxHP       = 0,
        bulletSpeed = 0,
        pickupRange = 0,
        expMult     = 0,
    }

    -- 初始化空网格
    self:_initGrid()
    return self
end

-- 初始化（或重新初始化）网格，保留现有武器位置
function Bag:_initGrid()
    for r = 1, self.rows do
        if not self._grid[r] then
            self._grid[r] = {}
        end
        for c = 1, self.cols do
            -- 只填 nil，不覆盖已有数据
            if self._grid[r][c] == nil then
                self._grid[r][c] = nil
            end
        end
    end
end

-- ============================================================
-- 放置 / 移除
-- ============================================================

-- 检测武器能否放置在 (row, col)（0-indexed → 内部 1-indexed）
-- @param weapon:  Weapon 实例
-- @param row:     放置锚点行（1-indexed）
-- @param col:     放置锚点列（1-indexed）
-- @return true/false, 失败原因字符串（可选）
function Bag:canPlace(weapon, row, col)
    local cells = weapon:getCells(row, col)
    for _, cell in ipairs(cells) do
        -- 越界检查
        if cell.row < 1 or cell.row > self.rows
        or cell.col < 1 or cell.col > self.cols then
            return false, "out_of_bounds"
        end
        -- 占用冲突检查（允许同一武器重叠自身，用于移动预览）
        local existing = self._grid[cell.row][cell.col]
        if existing ~= nil and existing ~= weapon.instanceId then
            return false, "conflict"
        end
    end
    return true
end

-- 放置武器到背包
-- @param weapon:  Weapon 实例
-- @param row:     放置锚点行（1-indexed）
-- @param col:     放置锚点列（1-indexed）
-- @return true/false
function Bag:place(weapon, row, col)
    local ok, reason = self:canPlace(weapon, row, col)
    if not ok then return false, reason end

    -- 先移除旧位置（若已在背包中）
    if self._weapons[weapon.instanceId] then
        self:_clearFromGrid(weapon)
    end

    -- 写入网格
    local cells = weapon:getCells(row, col)
    for _, cell in ipairs(cells) do
        self._grid[cell.row][cell.col] = weapon.instanceId
    end

    -- 记录武器实例及其锚点
    weapon._bagRow = row
    weapon._bagCol = col
    self._weapons[weapon.instanceId] = weapon

    -- Phase 7：重新计算相邻增益和羁绊
    getAdjacency().recalculate(self)
    getSynergy().recalculate(self)

    return true
end

-- 从背包移除武器
-- @param weapon: Weapon 实例
function Bag:remove(weapon)
    if not self._weapons[weapon.instanceId] then return end
    self:_clearFromGrid(weapon)
    self._weapons[weapon.instanceId] = nil
    weapon._bagRow = nil
    weapon._bagCol = nil

    -- Phase 7：重新计算相邻增益和羁绊
    getAdjacency().recalculate(self)
    getSynergy().recalculate(self)
end

-- 清除网格中武器的占格记录
function Bag:_clearFromGrid(weapon)
    local row = weapon._bagRow
    local col = weapon._bagCol
    if not row or not col then return end

    local cells = weapon:getCells(row, col)
    for _, cell in ipairs(cells) do
        if self._grid[cell.row] and self._grid[cell.row][cell.col] == weapon.instanceId then
            self._grid[cell.row][cell.col] = nil
        end
    end
end

-- ============================================================
-- 扩展
-- ============================================================

-- 扩展背包大小
-- @param dRows: 增加的行数
-- @param dCols: 增加的列数
-- @return 实际扩展后的 rows, cols
function Bag:expand(dRows, dCols)
    self.rows = math.min(self.rows + (dRows or 0), MAX_ROWS)
    self.cols = math.min(self.cols + (dCols or 0), MAX_COLS)
    self:_initGrid()
    return self.rows, self.cols
end

-- ============================================================
-- 查询
-- ============================================================

-- 获取指定格的武器实例
-- @param row, col: 1-indexed
-- @return Weapon 实例，或 nil
function Bag:getWeaponAt(row, col)
    if not self._grid[row] then return nil end
    local id = self._grid[row][col]
    if not id then return nil end
    return self._weapons[id]
end

-- 获取背包中所有武器实例列表（去重，按 instanceId 排序）
-- @return { Weapon, ... }
function Bag:getAllWeapons()
    local list = {}
    for _, weapon in pairs(self._weapons) do
        table.insert(list, weapon)
    end
    table.sort(list, function(a, b) return a.instanceId < b.instanceId end)
    return list
end

-- 背包是否有空间放置某个武器（暴力扫描所有位置）
-- @param weapon: Weapon 实例
-- @return true/false
function Bag:hasSpace(weapon)
    for r = 1, self.rows do
        for c = 1, self.cols do
            if self:canPlace(weapon, r, c) then
                return true
            end
        end
    end
    return false
end

-- 返回最大行/列上限（供 UI 参考）
function Bag.getMaxSize()
    return MAX_ROWS, MAX_COLS
end

return Bag
