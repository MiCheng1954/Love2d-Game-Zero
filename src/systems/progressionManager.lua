--[[
    src/systems/progressionManager.lua
    局外成长数据管理器 — Phase 13
    负责读写 data/progression.json，管理通用成长点数与角色里程碑点数 / 技能树节点解锁。
]]

local ProgressionManager = {}

-- ============================================================
-- 通用属性定义
-- ============================================================
local COMMON_ATTRS = {
    attack   = { maxLevel = 5, costPerLevel = 10, bonusPerLevel = 5  },  -- 攻击力 +5% 每档
    speed    = { maxLevel = 5, costPerLevel = 8,  bonusPerLevel = 5  },  -- 移速 +5%
    maxhp    = { maxLevel = 5, costPerLevel = 8,  bonusPerLevel = 10 },  -- 最大HP +10
    critrate = { maxLevel = 3, costPerLevel = 15, bonusPerLevel = 3  },  -- 暴击率 +3%
    pickup   = { maxLevel = 3, costPerLevel = 8,  bonusPerLevel = 10 },  -- 拾取范围 +10%
    expmult  = { maxLevel = 3, costPerLevel = 12, bonusPerLevel = 10 },  -- 经验获取 +10%
}

local FILE_PATH = "data/progression.json"

-- ============================================================
-- 默认数据结构
-- ============================================================
local function makeDefault()
    return {
        commonPoints = 0,
        commonLevels = {
            attack   = 0,
            speed    = 0,
            maxhp    = 0,
            critrate = 0,
            pickup   = 0,
            expmult  = 0,
        },
        characters = {
            engineer = { milestonePoints = 0, unlockedNodes = {} },
            berserker = { milestonePoints = 0, unlockedNodes = {} },
            phantom   = { milestonePoints = 0, unlockedNodes = {} },
        },
        treeNodes = {},   -- 通用机制树已解锁节点ID列表（所有角色共用）
    }
end

