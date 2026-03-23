--[[
    src/systems/achievementManager.lua
    成就管理系统 — Phase 13
    负责读写 data/achievements.json，检测并解锁成就。
    成就定义由 config/achievements.lua 提供。
]]

local AchievementManager = {}

local FILE_PATH = "data/achievements.json"

-- ============================================================
-- 极简 JSON 编解码（直接复用 progressionManager 的内部实现）
-- ============================================================
local Json = {}

-- ---------- 编码 ----------
local function encodeValue(val, indent, currentIndent)
    local t = type(val)
    if t == "nil" then
        return "null"
    elseif t == "boolean" then
        return tostring(val)
    elseif t == "number" then
        if val ~= val then return "null" end
        return string.format(math.floor(val) == val and "%d" or "%.6g", val)
    elseif t == "string" then
        local escaped = val
            :gsub("\\", "\\\\")
            :gsub("\"", "\\\"")
            :gsub("\n", "\\n")
            :gsub("\r", "\\r")
            :gsub("\t", "\\t")
        return "\"" .. escaped .. "\""
    elseif t == "table" then
        local isArray = true
        local maxN = 0
        for k, _ in pairs(val) do
            if type(k) ~= "number" or k < 1 or math.floor(k) ~= k then
                isArray = false
                break
            end
            if k > maxN then maxN = k end
        end
        if isArray and maxN ~= #val then isArray = false end

        local nextIndent = currentIndent .. indent

        if isArray then
            if #val == 0 then return "[]" end
            local parts = {}
            for i = 1, #val do
                parts[i] = nextIndent .. encodeValue(val[i], indent, nextIndent)
            end
            return "[\n" .. table.concat(parts, ",\n") .. "\n" .. currentIndent .. "]"
        else
            local parts = {}
            local keys = {}
            for k in pairs(val) do keys[#keys + 1] = k end
            table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
            for _, k in ipairs(keys) do
                local keyStr = "\"" .. tostring(k) .. "\""
                parts[#parts + 1] = nextIndent .. keyStr .. ": " .. encodeValue(val[k], indent, nextIndent)
            end
            if #parts == 0 then return "{}" end
            return "{\n" .. table.concat(parts, ",\n") .. "\n" .. currentIndent .. "}"
        end
    else
        return "null"
    end
end

function Json.encode(val)
    return encodeValue(val, "  ", "")
end

-- ---------- 解码 ----------
local function skipWhitespace(s, i)
    while i <= #s do
        local c = s:sub(i, i)
        if c == " " or c == "\t" or c == "\n" or c == "\r" then
            i = i + 1
        else
            break
        end
    end
    return i
end

local parseValue  -- 前向声明

local function parseString(s, i)
    i = i + 1
    local result = {}
    while i <= #s do
        local c = s:sub(i, i)
        if c == "\"" then
            return table.concat(result), i + 1
        elseif c == "\\" then
            local next = s:sub(i + 1, i + 1)
            if next == "\"" then result[#result + 1] = "\""
            elseif next == "\\" then result[#result + 1] = "\\"
            elseif next == "n" then result[#result + 1] = "\n"
            elseif next == "r" then result[#result + 1] = "\r"
            elseif next == "t" then result[#result + 1] = "\t"
            elseif next == "/" then result[#result + 1] = "/"
            else result[#result + 1] = next
            end
            i = i + 2
        else
            result[#result + 1] = c
            i = i + 1
        end
    end
    error("JSON: unterminated string")
end

local function parseNumber(s, i)
    local numStr = s:match("^-?%d+%.?%d*[eE]?[+-]?%d*", i)
    if not numStr then error("JSON: invalid number at " .. i) end
    return tonumber(numStr), i + #numStr
end

local function parseArray(s, i)
    i = i + 1
    local arr = {}
    i = skipWhitespace(s, i)
    if s:sub(i, i) == "]" then
        return arr, i + 1
    end
    while true do
        i = skipWhitespace(s, i)
        local val
        val, i = parseValue(s, i)
        arr[#arr + 1] = val
        i = skipWhitespace(s, i)
        local c = s:sub(i, i)
        if c == "]" then
            return arr, i + 1
        elseif c == "," then
            i = i + 1
        else
            error("JSON: expected ',' or ']' in array at " .. i)
        end
    end
end

local function parseObject(s, i)
    i = i + 1
    local obj = {}
    i = skipWhitespace(s, i)
    if s:sub(i, i) == "}" then
        return obj, i + 1
    end
    while true do
        i = skipWhitespace(s, i)
        if s:sub(i, i) ~= "\"" then
            error("JSON: expected string key at " .. i)
        end
        local key
        key, i = parseString(s, i)
        i = skipWhitespace(s, i)
        if s:sub(i, i) ~= ":" then
            error("JSON: expected ':' at " .. i)
        end
        i = i + 1
        i = skipWhitespace(s, i)
        local val
        val, i = parseValue(s, i)
        obj[key] = val
        i = skipWhitespace(s, i)
        local c = s:sub(i, i)
        if c == "}" then
            return obj, i + 1
        elseif c == "," then
            i = i + 1
        else
            error("JSON: expected ',' or '}' in object at " .. i)
        end
    end
end

parseValue = function(s, i)
    i = skipWhitespace(s, i)
    local c = s:sub(i, i)
    if c == "\"" then
        return parseString(s, i)
    elseif c == "{" then
        return parseObject(s, i)
    elseif c == "[" then
        return parseArray(s, i)
    elseif c == "t" then
        if s:sub(i, i + 3) == "true" then return true, i + 4 end
        error("JSON: invalid token at " .. i)
    elseif c == "f" then
        if s:sub(i, i + 4) == "false" then return false, i + 5 end
        error("JSON: invalid token at " .. i)
    elseif c == "n" then
        if s:sub(i, i + 3) == "null" then return nil, i + 4 end
        error("JSON: invalid token at " .. i)
    elseif c == "-" or (c >= "0" and c <= "9") then
        return parseNumber(s, i)
    else
        error("JSON: unexpected character '" .. c .. "' at " .. i)
    end
end

function Json.decode(s)
    local val, _ = parseValue(s, 1)
    return val
end

-- ============================================================
-- 内部状态
-- ============================================================
local _unlockedSet = nil   -- id → true，已解锁集合
local _config      = nil   -- 成就定义列表（从 config/achievements.lua 加载）
-- 每个成就的 condition progress 表：_progress[id] = {}
local _progress    = {}

-- ============================================================
-- 内部：懒加载成就配置
-- ============================================================
local function getConfig()
    if not _config then
        _config = require("config.achievements")
    end
    return _config
end

-- ============================================================
-- 1. load — 从 data/achievements.json 读取解锁状态
-- ============================================================
function AchievementManager.load()
    _unlockedSet = {}
    _progress    = {}

    local raw = love.filesystem.read(FILE_PATH)
    if raw then
        local ok, decoded = pcall(Json.decode, raw)
        if ok and decoded and type(decoded.unlocked) == "table" then
            for _, id in ipairs(decoded.unlocked) do
                _unlockedSet[id] = true
            end
        end
    end
end

-- ============================================================
-- 2. save — 写入 data/achievements.json
-- ============================================================
function AchievementManager.save()
    if not _unlockedSet then return end

    -- 将 set 转为有序数组（方便 diff/版本控制）
    local unlocked = {}
    for id, _ in pairs(_unlockedSet) do
        unlocked[#unlocked + 1] = id
    end
    table.sort(unlocked)

    local encoded = Json.encode({ unlocked = unlocked })
    love.filesystem.write(FILE_PATH, encoded)
end

-- ============================================================
-- 3. unlock — 强制解锁成就（内部调用）
-- ============================================================
function AchievementManager.unlock(id)
    if not _unlockedSet then AchievementManager.load() end
    if _unlockedSet[id] then return end  -- 已解锁，幂等
    _unlockedSet[id] = true
    AchievementManager.save()
end

-- ============================================================
-- 4. isUnlocked
-- ============================================================
function AchievementManager.isUnlocked(id)
    if not _unlockedSet then AchievementManager.load() end
    return _unlockedSet[id] == true
end

-- ============================================================
-- 5. notify — 通知游戏事件，检测所有未解锁成就的 condition
-- ============================================================
-- @param event  string — 事件名（如 "enemy_killed"、"boss_killed"、"game_end"）
-- @param data   table  — 事件附带数据
-- @return       array  — 本次 notify 新触发解锁的成就 id 列表（供 UI 弹出通知）
function AchievementManager.notify(event, data)
    if not _unlockedSet then AchievementManager.load() end
    data = data or {}

    local cfg = getConfig()
    local newlyUnlocked = {}

    for _, def in ipairs(cfg) do
        -- 只处理监听同一 event 且尚未解锁的成就
        if def.event == event and not _unlockedSet[def.id] then
            -- 懒初始化 progress 表
            if not _progress[def.id] then
                _progress[def.id] = {}
            end
            local ok, result = pcall(def.condition, data, _progress[def.id])
            if ok and result then
                AchievementManager.unlock(def.id)
                newlyUnlocked[#newlyUnlocked + 1] = def.id
            end
        end
    end

    return newlyUnlocked
end

-- ============================================================
-- 6. getAll — 返回所有成就（含解锁状态），供 UI 遍历
-- ============================================================
-- 每个元素：
--   { id, nameKey, descKey, icon, unlocked }
function AchievementManager.getAll()
    if not _unlockedSet then AchievementManager.load() end

    local cfg = getConfig()
    local result = {}
    for _, def in ipairs(cfg) do
        result[#result + 1] = {
            id       = def.id,
            nameKey  = def.nameKey  or def.id,
            descKey  = def.descKey  or "",
            icon     = def.icon     or "★",
            unlocked = _unlockedSet[def.id] == true,
        }
    end
    return result
end

return AchievementManager
