--[[
    src/systems/skillManager.lua
    Phase 8 槽位制技能管理系统
    skill1(空格)=dash专属 skill2(Q)/skill3(E)=通用主动 skill4(F)=角色专属
    _passives = 被动列表 最多6个
    add() 返回: true=成功, false=失败, {conflict=}=槽位冲突, {passiveFull=}=被动满
]]

local SkillConfig = require("config.skills")

local SkillManager = {}
SkillManager.__index = SkillManager

-- local MAX_PASSIVES = 6  -- 需求#7：移除被动技能上限

function SkillManager.new()
    local self = setmetatable({}, SkillManager)
    self._slots = { skill1=nil, skill2=nil, skill3=nil, skill4=nil }
    self._passives = {}
    self._globalSlowActive = false
    self._globalSlowRate   = 0
    self._globalSlowTimer  = 0
    self._firedThisFrame   = {}   -- Bug#26：记录本帧触发的技能 id
    self._replacedSkills   = {}   -- Bug#39：被顶替出槽位的技能 id 集合（不再出现在候选池）
    return self
end

local function effectiveCooldown(inst, cdReduce)
    local base = inst.cfg.cooldown or 0
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

local function effectiveInterval(inst)
    local base = inst.cfg.trigger and inst.cfg.trigger.interval or 10
    if inst.cfg.levelBonus and inst.cfg.levelBonus.interval then
        base = math.max(2, base + inst.cfg.levelBonus.interval * (inst.level - 1))
    end
    return base
end

local function effectiveKillCount(inst)
    return inst.cfg.trigger and inst.cfg.trigger.killCount or 5
end

local function effectiveOnhitCd(inst)
    local base = inst.cfg.trigger and inst.cfg.trigger.cd or 10
    if inst.cfg.levelBonus and inst.cfg.levelBonus.cd then
        base = math.max(1, base + inst.cfg.levelBonus.cd * (inst.level - 1))
    end
    return base
end

local function makeInst(skillId, cfg)
    local initCd = 0
    if cfg.type == "active" then
        initCd = cfg.cooldown or 0
    elseif cfg.type == "passive_onhit" then
        initCd = (cfg.trigger and cfg.trigger.cd) or 0
    end
    return { id=skillId, cfg=cfg, level=1, _cdTimer=initCd, _evTimer=0, _evCount=0 }
end

local function resolveSlot(cfg, slots)
    local st = cfg.slotType or "active"
    if st == "dash" then return "skill1"
    elseif st == "exclusive" then return "skill4"
    else
        -- slotType="active"：直接用 cfg.key 定向填充对应槽位
        return cfg.key or "skill2"
    end
end

local function findPassive(passives, skillId)
    for i, inst in ipairs(passives) do
        if inst.id == skillId then return i, inst end
    end
    return nil, nil
end

function SkillManager:add(skillId, player)
    local cfg = SkillConfig[skillId]
    if not cfg then return false end

    if cfg.characterId and player then
        if player.characterId ~= cfg.characterId then return false end
    end

    if cfg.type == "active" and not cfg.slotType then cfg.slotType = "active" end

    if cfg.type == "active" then
        local targetSlot = resolveSlot(cfg, self._slots)
        local existing   = self._slots[targetSlot]

        if existing then
            if existing.id == skillId then
                if existing.level < (cfg.maxLevel or 1) then
                    existing.level = existing.level + 1
                    return true
                else
                    return false
                end
            else
                return { conflict=true, slot=targetSlot, existing=existing.id, incoming=skillId }
            end
        else
            self._slots[targetSlot] = makeInst(skillId, cfg)
            return true
        end
    else
        local idx, existing = findPassive(self._passives, skillId)
        if existing then
            if existing.level < (cfg.maxLevel or 1) then
                existing.level = existing.level + 1
                return true
            else
                return false
            end
        else
            table.insert(self._passives, makeInst(skillId, cfg))
            return true
        end
    end
end

