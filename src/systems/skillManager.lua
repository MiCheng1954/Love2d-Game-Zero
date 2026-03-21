--[[
    src/systems/skillManager.lua
    技能管理系统 — Phase 8

    负责：
        - 存储玩家当前持有的所有技能实例（含等级、冷却计时器）
        - tryActivate()   — 玩家按键时，检查 CD 并触发主动技能
        - update()        — 推进定时类被动技能计时器，到期自动触发
        - onKill()        — 通知击杀计数类被动技能
        - onHit()         — 通知受伤触发类被动技能
        - recalcPassive() — 将纯被动技能的加成累加到 psb
        - 对外查询接口：hasSkill / getLevel / getCooldownRatio / getAll

    运行时实例结构：
        {
            cfg       = SkillConfig["dash"],  -- 配置引用
            level     = 1,
            _cdTimer  = 0,   -- 当前已冷却时间（主动 / passive_onhit 用）
            _evTimer  = 0,   -- 事件计时（passive_timed 用）
            _evCount  = 0,   -- 事件计数（passive_onkill 用）
            _active   = false,   -- 是否在持续效果中（预留，battle_cry 等通过 player 字段管理）
        }
]]

local SkillConfig = require("config.skills")

local SkillManager = {}
SkillManager.__index = SkillManager

-- 创建新的 SkillManager 实例
function SkillManager.new()
    local self = setmetatable({}, SkillManager)
    self._skills = {}   -- key = skillId, value = 实例表
    return self
end

-- ============================================================
-- 内部工具
-- ============================================================

-- 获取技能实际冷却时间（考虑 cdReduce 羁绊加成）
-- @param inst     实例
-- @param cdReduce psb.cdReduce（0~1，越大 CD 越短）
local function effectiveCooldown(inst, cdReduce)
    local base = inst.cfg.cooldown or 0
    -- levelBonus.cooldown 为负数表示减少
    local lvBonus = 0
    if inst.cfg.levelBonus and inst.cfg.levelBonus.cooldown then
        lvBonus = inst.cfg.levelBonus.cooldown * (inst.level - 1)
    end
    local cd = math.max(0.5, base + lvBonus)
    if cdReduce and cdReduce > 0 then
        cd = cd * (1 - math.min(0.9, cdReduce))
    end
    return cd
end

-- 获取事件被动的触发间隔（考虑等级加成）
local function effectiveInterval(inst)
    local base = inst.cfg.trigger and inst.cfg.trigger.interval or 10
    -- levelBonus 里可以包含 interval 减少
    if inst.cfg.levelBonus and inst.cfg.levelBonus.interval then
        base = math.max(2, base + inst.cfg.levelBonus.interval * (inst.level - 1))
    end
    return base
end

-- 获取 passive_onkill 的击杀阈值
local function effectiveKillCount(inst)
    return inst.cfg.trigger and inst.cfg.trigger.killCount or 5
end

-- 获取 passive_onhit 的独立冷却
local function effectiveOnhitCd(inst)
    local base = inst.cfg.trigger and inst.cfg.trigger.cd or 10
    if inst.cfg.levelBonus and inst.cfg.levelBonus.cd then
        base = math.max(1, base + inst.cfg.levelBonus.cd * (inst.level - 1))
    end
    return base
end

-- ============================================================
-- 公共 API
-- ============================================================

-- 添加技能（不存在则 Lv1 获得，已有则升级；满级不变）
-- @param skillId  技能 id（如 "dash"）
-- @param player   玩家实例（用于 characterId 检查）
-- @return true/false 是否成功
function SkillManager:add(skillId, player)
    local cfg = SkillConfig[skillId]
    if not cfg then return false end

    -- 角色专属检查
    if cfg.characterId and player then
        if player.characterId ~= cfg.characterId then
            return false
        end
    end

    local inst = self._skills[skillId]
    if inst then
        -- 已有，尝试升级
        if inst.level < cfg.maxLevel then
            inst.level = inst.level + 1
            return true
        else
            return false  -- 已满级
        end
    else
        -- 新增
        -- 初始 cdTimer：主动技能 = cooldown（立即就绪）
        --               passive_onhit = trigger.cd（立即就绪）
        --               其他类型 = 0
        local initCd = 0
        if cfg.type == "active" then
            initCd = cfg.cooldown or 0
        elseif cfg.type == "passive_onhit" then
            initCd = (cfg.trigger and cfg.trigger.cd) or 0
        end
        self._skills[skillId] = {
            cfg      = cfg,
            level    = 1,
            _cdTimer = initCd,
            _evTimer = 0,
            _evCount = 0,
        }
        return true
    end