-- ============================================================
-- 极简 JSON 编解码（只支持数字/字符串/布尔/nil/数组/对象）
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
        if val ~= val then return "null" end          -- NaN 处理
        return string.format(math.floor(val) == val and "%d" or "%.6g", val)
    elseif t == "string" then
        -- 转义特殊字符
        local escaped = val
            :gsub("\\", "\\\\")
            :gsub("\"", "\\\"")
            :gsub("\n", "\\n")
            :gsub("\r", "\\r")
            :gsub("\t", "\\t")
        return "\"" .. escaped .. "\""
    elseif t == "table" then
        -- 判断是数组还是对象
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
    -- i 指向起始 "
    i = i + 1  -- 跳过 "
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
    i = i + 1  -- 跳过 [
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
    i = i + 1  -- 跳过 {
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
-- 内部数据（运行时缓存）
-- ============================================================
local _data = nil  -- 当前加载的数据

-- ============================================================
-- 工具：确保 characters 表里有指定角色的记录
-- ============================================================
local function ensureChar(charId)
    if not _data.characters[charId] then
        _data.characters[charId] = { milestonePoints = 0, unlockedNodes = {} }
    end
end

-- ============================================================
-- 1. load
-- ============================================================
function ProgressionManager.load()
    local raw = love.filesystem.read(FILE_PATH)
    if raw then
        local ok, decoded = pcall(Json.decode, raw)
        if ok and decoded then
            -- 补齐缺失字段（向前兼容）
            if type(decoded.commonPoints) ~= "number" then decoded.commonPoints = 0 end
            if type(decoded.commonLevels) ~= "table" then decoded.commonLevels = {} end
            if type(decoded.characters) ~= "table" then decoded.characters = {} end
            if type(decoded.treeNodes) ~= "table" then decoded.treeNodes = {} end
            -- 补齐每个通用属性
            for attr, _ in pairs(COMMON_ATTRS) do
                if type(decoded.commonLevels[attr]) ~= "number" then
                    decoded.commonLevels[attr] = 0
                end
            end
            -- 补齐预置角色
            local defaultChars = { "engineer", "berserker", "phantom" }
            for _, cid in ipairs(defaultChars) do
                if type(decoded.characters[cid]) ~= "table" then
                    decoded.characters[cid] = { milestonePoints = 0, unlockedNodes = {} }
                end
                if type(decoded.characters[cid].unlockedNodes) ~= "table" then
                    decoded.characters[cid].unlockedNodes = {}
                end
                if type(decoded.characters[cid].milestonePoints) ~= "number" then
                    decoded.characters[cid].milestonePoints = 0
                end
            end
            _data = decoded
        else
            _data = makeDefault()
        end
    else
        _data = makeDefault()
    end
    return _data
end

-- ============================================================
-- 2. save
-- ============================================================
function ProgressionManager.save()
    if not _data then return end
    local encoded = Json.encode(_data)
    love.filesystem.write(FILE_PATH, encoded)
end

-- ============================================================
-- 3. getCommonPoints
-- ============================================================
function ProgressionManager.getCommonPoints()
    if not _data then ProgressionManager.load() end
    return _data.commonPoints
end

-- ============================================================
-- 4. addCommonPoints
-- ============================================================
function ProgressionManager.addCommonPoints(n)
    if not _data then ProgressionManager.load() end
    _data.commonPoints = (_data.commonPoints or 0) + n
    ProgressionManager.save()
end

-- ============================================================
-- 5. getCommonLevel
-- ============================================================
function ProgressionManager.getCommonLevel(attr)
    if not _data then ProgressionManager.load() end
    return _data.commonLevels[attr] or 0
end

-- ============================================================
-- 6. upgradeCommon
-- ============================================================
function ProgressionManager.upgradeCommon(attr)
    if not _data then ProgressionManager.load() end
    local def = COMMON_ATTRS[attr]
    if not def then
        return false  -- 未知属性
    end
    local curLevel = _data.commonLevels[attr] or 0
    if curLevel >= def.maxLevel then
        return false  -- 已到最大档
    end
    local cost = def.costPerLevel
    if (_data.commonPoints or 0) < cost then
        return false  -- 点数不足
    end
    _data.commonPoints = _data.commonPoints - cost
    _data.commonLevels[attr] = curLevel + 1
    ProgressionManager.save()
    return true
end

-- ============================================================
-- 7. getMilestonePoints
-- ============================================================
function ProgressionManager.getMilestonePoints(charId)
    if not _data then ProgressionManager.load() end
    ensureChar(charId)
    return _data.characters[charId].milestonePoints or 0
end

-- ============================================================
-- 8. addMilestonePoints
-- ============================================================
function ProgressionManager.addMilestonePoints(charId, n)
    if not _data then ProgressionManager.load() end
    ensureChar(charId)
    _data.characters[charId].milestonePoints =
        (_data.characters[charId].milestonePoints or 0) + n
    ProgressionManager.save()
end

-- ============================================================
-- 9. isNodeUnlocked
-- ============================================================
function ProgressionManager.isNodeUnlocked(charId, nodeId)
    if not _data then ProgressionManager.load() end
    ensureChar(charId)
    local nodes = _data.characters[charId].unlockedNodes
    for _, id in ipairs(nodes) do
        if id == nodeId then return true end
    end
    return false
end

-- ============================================================
-- 10. unlockNode
-- ============================================================
function ProgressionManager.unlockNode(charId, nodeId)
    if not _data then ProgressionManager.load() end
    ensureChar(charId)

    -- 已解锁则直接返回 false
    if ProgressionManager.isNodeUnlocked(charId, nodeId) then
        return false
    end

    -- 从 characters.lua 中查找节点定义
    local CharacterConfig = require("config.characters")
    local charCfg = CharacterConfig[charId]
    if not charCfg or not charCfg.skillTree then
        return false
    end

    local nodeDef = nil
    for _, node in ipairs(charCfg.skillTree) do
        if node.id == nodeId then
            nodeDef = node
            break
        end
    end
    if not nodeDef then return false end

    -- 检查前置节点是否已全部解锁
    if nodeDef.requires then
        for _, reqId in ipairs(nodeDef.requires) do
            if not ProgressionManager.isNodeUnlocked(charId, reqId) then
                return false  -- 前置未满足
            end
        end
    end

    -- 检查里程碑点数是否足够
    local pts = _data.characters[charId].milestonePoints or 0
    if pts < (nodeDef.cost or 0) then
        return false  -- 点数不足
    end

    -- 扣除并解锁
    _data.characters[charId].milestonePoints = pts - nodeDef.cost
    local nodes = _data.characters[charId].unlockedNodes
    nodes[#nodes + 1] = nodeId
    ProgressionManager.save()
    return true
end

-- ============================================================
-- 11. getCommonBonus
-- ============================================================
function ProgressionManager.getCommonBonus()
    if not _data then ProgressionManager.load() end
    local bonus = {}
    for attr, def in pairs(COMMON_ATTRS) do
        local level = _data.commonLevels[attr] or 0
        bonus[attr] = level * def.bonusPerLevel
    end
    -- bonus.attack   → 攻击力百分比加成（0~25）
    -- bonus.speed    → 移速百分比加成（0~25）
    -- bonus.maxhp    → 最大HP加成（0~50）
    -- bonus.critrate → 暴击率加成（0~9，百分比单位）
    -- bonus.pickup   → 拾取范围百分比加成（0~30）
    -- bonus.expmult  → 经验获取百分比加成（0~30）
    return bonus
end

-- ============================================================
-- 12. getUnlockedNodes
-- ============================================================
function ProgressionManager.getUnlockedNodes(charId)
    if not _data then ProgressionManager.load() end
    ensureChar(charId)
    -- 返回副本，防止外部直接修改内部数据
    local result = {}
    for _, id in ipairs(_data.characters[charId].unlockedNodes) do
        result[#result + 1] = id
    end
    return result
end

-- ============================================================
-- 13. isTreeNodeUnlocked
-- ============================================================
function ProgressionManager.isTreeNodeUnlocked(nodeId)
    if not _data then ProgressionManager.load() end
    local nodes = _data.treeNodes
    for _, id in ipairs(nodes) do
        if id == nodeId then return true end
    end
    return false
end

-- ============================================================
-- 14. unlockTreeNode
-- ============================================================
function ProgressionManager.unlockTreeNode(nodeId)
    if not _data then ProgressionManager.load() end

    if ProgressionManager.isTreeNodeUnlocked(nodeId) then
        return false
    end

    local ProgressionTreeConfig = require("config.progressionTree")
    local nodeDef = nil
    for _, node in ipairs(ProgressionTreeConfig) do
        if node.id == nodeId then
            nodeDef = node
            break
        end
    end
    if not nodeDef then return false end

    -- 检查前置节点是否全部解锁
    if nodeDef.requires then
        for _, reqId in ipairs(nodeDef.requires) do
            if not ProgressionManager.isTreeNodeUnlocked(reqId) then
                return false
            end
        end
    end

    -- 检查通用点数是否足够
    local pts = _data.commonPoints or 0
    if pts < (nodeDef.cost or 0) then
        return false
    end

    _data.commonPoints = pts - nodeDef.cost
    local nodes = _data.treeNodes
    nodes[#nodes + 1] = nodeId
    ProgressionManager.save()
    return true
end

-- ============================================================
-- 15. getUnlockedTreeNodes
-- ============================================================
function ProgressionManager.getUnlockedTreeNodes()
    if not _data then ProgressionManager.load() end
    local result = {}
    for _, id in ipairs(_data.treeNodes) do
        result[#result + 1] = id
    end
    return result
end

return ProgressionManager
