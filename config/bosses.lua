--[[
    config/bosses.lua
    Boss 配置表 — Phase 9
    共 4 个 Boss，按局内时间触发：4/8/12/18 分钟

    每个 Boss 含：
      phase        — 触发时间（分钟）
      nameKey      — i18n 名称 key
      hp/attack/speed/radius/color — 基础属性
      expDrop/soulDrop             — 死亡掉落
      isFinal      — 是否为最终 Boss（击败后触发胜利）
      skills       — 技能列表，每项 { interval, effect(boss, player, projectiles) }
]]

local BossConfig = {}

-- ── Boss 1：碎骨者（4分钟）──
-- 近战型，会周期性冲向玩家造成大范围伤害
BossConfig[1] = {
    id          = "crusher",
    phase       = 4,
    nameKey     = "boss.crusher.name",
    hp          = 600,
    attack      = 30,
    defense     = 5,
    speed       = 90,
    radius      = 28,
    color       = {0.85, 0.15, 0.15},   -- 深红
    expDrop     = 200,
    soulDrop    = 30,
    isFinal     = false,
    skills = {
        -- 技能1：冲刺（每5秒向玩家冲刺，速度×5持续0.4秒）
        {
            id       = "charge",
            interval = 5.0,
            effect   = function(boss, player, projectiles)
                if not player or not boss._target then return end
                local dx = boss._target.x - boss.x
                local dy = boss._target.y - boss.y
                local d  = math.sqrt(dx*dx + dy*dy)
                if d < 1 then return end
                boss._chargeDx    = dx / d
                boss._chargeDy    = dy / d
                boss._chargeTimer = 0.4   -- 冲刺持续时间
                boss._chargeSpeed = boss.speed * 5
            end,
        },
        -- 技能2：震地（每8秒，对玩家120px内造成伤害）
        {
            id       = "stomp",
            interval = 8.0,
            effect   = function(boss, player, projectiles)
                if not player then return end
                local dx = player.x - boss.x
                local dy = player.y - boss.y
                if math.sqrt(dx*dx + dy*dy) <= 120 then
                    player:takeDamage(25)
                end
                boss._stompFlash = 0.3   -- 视觉闪光计时
            end,
        },
    },
}

-- ── Boss 2：幽灵法师（8分钟）──
-- 远程型，持续向玩家发射多方向弹幕
BossConfig[2] = {
    id          = "phantom",
    phase       = 8,
    nameKey     = "boss.phantom.name",
    hp          = 1000,
    attack      = 20,
    defense     = 0,
    speed       = 55,
    radius      = 24,
    color       = {0.4, 0.2, 0.9},      -- 深紫
    expDrop     = 350,
    soulDrop    = 50,
    isFinal     = false,
    skills = {
        -- 技能1：3方向弹幕（每3秒）
        {
            id       = "tri_shot",
            interval = 3.0,
            effect   = function(boss, player, projectiles)
                if not player or not projectiles then return end
                local Projectile = require("src.entities.projectile")
                local dx = player.x - boss.x
                local dy = player.y - boss.y
                local d  = math.sqrt(dx*dx + dy*dy)
                if d < 1 then return end
                local bx, by = dx/d, dy/d
                local angles = { -0.35, 0, 0.35 }
                for _, a in ipairs(angles) do
                    local ca, sa = math.cos(a), math.sin(a)
                    local fx = bx*ca - by*sa
                    local fy = bx*sa + by*ca
                    local p  = Projectile.new(boss.x, boss.y, fx, fy, 18, 220)
                    p._isEnemyProjectile = true
                    p._damage = 18
                    table.insert(projectiles, p)
                end
            end,
        },
        -- 技能2：360°散射（每10秒，8颗子弹）
        {
            id       = "nova",
            interval = 10.0,
            effect   = function(boss, player, projectiles)
                if not projectiles then return end
                local Projectile = require("src.entities.projectile")
                for i = 0, 7 do
                    local a  = (i / 8) * math.pi * 2
                    local p  = Projectile.new(boss.x, boss.y,
                        math.cos(a), math.sin(a), 22, 180)
                    p._isEnemyProjectile = true
                    p._damage = 22
                    table.insert(projectiles, p)
                end
            end,
        },
    },
}

