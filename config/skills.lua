--[[
    config/skills.lua
    技能配置表 — Phase 8
    共 20 个技能（含1个角色专属）：
        6 个主动（active）
        8 个事件被动（passive_timed / passive_onkill / passive_onhit）
        5 个纯被动（passive）
        1 个角色专属主动（overload，default 角色）

    effect 函数签名：
        active / passive_onhit      → function(player, level, ctx)
        passive_timed / passive_onkill → function(player, level, ctx)
        passive（纯被动）           → 通过 passive 字段写到 psb，不用 effect

    ctx 字段（game.lua 传入）：
        dx, dy   — 玩家当前移动方向（归一化）
        enemies  — 当前敌人列表
        bag      — 玩家背包实例
        projectiles — 当前投射物列表（可追加）

    passive 字段说明（纯被动写法）：
        key  — psb 字段名（如 "maxHP"、"speed"、"critChance" 等）
        base — Lv1 时的加成量
        lvBonus — 每升级额外增量（可选，默认 0）
]]

-- 工具函数：获取离玩家最近的敌人
local function findNearest(player, enemies)
    local nearest, minDist = nil, math.huge
    for _, e in ipairs(enemies or {}) do
        if not e._isDead then
            local dx = e.x - player.x
            local dy = e.y - player.y
            local d  = math.sqrt(dx*dx + dy*dy)
            if d < minDist then
                minDist = d
                nearest = e
            end
        end
    end
    return nearest, minDist
end

-- 工具函数：对圆形范围内所有敌人造成伤害
local function aoeHarm(player, enemies, radius, damage)
    local hit = 0
    for _, e in ipairs(enemies or {}) do
        if not e._isDead then
            local dx = e.x - player.x
            local dy = e.y - player.y
            local d  = math.sqrt(dx*dx + dy*dy)
            if d <= radius then
                e:takeDamage(damage)
                hit = hit + 1
            end
        end
    end
    return hit
end

-- 工具函数：减速圆形范围内所有敌人（持续 duration 秒）
local function aoeSlowEnemies(player, enemies, radius, slowRate, duration)
    for _, e in ipairs(enemies or {}) do
        if not e._isDead then
            local dx = e.x - player.x
            local dy = e.y - player.y
            local d  = math.sqrt(dx*dx + dy*dy)
            if radius == nil or d <= radius then
                -- 记录原速度（防止重复叠加）
                if not e._baseSpeed then e._baseSpeed = e.speed end
                e.speed = e._baseSpeed * (1 - slowRate)
                -- 设置恢复计时
                e._slowTimer    = duration
                e._slowRestored = false
            end
        end
    end
end

-- ============================================================
-- 主配置表
-- ============================================================
local SkillConfig = {}

-- ---- A. 主动技能 ----

SkillConfig["dash"] = {
    type        = "active",
    key         = "skill1",    -- 空格
    cooldown    = 8,
    nameKey     = "skill.dash.name",
    descKey     = "skill.dash.desc",
    maxLevel    = 3,
    levelBonus  = { distance = 50, cooldown = -0.5 },
    tag         = "爆发",
    characterId = nil,
    effect = function(player, level, ctx)
        local dist = 200 + (level - 1) * 50
        local dx   = ctx and ctx.dx or 0
        local dy   = ctx and ctx.dy or 0
        -- 若无移动方向则向右冲
        if dx == 0 and dy == 0 then dx = 1 end
        player.x = player.x + dx * dist
        player.y = player.y + dy * dist
    end,
}

SkillConfig["time_slow"] = {
    type        = "active",
    key         = "skill2",    -- Q
    cooldown    = 20,
    nameKey     = "skill.time_slow.name",
    descKey     = "skill.time_slow.desc",
    maxLevel    = 3,
    levelBonus  = { duration = 1, cooldown = -1 },
    tag         = "辅助",
    characterId = nil,
    effect = function(player, level, ctx)
        local duration = 3 + (level - 1) * 1
        aoeSlowEnemies(player, ctx and ctx.enemies, nil, 0.8, duration)
    end,
}