function SkillManager:replaceSlot(slot, skillId)
    local cfg = SkillConfig[skillId]
    if not cfg then return end
    -- Bug#39：记录被顶替的旧技能，防止其重新出现在候选列表
    local old = self._slots[slot]
    if old then self._replacedSkills[old.id] = true end
    self._slots[slot] = makeInst(skillId, cfg)
end

function SkillManager:removePassive(skillId)
    for i, inst in ipairs(self._passives) do
        if inst.id == skillId then
            table.remove(self._passives, i)
            return true
        end
    end
    return false
end

function SkillManager:forceAddPassive(skillId)
    local cfg = SkillConfig[skillId]
    if not cfg then return end
    table.insert(self._passives, makeInst(skillId, cfg))
end

function SkillManager:hasSkill(skillId)
    for _, inst in pairs(self._slots) do
        if inst and inst.id == skillId then return true end
    end
    for _, inst in ipairs(self._passives) do
        if inst.id == skillId then return true end
    end
    return false
end

function SkillManager:getLevel(skillId)
    for _, inst in pairs(self._slots) do
        if inst and inst.id == skillId then return inst.level end
    end
    for _, inst in ipairs(self._passives) do
        if inst.id == skillId then return inst.level end
    end
    return 0
end

function SkillManager:getSlot(slotKey) return self._slots[slotKey] end
function SkillManager:getPassives() return self._passives end

function SkillManager:getPassiveIdList()
    local list = {}
    for _, inst in ipairs(self._passives) do table.insert(list, inst.id) end
    return list
end

function SkillManager:getCooldownRatio(skillId, cdReduce)
    for _, inst in pairs(self._slots) do
        if inst and inst.id == skillId then
            local cd = effectiveCooldown(inst, cdReduce)
            if cd <= 0 then return 1 end
            return math.min(1, inst._cdTimer / cd)
        end
    end
    for _, inst in ipairs(self._passives) do
        if inst.id == skillId then
            if inst.cfg.type == "passive_onhit" then
                local cd = effectiveOnhitCd(inst)
                if cd <= 0 then return 1 end
                return math.min(1, inst._cdTimer / cd)
            elseif inst.cfg.type == "passive_timed" then
                -- Bug#22：定时被动返回充能进度（0=刚触发，1=即将触发）
                local interval = effectiveInterval(inst)
                if interval <= 0 then return 1 end
                return math.min(1, inst._evTimer / interval)
            else
                return 1
            end
        end
    end
    return 0
end

function SkillManager:getAll()
    local all = {}
    for _, inst in pairs(self._slots) do
        if inst then all[inst.id] = inst end
    end
    for _, inst in ipairs(self._passives) do all[inst.id] = inst end
    return all
end

function SkillManager:getSortedList()
    local list = {}
    for _, inst in pairs(self._slots) do
        if inst then table.insert(list, { id=inst.id, inst=inst }) end
    end
    for _, inst in ipairs(self._passives) do
        table.insert(list, { id=inst.id, inst=inst })
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

function SkillManager:tryActivate(slotKey, player, ctx, cdReduce)
    local inst = self._slots[slotKey]
    if not inst then return false end
    if inst.cfg.type ~= "active" then return false end
    local cd = effectiveCooldown(inst, cdReduce)
    if inst._cdTimer >= cd then
        if inst.cfg.effect then inst.cfg.effect(player, inst.level, ctx) end
        inst._cdTimer = 0
        return true
    end
    return false
end