-- ── Boss 3：钢铁巨兽（12分钟）──
-- 高防坦克型，会召唤小兵
BossConfig[3] = {
    id          = "colossus",
    phase       = 12,
    nameKey     = "boss.colossus.name",
    hp          = 2000,
    attack      = 40,
    defense     = 15,
    speed       = 40,
    radius      = 36,
    color       = {0.4, 0.5, 0.55},     -- 钢铁灰
    expDrop     = 600,
    soulDrop    = 80,
    isFinal     = false,
    skills = {
        -- 技能1：重拳（每4秒，玩家80px内造成大量伤害）
        {
            id       = "heavy_punch",
            interval = 4.0,
            effect   = function(boss, player, projectiles)
                if not player then return end
                local dx = player.x - boss.x
                local dy = player.y - boss.y
                if math.sqrt(dx*dx + dy*dy) <= 80 then
                    player:takeDamage(35)
                end
                boss._punchFlash = 0.25
            end,
        },
        -- 技能2：召唤（每15秒，标记召唤2只 basic 敌人，由 game.lua 处理生成）
        {
            id       = "summon",
            interval = 15.0,
            effect   = function(boss, player, projectiles)
                boss._summonPending = (boss._summonPending or 0) + 2
            end,
        },
        -- 技能3：横扫弹幕（每6秒，5颗扇形弹）
        {
            id       = "sweep",
            interval = 6.0,
            effect   = function(boss, player, projectiles)
                if not player or not projectiles then return end
                local Projectile = require("src.entities.projectile")
                local dx = player.x - boss.x
                local dy = player.y - boss.y
                local d  = math.sqrt(dx*dx + dy*dy)
                if d < 1 then return end
                local bx, by = dx/d, dy/d
                local spread = { -0.5, -0.25, 0, 0.25, 0.5 }
                for _, a in ipairs(spread) do
                    local ca, sa = math.cos(a), math.sin(a)
                    local fx = bx*ca - by*sa
                    local fy = bx*sa + by*ca
                    local p  = Projectile.new(boss.x, boss.y, fx, fy, 28, 250)
                    p._isEnemyProjectile = true
                    p._damage = 28
                    table.insert(projectiles, p)
                end
            end,
        },
    },
}

-- ── Boss 4：虚空领主（18分钟，最终Boss）──
-- 综合型，集合前三Boss的技能并强化
BossConfig[4] = {
    id          = "void_lord",
    phase       = 18,
    nameKey     = "boss.void_lord.name",
    hp          = 4000,
    attack      = 50,
    defense     = 10,
    speed       = 70,
    radius      = 32,
    color       = {0.15, 0.85, 0.7},    -- 暗青绿
    expDrop     = 1000,
    soulDrop    = 150,
    isFinal     = true,                 -- 击败即胜利
    skills = {
        -- 技能1：冲刺（同 Boss1，CD缩短）
        {
            id       = "charge",
            interval = 4.0,
            effect   = function(boss, player, projectiles)
                if not player or not boss._target then return end
                local dx = boss._target.x - boss.x
                local dy = boss._target.y - boss.y
                local d  = math.sqrt(dx*dx + dy*dy)
                if d < 1 then return end
                boss._chargeDx    = dx / d
                boss._chargeDy    = dy / d
                boss._chargeTimer = 0.35
                boss._chargeSpeed = boss.speed * 5.5
            end,
        },
        -- 技能2：8方向弹幕（每4秒）
        {
            id       = "nova",
            interval = 4.0,
            effect   = function(boss, player, projectiles)
                if not projectiles then return end
                local Projectile = require("src.entities.projectile")
                for i = 0, 7 do
                    local a  = (i / 8) * math.pi * 2
                    local p  = Projectile.new(boss.x, boss.y,
                        math.cos(a), math.sin(a), 30, 230)
                    p._isEnemyProjectile = true
                    p._damage = 30
                    table.insert(projectiles, p)
                end
            end,
        },
        -- 技能3：追踪弹（每6秒，3颗追踪玩家的弹）
        {
            id       = "homing",
            interval = 6.0,
            effect   = function(boss, player, projectiles)
                if not player or not projectiles then return end
                local Projectile = require("src.entities.projectile")
                for i = 1, 3 do
                    local angle = (i-1) * (math.pi * 2 / 3) + (boss._homingOffset or 0)
                    local dx = player.x - boss.x
                    local dy = player.y - boss.y
                    local d  = math.sqrt(dx*dx + dy*dy)
                    if d > 0 then
                        local p = Projectile.new(boss.x, boss.y, dx/d, dy/d, 35, 260)
                        p._isEnemyProjectile = true
                        p._damage = 35
                        table.insert(projectiles, p)
                    end
                end
                boss._homingOffset = ((boss._homingOffset or 0) + 0.5) % (math.pi * 2)
            end,
        },
        -- 技能4：召唤（每20秒）
        {
            id       = "summon",
            interval = 20.0,
            effect   = function(boss, player, projectiles)
                boss._summonPending = (boss._summonPending or 0) + 3
            end,
        },
    },
}

return BossConfig
