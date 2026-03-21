--[[
    src/systems/legacyManager.lua
    传承技能管理器
    Phase 10：负责读写 data/legacy.json、按激活羁绊匹配传承池抽取候选、下局应用传承效果
]]

local LegacyManager = {}

local LegacyConfig = require("config.legacy")
local Log          = require("src.utils.log")

local SAVE_PATH = "legacy.json"   -- love.filesystem 根目录

-- ============================================================
-- 1. 读写 legacy.json
-- ============================================================

-- 读取已保存的传承数据
-- @return table 或 nil（若无存档）
-- 存档格式：{ id = "legacy_attack", category = "伤害", effect = {...} }
function LegacyManager.load()
    if not love.filesystem.getInfo(SAVE_PATH) then
        return nil
    end
    local content, err = love.filesystem.read(SAVE_PATH)
    if not content then
        Log.warn("legacyManager: 读取传承失败 " .. tostring(err))
        return nil
    end
    local ok, data = pcall(function()
        -- 简单 JSON 解析（依赖 LÖVE 内置或手写，此处用 Lua 模拟）
        return LegacyManager._parseJSON(content)
    end)
    if ok and data then
        return data
    end
    Log.warn("legacyManager: 解析传承 JSON 失败")
    return nil
end

-- 保存传承数据到文件
-- @param legacy: 传承数据表 { id, category, nameKey, descKey, effect }
function LegacyManager.save(legacy)
    if not legacy then
        -- 清除传承
        love.filesystem.remove(SAVE_PATH)
        return
    end
    local json = LegacyManager._toJSON(legacy)
    local ok, err = love.filesystem.write(SAVE_PATH, json)
    if not ok then
        Log.warn("legacyManager: 写入传承失败 " .. tostring(err))
    else
        Log.info("legacyManager: 传承已保存 → " .. legacy.id)
    end
end

-- 清除传承存档（下局不应用）
function LegacyManager.clear()
    love.filesystem.remove(SAVE_PATH)
    Log.info("legacyManager: 传承存档已清除")
end

-- ============================================================
-- 2. 传承候选池匹配
-- ============================================================