end

-- 是否拥有某技能
function SkillManager:hasSkill(skillId)
    return self._skills[skillId] ~= nil
end

-- 获取技能等级（未拥有返回 0）
function SkillManager:getLevel(skillId)
    local inst = self._skills[skillId]
    return inst and inst.level or 0
end

-- 获取冷却进度比（0=冷却中，1=就绪）—— 仅对主动/passive_onhit 有意义
-- @param cdReduce 冷却缩减比（来自 psb）
function SkillManager:getCooldownRatio(skillId, cdReduce)
    local inst = self._skills[skillId]
    if not inst then return 0 end
    local cfg = inst.cfg
    if cfg.type ~= "active" and cfg.type ~= "passive_onhit" then return 1 end
    local cd = effectiveCooldown(inst, cdReduce)
    if cd <= 0 then return 1 end
    return math.min(1, inst._cdTimer / cd)
end

-- 返回全部实例表（供 draw/debug 遍历）
function SkillManager:getAll()
    return self._skills
end

-- 返回按 id 排序的有序技能列表（供 HUD 稳定渲染）
function SkillManager:getSortedList()
    local list = {}
    for id, inst in pairs(self._skills) do
        table.insert(list, { id = id, inst = inst })
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

-- 尝试激活主动技能
-- @param slotKey  "skill1" / "skill2" / "skill3" / "skill4"
-- @param player   玩家实例
-- @param ctx      上下文（dx, dy, enemies, bag, projectiles）
-- @param cdReduce 冷却缩减比
-- @return 是否触发了技能
function SkillManager:tryActivate(slotKey, player, ctx, cdReduce)
    local triggered = false
    for _, inst in pairs(self._skills) do
        local cfg = inst.cfg
        if cfg.type == "active" and cfg.key == slotKey then
            local cd = effectiveCooldown(inst, cdReduce)
            if inst._cdTimer >= cd then
                -- 触发效果
                if cfg.effect then
                    cfg.effect(player, inst.level, ctx)
                end
                inst._cdTimer = 0  -- 重置冷却
                triggered = true
            end
            -- 同一槽位只触发第一个就绪的技能
            if triggered then break end
        end
    end
    return triggered
end

-- 每帧更新（推进 cdTimer / 触发 passive_timed）
-- @param dt       帧时间
-- @param player   玩家实例
-- @param ctx      上下文
-- @param cdReduce 冷却缩减比
function SkillManager:update(dt, player, ctx, cdReduce)
    for _, inst in pairs(self._skills) do
        local cfg = inst.cfg

        -- 更新持续效果（battle_cry / rage / overload 等通过 player 字段管理）
        -- 此处只负责统一推进 CD 计时器
        if cfg.type == "active" or cfg.type == "passive_onhit" then
            inst._cdTimer = inst._cdTimer + dt

        elseif cfg.type == "passive_timed" then
            inst._evTimer = inst._evTimer + dt
            local interval = effectiveInterval(inst)
            if inst._evTimer >= interval then
                inst._evTimer = inst._evTimer - interval
                if cfg.effect then
                    cfg.effect(player, inst.level, ctx)
                end
            end
        end
    end

    -- 更新 player 级别的持续 buff（battle_cry / rage / overload 等）
    if player._battleCryTimer and player._battleCryTimer > 0 then
        player._battleCryTimer = player._battleCryTimer - dt
        if player._battleCryTimer <= 0 then
            player._battleCryTimer = 0
            if player._battleCryActive then
                player.attack = player.attack / 2
                player._battleCryActive = false
            end
        end
    end

    if player._rageTimer and player._rageTimer > 0 then
        player._rageTimer = player._rageTimer - dt
        if player._rageTimer <= 0 then
            player._rageTimer = 0
            if player._rageActive then
                player.attack = player.attack - (player._rageBonus or 0)
                player._rageActive = false
                player._rageBonus  = 0
            end
        end
    end

    if player._overloadTimer and player._overloadTimer > 0 then
        player._overloadTimer = player._overloadTimer - dt
        if player._overloadTimer <= 0 then
            player._overloadTimer = 0
            -- 恢复武器攻速
            local bag = player._overloadBag or player._bag
            if bag then
                for _, w in ipairs(bag:getAllWeapons()) do
                    if w._overloadOrig then
                        w.attackSpeed   = w._overloadOrig
                        w._overloadOrig = nil
                    end
                end
            end
            player._overloadBag = nil
        end
    end

    -- 魔法护罩计时
    if player._shieldTimer and player._shieldTimer > 0 then
        player._shieldTimer = player._shieldTimer - dt
        if player._shieldTimer <= 0 then
            player._shieldActive   = false
            player._shieldTimer    = 0
            player._shieldAbsorbed = false
        end
    end

    -- 灵魂汲取范围临时加成计时
    if player._soulDrainTimer and player._soulDrainTimer > 0 then
        player._soulDrainTimer = player._soulDrainTimer - dt
        if player._soulDrainTimer <= 0 then
            player._soulDrainTimer = 0
            if player._soulDrainRange and player._soulDrainRange > 0 then
                player.pickupRadius  = player.pickupRadius - player._soulDrainRange
                player._soulDrainRange = 0
            end
        end
    end

    -- 敌人减速恢复（遍历所有敌人，清理 _slowTimer）
    for _, e in ipairs(ctx and ctx.enemies or {}) do
        if e._slowTimer and e._slowTimer > 0 then
            e._slowTimer = e._slowTimer - dt
            if e._slowTimer <= 0 then
                e._slowTimer    = 0
                e._slowRestored = true
                if e._baseSpeed then
                    e.speed     = e._baseSpeed
                    e._baseSpeed = nil
                end
            end
        end
    end