SkillConfig["bomb_throw"] = {
    type        = "active",
    key         = "skill3",    -- E
    cooldown    = 12,
    nameKey     = "skill.bomb_throw.name",
    descKey     = "skill.bomb_throw.desc",
    maxLevel    = 3,
    levelBonus  = { damage = 30, radius = 20 },
    tag         = "爆发",
    characterId = nil,
    effect = function(player, level, ctx)
        local radius = 150 + (level - 1) * 20
        local damage = 80  + (level - 1) * 30
        -- 爆炸点在玩家前方 200px
        local dx = ctx and ctx.dx or 0
        local dy = ctx and ctx.dy or 1
        if dx == 0 and dy == 0 then dy = 1 end
        local cx = player.x + dx * 200
        local cy = player.y + dy * 200
        for _, e in ipairs(ctx and ctx.enemies or {}) do
            if not e._isDead then
                local ex = e.x - cx
                local ey = e.y - cy
                if math.sqrt(ex*ex + ey*ey) <= radius then
                    e:takeDamage(damage)
                end
            end
        end
    end,
}

SkillConfig["blink"] = {
    type        = "active",
    key         = "skill2",    -- Q（与 time_slow 共享按键，后加的替换）
    cooldown    = 15,
    nameKey     = "skill.blink.name",
    descKey     = "skill.blink.desc",
    maxLevel    = 3,
    levelBonus  = { damage = 20, cooldown = -1 },
    tag         = "爆发",
    characterId = nil,
    effect = function(player, level, ctx)
        local damage = 40 + (level - 1) * 20
        local nearest = findNearest(player, ctx and ctx.enemies)
        if nearest then
            -- 瞬移到敌人背后 80px
            local dx = player.x - nearest.x
            local dy = player.y - nearest.y
            local d  = math.sqrt(dx*dx + dy*dy)
            if d < 1 then dx, dy, d = 1, 0, 1 end
            player.x = nearest.x + (dx/d) * (-80)
            player.y = nearest.y + (dy/d) * (-80)
            -- 残影伤害
            nearest:takeDamage(damage)
        end
    end,
}

SkillConfig["battle_cry"] = {
    type        = "active",
    key         = "skill4",    -- F
    cooldown    = 25,
    nameKey     = "skill.battle_cry.name",
    descKey     = "skill.battle_cry.desc",
    maxLevel    = 3,
    levelBonus  = { duration = 2, cooldown = -2 },
    tag         = "爆发",
    characterId = nil,
    effect = function(player, level, ctx)
        local duration = 10 + (level - 1) * 2
        -- 添加临时 attack 倍率 buff（用 _battleCryTimer 跟踪）
        if not player._battleCryActive then
            player.attack = player.attack * 2
            player._battleCryActive = true
        end
        player._battleCryTimer = duration
        -- 附近敌人停滞 0.5s
        aoeSlowEnemies(player, ctx and ctx.enemies, 300, 1.0, 0.5)
    end,
}

SkillConfig["mana_shield"] = {
    type        = "active",
    key         = "skill4",    -- F（与 battle_cry 共享槽位）
    cooldown    = 18,
    nameKey     = "skill.mana_shield.name",
    descKey     = "skill.mana_shield.desc",
    maxLevel    = 3,
    levelBonus  = { duration = 2, cooldown = -2 },
    tag         = "防御",
    characterId = nil,
    effect = function(player, level, ctx)
        local duration = 8 + (level - 1) * 2
        player._shieldActive   = true
        player._shieldTimer    = duration
        player._shieldAbsorbed = false  -- 尚未吸收伤害
    end,
}

-- ---- B. 事件被动 — 定时类 ----

SkillConfig["emp_burst"] = {
    type        = "passive_timed",
    trigger     = { interval = 12 },
    nameKey     = "skill.emp_burst.name",
    descKey     = "skill.emp_burst.desc",
    maxLevel    = 3,
    levelBonus  = { slowDuration = 1, interval = -2 },
    tag         = "辅助",
    characterId = nil,
    effect = function(player, level, ctx)
        local slowDur = 3 + (level - 1) * 1
        aoeSlowEnemies(player, ctx and ctx.enemies, nil, 0.5, slowDur)
    end,
}

