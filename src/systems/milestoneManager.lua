--[[
    src/systems/milestoneManager.lua
    里程碑系统 — Phase 13
    追踪当前局内的里程碑进度。
    游戏事件通过 notify() 驱动条件判断；局结束时统计得分并写入 progressionManager。
]]

local MilestoneManager = {}
MilestoneManager.__index = MilestoneManager

-- ============================================================
-- 1. new
-- ============================================================
-- @param characterId  string — 当前局选择的角色 id（如 "engineer"）
-- @return instance
function MilestoneManager.new(characterId)
    local self = setmetatable({}, MilestoneManager)

    self._characterId = characterId
    self._completed   = {}   -- 已完成的里程碑列表，元素：{id, points, nameKey, descKey}
    self._completedSet = {}  -- id → true，快速去重
    self._totalPoints = 0    -- 本局累计里程碑点数

    -- 从角色配置表中读取里程碑定义
    local CharacterConfig = require("config.characters")
    local charCfg = CharacterConfig[characterId]

    -- 里程碑追踪状态：每个里程碑对应独立的 progress 表
    -- _trackers[i] = { def = <milestone定义>, progress = {}, done = false }
    self._trackers = {}

    if charCfg and charCfg.milestones then
        for _, ms in ipairs(charCfg.milestones) do
            self._trackers[#self._trackers + 1] = {
                def      = ms,
                progress = {},
                done     = false,
            }
        end
    end

    return self
end

-- ============================================================
-- 2. notify
-- ============================================================
-- 通知一个游戏事件，驱动所有尚未完成的里程碑进行条件检查。
-- @param event  string — 事件名（如 "enemy_killed"、"skill_activated"、"tick"、"game_end"）
-- @param data   table  — 事件附带数据（可为空表）
function MilestoneManager:notify(event, data)
    data = data or {}
    for _, tracker in ipairs(self._trackers) do
        if not tracker.done then
            local ms = tracker.def
            -- 只处理监听同一 event 的里程碑
            if ms.event == event then
                local ok, result = pcall(ms.condition, data, tracker.progress)
                if ok and result then
                    -- 标记完成
                    tracker.done = true
                    if not self._completedSet[ms.id] then
                        self._completedSet[ms.id] = true
                        self._totalPoints = self._totalPoints + (ms.points or 0)
                        self._completed[#self._completed + 1] = {
                            id      = ms.id,
                            points  = ms.points or 0,
                            nameKey = ms.nameKey or ms.id,
                            descKey = ms.descKey or "",
                        }
                    end
                end
            end
        end
    end
end

-- ============================================================
-- 3. getCompletedList
-- ============================================================
-- 返回本局已完成的里程碑列表（副本），元素：{id, points, nameKey, descKey}
function MilestoneManager:getCompletedList()
    local result = {}
    for _, entry in ipairs(self._completed) do
        result[#result + 1] = {
            id      = entry.id,
            points  = entry.points,
            nameKey = entry.nameKey,
            descKey = entry.descKey,
        }
    end
    return result
end

-- ============================================================
-- 4. getProgressSummary
-- ============================================================
-- 返回所有里程碑的进度摘要（供结算界面显示）
-- 每个元素：{ id, nameKey, descKey, done, points, progress }
--   progress 为该里程碑当前的 progress 表（只读参考）
function MilestoneManager:getProgressSummary()
    local result = {}
    for _, tracker in ipairs(self._trackers) do
        local ms = tracker.def
        result[#result + 1] = {
            id       = ms.id,
            nameKey  = ms.nameKey or ms.id,
            descKey  = ms.descKey or "",
            points   = ms.points or 0,
            done     = tracker.done,
            progress = tracker.progress,  -- 外部只读，不应修改
        }
    end
    return result
end

-- ============================================================
-- 5. getTotalPointsEarned
-- ============================================================
function MilestoneManager:getTotalPointsEarned()
    return self._totalPoints
end

return MilestoneManager