-- 根据本局激活的羁绊，从候选池中随机抽取 3 个传承
-- @param activeSynergies: 本局激活的羁绊列表（来自 bag._activeSynergies）
-- @return 3 个传承数据表（去重）；若池不足则用全类别补充
function LegacyManager.drawCandidates(activeSynergies)
    local pool = LegacyConfig.pool
    local tagMap = LegacyConfig.categoryTagMap

    -- 1. 统计本局激活的羁绊 tags
    local activeTags = {}
    for _, syn in ipairs(activeSynergies or {}) do
        -- syn.tag 是技能羁绊的 tag，syn.nameKey 可回推 tag
        -- 直接从 syn.tag 读取（bagUI/synergy 系统里激活羁绊有 .tag 字段）
        if syn.tag then
            activeTags[syn.tag] = true
        end
    end

    -- 2. 找出命中的大类
    local matchedCategories = {}
    for category, tags in pairs(tagMap) do
        for _, tag in ipairs(tags) do
            if activeTags[tag] then
                matchedCategories[category] = true
                break
            end
        end
    end

    -- 3. 建立候选子集
    local candidates = {}
    local usedIds    = {}   -- 避免同一个传承出现两次

    -- 先加入匹配大类的传承
    for _, entry in ipairs(pool) do
        if matchedCategories[entry.category] and not usedIds[entry.id] then
            table.insert(candidates, entry)
            usedIds[entry.id] = true
        end
    end

    -- 若候选不足 3 个，从全类别补充（不重复）
    if #candidates < 3 then
        for _, entry in ipairs(pool) do
            if not usedIds[entry.id] then
                table.insert(candidates, entry)
                usedIds[entry.id] = true
            end
        end
    end

    -- 4. Fisher-Yates 随机抽取 3 个
    local result = {}
    local copy   = {}
    for _, v in ipairs(candidates) do table.insert(copy, v) end

    for i = 1, math.min(3, #copy) do
        local j = math.random(i, #copy)
        copy[i], copy[j] = copy[j], copy[i]
        table.insert(result, copy[i])
    end

    return result
end

-- ============================================================
-- 3. 下局应用传承效果
-- ============================================================

-- 将已保存的传承效果应用到 player 基础属性
-- 在 Game:enter() 中调用（玩家实体初始化之后）
-- @param player: Player 实例
function LegacyManager.applyToPlayer(player)
    local legacy = LegacyManager.load()
    if not legacy or not legacy.effect then
        return
    end

    local e = legacy.effect
    Log.info("legacyManager: 应用传承 → " .. (legacy.id or "?"))

    -- 攻击力
    if e.attack then
        player.attack = (player.attack or 0) + e.attack
    end
    -- 暴击率
    if e.critRate then
        player.critRate = (player.critRate or 0) + e.critRate
    end
    -- 暴击伤害
    if e.critDamage then
        player.critDamage = (player.critDamage or 1) + e.critDamage
    end
    -- 弹速加成（存入 player._legacyBulletSpeed，game.lua 读取后累加到 mergedPsb.bulletSpeed）
    if e.bulletSpeed then
        player._legacyBulletSpeed = (player._legacyBulletSpeed or 0) + e.bulletSpeed
    end
    -- CD 缩短（存入 player._legacyCdReduce，同上）
    if e.cdReduce then
        player._legacyCdReduce = (player._legacyCdReduce or 0) + e.cdReduce
    end
    -- 武器射速加成倍数（乘数叠加）
    if e.attackSpeed then
        player._legacyAttackSpeed = (player._legacyAttackSpeed or 0) + e.attackSpeed
    end
    -- 最大 HP
    if e.maxHP then
        player.maxHp = (player.maxHp or 100) + e.maxHP
        player.hp    = math.min(player.hp + e.maxHP, player.maxHp)
    end
    -- 防御（直接叠加到 player.defense 基础值）
    if e.defense then
        player.defense = math.min(0.9, (player.defense or 0) + e.defense)
    end
    -- 移速
    if e.speed then
        player.speed = (player.speed or 0) + e.speed
    end
    -- 经验倍率（+20 代表 +20%，存入 player._legacyExpMult）
    if e.expMult then
        player._legacyExpMult = (player._legacyExpMult or 0) + e.expMult
    end
    -- 拾取范围
    if e.pickupRange then
        player.pickupRadius = (player.pickupRadius or 0) + e.pickupRange
    end
    -- 灵魂获取倍率（预留接口，暂存字段）
    if e.soulsMult then
        player._legacySoulsMult = (player._legacySoulsMult or 0) + e.soulsMult
    end

    -- 标记本局已有传承
    player._hasLegacy  = true
    player._legacyData = legacy
end

-- ============================================================
-- 4. 简易 JSON 工具（避免额外依赖）
-- ============================================================

-- 将传承 table 序列化为 JSON 字符串
function LegacyManager._toJSON(t)
    local parts = {}
    table.insert(parts, "{")

    -- id
    table.insert(parts, string.format("  \"id\": \"%s\",", t.id or ""))
    -- category
    table.insert(parts, string.format("  \"category\": \"%s\",", t.category or ""))
    -- nameKey
    table.insert(parts, string.format("  \"nameKey\": \"%s\",", t.nameKey or ""))
    -- descKey
    table.insert(parts, string.format("  \"descKey\": \"%s\",", t.descKey or ""))
    -- effect
    table.insert(parts, "  \"effect\": {")
    local effectParts = {}
    for k, v in pairs(t.effect or {}) do
        table.insert(effectParts, string.format("    \"%s\": %s", k, tostring(v)))
    end
    table.insert(parts, table.concat(effectParts, ",\n"))
    table.insert(parts, "  }")

    table.insert(parts, "}")
    return table.concat(parts, "\n")
end

-- 从 JSON 字符串解析传承 table（轻量实现，仅支持平铺结构）
function LegacyManager._parseJSON(str)
    local result = {}

    -- 解析 id
    result.id       = str:match("\"id\"%s*:%s*\"([^\"]+)\"")
    result.category = str:match("\"category\"%s*:%s*\"([^\"]+)\"")
    result.nameKey  = str:match("\"nameKey\"%s*:%s*\"([^\"]+)\"")
    result.descKey  = str:match("\"descKey\"%s*:%s*\"([^\"]+)\"")

    -- 解析 effect 内各字段（数字）
    result.effect = {}
    local effectBlock = str:match("\"effect\"%s*:%s*{([^}]+)}")
    if effectBlock then
        for k, v in effectBlock:gmatch("\"([^\"]+)\"%s*:%s*([%d%.%-]+)") do
            result.effect[k] = tonumber(v)
        end
    end

    if not result.id then return nil end
    return result
end

return LegacyManager