SkillConfig["heal_pulse"] = {
    type        = "passive_timed",
    trigger     = { interval = 15 },
    nameKey     = "skill.heal_pulse.name",
    descKey     = "skill.heal_pulse.desc",
    maxLevel    = 3,
    levelBonus  = { healBonus = 5, interval = -2 },
    tag         = "防御",
    characterId = nil,
    effect = function(player, level, ctx)
        local base  = 8 + (level - 1) * 5
        local byPct = math.floor(player.maxHp * 0.05)
        player:heal(math.max(base, byPct))
    end,
}

SkillConfig["ammo_supply"] = {
    type        = "passive_timed",
    trigger     = { interval = 10 },
    nameKey     = "skill.ammo_supply.name",
    descKey     = "skill.ammo_supply.desc",
    maxLevel    = 3,
    levelBonus  = { stacks = 1, interval = -1 },
    tag         = "精准",
    characterId = nil,
    effect = function(player, level, ctx)
        -- 给玩家标记一次弹药强化（下次子弹伤害×2）
        player._ammoSupplyStacks = (player._ammoSupplyStacks or 0) + (1 + (level-1))
    end,
}

-- ---- B. 事件被动 — 击杀类 ----

SkillConfig["explosion"] = {
    type        = "passive_onkill",
    trigger     = { killCount = 5 },
    nameKey     = "skill.explosion.name",
    descKey     = "skill.explosion.desc",
    maxLevel    = 3,
    levelBonus  = { damage = 20, radius = 20 },
    tag         = "爆发",
    characterId = nil,
    effect = function(player, level, ctx)
        local radius = 150 + (level - 1) * 20
        local damage = 60  + (level - 1) * 20
        aoeHarm(player, ctx and ctx.enemies, radius, damage)
    end,
}

SkillConfig["soul_drain"] = {
    type        = "passive_onkill",
    trigger     = { killCount = 3 },
    nameKey     = "skill.soul_drain.name",
    descKey     = "skill.soul_drain.desc",
    maxLevel    = 3,
    levelBonus  = { heal = 3, rangeBonus = 20 },
    tag         = "辅助",
    characterId = nil,
    effect = function(player, level, ctx)
        local heal      = 5  + (level - 1) * 3
        local rangeBon  = 50 + (level - 1) * 20
        player:heal(heal)
        -- 临时扩大拾取范围 3s
        player._soulDrainRange      = (player._soulDrainRange or 0) + rangeBon
        player.pickupRadius         = player.pickupRadius + rangeBon
        player._soulDrainTimer      = 3
    end,
}

-- ---- B. 事件被动 — 受伤类 ----

SkillConfig["counter_shot"] = {
    type        = "passive_onhit",
    trigger     = { cd = 10 },   -- 独立冷却
    nameKey     = "skill.counter_shot.name",
    descKey     = "skill.counter_shot.desc",
    maxLevel    = 3,
    levelBonus  = { damage = 15, bullets = 1 },
    tag         = "爆发",
    characterId = nil,
    effect = function(player, level, ctx)
        local damage  = 30 + (level - 1) * 15
        local bullets = 3  + (level - 1) * 1
        local MathUtils = require("src.utils.math")
        local Projectile = require("src.entities.projectile")
        local nearest = findNearest(player, ctx and ctx.enemies)
        if nearest then
            for i = 1, bullets do
                -- 小角度扇形散射
                local angle = math.atan2(nearest.y - player.y, nearest.x - player.x)
                local spread = (i - math.ceil(bullets/2)) * 0.15
                local pdx = math.cos(angle + spread)
                local pdy = math.sin(angle + spread)
                local proj = Projectile.new(player.x, player.y, pdx, pdy, damage, 500)
                if ctx and ctx.projectiles then
                    table.insert(ctx.projectiles, proj)
                end
            end
        end
    end,
}

SkillConfig["rage"] = {
    type        = "passive_onhit",
    trigger     = { cd = 20 },
    nameKey     = "skill.rage.name",
    descKey     = "skill.rage.desc",
    maxLevel    = 3,
    levelBonus  = { atkBonus = 15, duration = 2 },
    tag         = "爆发",
    characterId = nil,
    effect = function(player, level, ctx)
        local atkBonus = 50 + (level - 1) * 15
        local duration = 5  + (level - 1) * 2
        if not player._rageActive then
            player.attack = player.attack + atkBonus
            player._rageActive  = true
            player._rageBonus   = atkBonus
        end
        player._rageTimer = duration
    end,
}