function SkillManager:update(dt, player, ctx, cdReduce)
    self._firedThisFrame = {}   -- 每帧清空
    for _, inst in pairs(self._slots) do
        if inst and inst.cfg.type == "active" then
            inst._cdTimer = inst._cdTimer + dt
        end
    end

    for _, inst in ipairs(self._passives) do
        local cfg = inst.cfg
        if cfg.type == "passive_onhit" then
            inst._cdTimer = inst._cdTimer + dt
        elseif cfg.type == "passive_timed" then
            inst._evTimer = inst._evTimer + dt
            local interval = effectiveInterval(inst)
            if inst._evTimer >= interval then
                inst._evTimer = inst._evTimer - interval
                if cfg.effect then
                    cfg.effect(player, inst.level, ctx)
                    table.insert(self._firedThisFrame, inst.id)   -- Bug#26
                end
            end
        end
    end

    -- Phase 10.1：以下 buff 衰减逻辑已迁移至 BuffManager（player._buffManager:update()）
    -- battle_cry / rage / overload / mana_shield / soul_drain_range
    -- 由 player:update() 中统一调用 BuffManager:update(dt, self) 处理

    for _, e in ipairs(ctx and ctx.enemies or {}) do
        if e._slowTimer and e._slowTimer > 0 then
            e._slowTimer = e._slowTimer - dt
            if e._slowTimer <= 0 then
                e._slowTimer    = 0
                e._slowRestored = true
                if e._baseSpeed then
                    e.speed      = e._baseSpeed
                    e._baseSpeed = nil
                end
            end
        end
    end

    if self._globalSlowTimer > 0 then
        self._globalSlowTimer = self._globalSlowTimer - dt
        if self._globalSlowTimer <= 0 then
            self._globalSlowTimer    = 0
            self._globalSlowActive   = false
            self._globalSlowRate     = 0
            self._globalSlowDuration = 0
        end
    end
end

function SkillManager:onKill(player, enemy, ctx)
    for _, inst in ipairs(self._passives) do
        if inst.cfg.type == "passive_onkill" then
            inst._evCount = inst._evCount + 1
            local threshold = effectiveKillCount(inst)
            if inst._evCount >= threshold then
                inst._evCount = inst._evCount - threshold
                if inst.cfg.effect then
                    inst.cfg.effect(player, inst.level, ctx)
                    table.insert(self._firedThisFrame, inst.id)   -- Bug#26
                end
            end
        end
    end
end

function SkillManager:onHit(player, dmg, ctx)
    for _, inst in ipairs(self._passives) do
        if inst.cfg.type == "passive_onhit" then
            local cd = effectiveOnhitCd(inst)
            if inst._cdTimer >= cd then
                inst._cdTimer = 0
                local hitCtx = ctx and setmetatable({dmg=dmg}, {__index=ctx}) or {dmg=dmg}
                if inst.cfg.effect then
                    inst.cfg.effect(player, inst.level, hitCtx)
                    table.insert(self._firedThisFrame, inst.id)   -- Bug#26
                end
            end
        end
    end
end

function SkillManager:recalcPassive(psb)
    for _, inst in ipairs(self._passives) do
        if inst.cfg.type == "passive" and inst.cfg.passive then
            local passiveDef = inst.cfg.passive
            if passiveDef.key then
                local amount = passiveDef.base + (passiveDef.lvBonus or 0) * (inst.level - 1)
                psb[passiveDef.key] = (psb[passiveDef.key] or 0) + amount
            else
                for _, entry in ipairs(passiveDef) do
                    local amount = entry.base + (entry.lvBonus or 0) * (inst.level - 1)
                    psb[entry.key] = (psb[entry.key] or 0) + amount
                end
            end
        end
    end
end

function SkillManager:getTagCounts()
    local counts = {}
    for _, inst in pairs(self._slots) do
        if inst and inst.cfg.tag then
            counts[inst.cfg.tag] = (counts[inst.cfg.tag] or 0) + 1
        end
    end
    for _, inst in ipairs(self._passives) do
        if inst.cfg.tag then
            counts[inst.cfg.tag] = (counts[inst.cfg.tag] or 0) + 1
        end
    end
    return counts
end

function SkillManager:setGlobalSlow(rate, duration)
    self._globalSlowActive = true
    self._globalSlowRate   = rate
    local newTimer = math.max(self._globalSlowTimer, duration)
    -- Bug#38：记录最大时长供 HUD 倒计时进度条使用
    if newTimer > (self._globalSlowTimer or 0) then
        self._globalSlowDuration = newTimer
    end
    self._globalSlowTimer  = newTimer
end

function SkillManager:getGlobalSlow()
    if self._globalSlowActive then return self._globalSlowRate or 0 end
    return 0
end

return SkillManager
