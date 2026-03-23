--[[
    src/systems/buffManager.lua
    Buff 管理器 — Phase 10.1
    统一管理 timer 型和 stack 型 Buff 状态。

    Timer 型 Buff：
        add(buffId, duration, params, player)
            — 首次激活调用 onApply；刷新时取 max(remaining, duration)，不重复调用 onApply
        remove(buffId, player)  — 立即移除，调用 onRemove
        update(dt, player)      — 每帧倒计时，到期调用 onRemove

    Stack 型 Buff：
        addStack(buffId, count, player)          — 增加层数
        consumeStack(buffId, player) → boolean   — 消耗 1 层；归零时调用 onRemove
        getStacks(buffId) → number

    公共：
        has(buffId) → boolean
        get(buffId) → entry | nil
        getAll()    → 排序数组（供 HUD 迭代）
        clear(player) — 全清，各自调用 onRemove
]]

local BuffDefs = require("config.buffs")

local BuffManager = {}
BuffManager.__index = BuffManager

-- 构造新的 BuffManager 实例
function BuffManager.new()
    local self = setmetatable({}, BuffManager)
    self._timerBuffs = {}   -- [buffId] = { id, remaining, duration, params, def }
    self._stackBuffs = {}   -- [buffId] = { id, stacks, def }
    return self
end

-- ============================================================
-- Timer 型接口
-- ============================================================

-- 添加或刷新一个 timer 型 Buff
-- 首次激活调用 onApply；刷新时取 max(remaining, duration)，不重调 onApply
-- @param buffId   — Buff 配置 ID（对应 config/buffs.lua 的 key）
-- @param duration — Buff 持续时长（秒）
-- @param params   — 传递给 onApply/onRemove 的参数表（可为 nil）
-- @param player   — 玩家实例（onApply 中使用）
function BuffManager:add(buffId, duration, params, player)
    local def = BuffDefs[buffId]
    if not def then return end
    if def.buffType ~= "timer" then return end

    local existing = self._timerBuffs[buffId]
    if existing then
        -- 刷新：取较大值（不重复调用 onApply）
        existing.remaining = math.max(existing.remaining, duration)
        -- duration 也更新为新的标准时长（用于 HUD 进度条计算）
        if duration > existing.duration then
            existing.duration = duration
        end
    else
        -- 首次激活
        local entry = {
            id        = buffId,
            remaining = duration,
            duration  = duration,
            params    = params or {},
            def       = def,
        }
        self._timerBuffs[buffId] = entry
        -- 调用 onApply
        if def.onApply and player then
            def.onApply(player, entry.params)
        end
    end
end

-- 立即移除一个 timer 型 Buff，调用 onRemove
-- @param buffId — Buff ID
-- @param player — 玩家实例（onRemove 中使用）
function BuffManager:remove(buffId, player)
    local entry = self._timerBuffs[buffId]
    if not entry then return end
    self._timerBuffs[buffId] = nil
    local def = entry.def
    if def and def.onRemove and player then
        def.onRemove(player, entry.params, entry)
    end
end

-- 每帧更新所有 timer 型 Buff 的倒计时
-- @param dt     — 帧时间（秒）
-- @param player — 玩家实例（onRemove 中使用）
function BuffManager:update(dt, player)
    -- 先收集到期的 buffId，避免迭代中修改表
    local expired = {}
    for buffId, entry in pairs(self._timerBuffs) do
        entry.remaining = entry.remaining - dt
        if entry.remaining <= 0 then
            table.insert(expired, buffId)
        end
    end
    -- 处理到期
    for _, buffId in ipairs(expired) do
        self:remove(buffId, player)
    end
end

-- ============================================================
-- Stack 型接口
-- ============================================================