SkillConfig["thorns"] = {
    type        = "passive_onhit",
    trigger     = { cd = 8 },
    nameKey     = "skill.thorns.name",
    descKey     = "skill.thorns.desc",
    maxLevel    = 3,
    levelBonus  = { reflectRate = 0.1, cd = -1 },
    tag         = "防御",
    characterId = nil,
    -- effect 在 game.lua onHit 回调中特殊处理：ctx.dmg * reflectRate 反弹给攻击者
    effect = function(player, level, ctx)
        local reflectRate = 0.5 + (level - 1) * 0.1
        if ctx and ctx.dmg and ctx.attacker then
            local reflected = math.floor(ctx.dmg * reflectRate)
            if reflected > 0 then
                ctx.attacker:takeDamage(reflected)
            end
        end
    end,
}

-- ---- C. 纯被动技能 ----

SkillConfig["iron_body"] = {
    type        = "passive",
    nameKey     = "skill.iron_body.name",
    descKey     = "skill.iron_body.desc",
    maxLevel    = 3,
    levelBonus  = { maxHP = 25 },
    tag         = "防御",
    characterId = nil,
    passive     = { key = "maxHP", base = 50, lvBonus = 25 },
}

SkillConfig["swift_feet"] = {
    type        = "passive",
    nameKey     = "skill.swift_feet.name",
    descKey     = "skill.swift_feet.desc",
    maxLevel    = 3,
    levelBonus  = { speed = 15 },
    tag         = "爆发",
    characterId = nil,
    passive     = { key = "speed", base = 40, lvBonus = 15 },
}

SkillConfig["sharpshooter"] = {
    type        = "passive",
    nameKey     = "skill.sharpshooter.name",
    descKey     = "skill.sharpshooter.desc",
    maxLevel    = 3,
    levelBonus  = { critChance = 4, critMult = 10 },
    tag         = "精准",
    characterId = nil,
    passive     = {
        { key = "critChance", base = 10, lvBonus = 4 },
        { key = "critMult",   base = 30, lvBonus = 10 },
    },
}

SkillConfig["energy_field"] = {
    type        = "passive",
    nameKey     = "skill.energy_field.name",
    descKey     = "skill.energy_field.desc",
    maxLevel    = 3,
    levelBonus  = { pickupRange = 30, expMult = 10 },
    tag         = "辅助",
    characterId = nil,
    passive     = {
        { key = "pickupRange", base = 80,  lvBonus = 30 },
        { key = "expMult",     base = 20,  lvBonus = 10 },
    },
}

SkillConfig["iron_will"] = {
    type        = "passive",
    nameKey     = "skill.iron_will.name",
    descKey     = "skill.iron_will.desc",
    maxLevel    = 3,
    levelBonus  = { defense = 4 },
    tag         = "防御",
    characterId = nil,
    passive     = { key = "defense", base = 10, lvBonus = 4 },
}

-- ---- D. 角色专属技能 ----

SkillConfig["overload"] = {
    type        = "active",
    key         = "skill1",    -- 空格（备选槽）
    cooldown    = 30,
    nameKey     = "skill.overload.name",
    descKey     = "skill.overload.desc",
    maxLevel    = 3,
    levelBonus  = { duration = 1, cooldown = -3 },
    tag         = "爆发",
    characterId = "default",   -- 仅 default 角色可获得
    effect = function(player, level, ctx)
        local duration = 4 + (level - 1) * 1
        local bag = ctx and ctx.bag or (player._bag)
        if bag then
            local weapons = bag:getAllWeapons()
            for _, w in ipairs(weapons) do
                -- 临时将 attackSpeed 翻倍
                if not w._overloadOrig then
                    w._overloadOrig = w.attackSpeed
                    w.attackSpeed   = w.attackSpeed * 2
                end
            end
        end
        player._overloadTimer = duration
        player._overloadBag   = bag
    end,
}

return SkillConfig