end

-- 通知击杀事件
-- @param player  玩家实例
-- @param enemy   被击杀的敌人（可为 nil）
-- @param ctx     上下文
function SkillManager:onKill(player, enemy, ctx)
    for _, inst in pairs(self._skills) do
        if inst.cfg.type == "passive_onkill" then
            inst._evCount = inst._evCount + 1
            local threshold = effectiveKillCount(inst)
            if inst._evCount >= threshold then
                inst._evCount = inst._evCount - threshold
                if inst.cfg.effect then
                    inst.cfg.effect(player, inst.level, ctx)
                end
            end
        end
    end
end

-- 通知受伤事件
-- @param player   玩家实例
-- @param dmg      实际受到的伤害量
-- @param ctx      上下文（可含 attacker 字段）
function SkillManager:onHit(player, dmg, ctx)
    for _, inst in pairs(self._skills) do
        if inst.cfg.type == "passive_onhit" then
            local cd = effectiveOnhitCd(inst)
            if inst._cdTimer >= cd then
                inst._cdTimer = 0
                local hitCtx = ctx and setmetatable({dmg = dmg}, {__index = ctx}) or {dmg = dmg}
                if inst.cfg.effect then
                    inst.cfg.effect(player, inst.level, hitCtx)
                end
            end
        end
    end
end

-- 将纯被动技能的加成累加到 psb
-- @param psb  playerSynergyBonus 表（直接修改）
function SkillManager:recalcPassive(psb)
    for _, inst in pairs(self._skills) do
        if inst.cfg.type == "passive" and inst.cfg.passive then
            local passiveDef = inst.cfg.passive
            -- 支持单条和多条写法
            if passiveDef.key then
                -- 单条
                local amount = passiveDef.base + (passiveDef.lvBonus or 0) * (inst.level - 1)
                psb[passiveDef.key] = (psb[passiveDef.key] or 0) + amount
            else
                -- 多条（数组形式）
                for _, entry in ipairs(passiveDef) do
                    local amount = entry.base + (entry.lvBonus or 0) * (inst.level - 1)
                    psb[entry.key] = (psb[entry.key] or 0) + amount
                end
            end
        end
    end
end

-- 统计技能 Tag 计数（供 SkillSynergy 使用）
-- @return table: { tag = count, ... }
function SkillManager:getTagCounts()
    local counts = {}
    for _, inst in pairs(self._skills) do
        local tag = inst.cfg.tag
        if tag then
            counts[tag] = (counts[tag] or 0) + 1
        end
    end
    return counts
end

return SkillManager