-- 增加 stack 型 Buff 的层数
-- @param buffId — Buff ID
-- @param count  — 增加层数（默认 1）
-- @param player — 玩家实例（首次添加时调用 onApply）
function BuffManager:addStack(buffId, count, player)
    local def = BuffDefs[buffId]
    if not def then return end
    if def.buffType ~= "stack" then return end

    count = count or 1
    local existing = self._stackBuffs[buffId]
    if existing then
        existing.stacks = existing.stacks + count
    else
        local entry = {
            id     = buffId,
            stacks = count,
            def    = def,
        }
        self._stackBuffs[buffId] = entry
        if def.onApply and player then
            def.onApply(player, {})
        end
    end
end

-- 消耗一层 stack 型 Buff
-- 层数归零时调用 onRemove 并从表中删除
-- @param buffId — Buff ID
-- @param player — 玩家实例（onRemove 中使用）
-- @return boolean — 是否成功消耗（有层数则返回 true）
function BuffManager:consumeStack(buffId, player)
    local entry = self._stackBuffs[buffId]
    if not entry or entry.stacks <= 0 then return false end
    entry.stacks = entry.stacks - 1
    if entry.stacks <= 0 then
        self._stackBuffs[buffId] = nil
        local def = entry.def
        if def and def.onRemove and player then
            def.onRemove(player, {}, entry)
        end
    end
    return true
end

-- 获取 stack 型 Buff 的当前层数
-- @param buffId — Buff ID
-- @return number — 当前层数（不存在则返回 0）
function BuffManager:getStacks(buffId)
    local entry = self._stackBuffs[buffId]
    return entry and entry.stacks or 0
end

-- ============================================================
-- 公共查询接口
-- ============================================================

-- 检查某个 Buff 是否激活（timer 型未到期，或 stack 型有层数）
-- @param buffId — Buff ID
-- @return boolean
function BuffManager:has(buffId)
    if self._timerBuffs[buffId] then return true end
    local se = self._stackBuffs[buffId]
    if se and se.stacks > 0 then return true end
    return false
end

-- 获取 Buff 条目（timer 型返回 timerEntry，stack 型返回 stackEntry，不存在返回 nil）
-- @param buffId — Buff ID
-- @return entry | nil
function BuffManager:get(buffId)
    return self._timerBuffs[buffId] or self._stackBuffs[buffId]
end

-- 获取所有活跃 Buff 的排序数组（供 HUD 迭代）
-- 格式：{ { id, type="timer"|"stack", remaining, duration, stacks, def }, ... }
-- @return table (array)
function BuffManager:getAll()
    local list = {}
    for buffId, entry in pairs(self._timerBuffs) do
        table.insert(list, {
            id        = buffId,
            buffType  = "timer",
            remaining = entry.remaining,
            duration  = entry.duration,
            params    = entry.params,
            def       = entry.def,
        })
    end
    for buffId, entry in pairs(self._stackBuffs) do
        if entry.stacks > 0 then
            table.insert(list, {
                id       = buffId,
                buffType = "stack",
                stacks   = entry.stacks,
                def      = entry.def,
            })
        end
    end
    -- 按 buffId 排序，保证 HUD 显示顺序稳定
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

-- 清除所有 Buff，各自调用 onRemove
-- @param player — 玩家实例
function BuffManager:clear(player)
    -- 清除 timer 型
    local timerIds = {}
    for buffId, _ in pairs(self._timerBuffs) do
        table.insert(timerIds, buffId)
    end
    for _, buffId in ipairs(timerIds) do
        self:remove(buffId, player)
    end
    -- 清除 stack 型
    local stackIds = {}
    for buffId, _ in pairs(self._stackBuffs) do
        table.insert(stackIds, buffId)
    end
    for _, buffId in ipairs(stackIds) do
        local entry = self._stackBuffs[buffId]
        if entry then
            self._stackBuffs[buffId] = nil
            local def = entry.def
            if def and def.onRemove and player then
                def.onRemove(player, {}, entry)
            end
        end
    end
end

return BuffManager
