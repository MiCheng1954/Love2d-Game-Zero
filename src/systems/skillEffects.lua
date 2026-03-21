--[[
    src/systems/skillEffects.lua
    技能释放视觉效果系统 — Phase 8（需求1）

    提供简单的几何形状特效：
        - 冲刺：方向拖尾线段
        - 投掷炸弹：圆形爆炸波
        - 时间减缓 / 电磁脉冲：全屏闪烁
        - 传送闪现：圆圈消散
        - 战吼：玩家周围扩散圆
        - 魔法护罩：玩家身上持续光圈
        - 治疗：绿色粒子上升
        - 超载：武器发光闪烁提示

    用法：
        local FX = require("src.systems.skillEffects")
        FX.spawn("dash", player, ctx)   -- 触发技能时调用
        FX.update(dt)                   -- 每帧更新
        FX.draw()                       -- 每帧绘制（在玩家层之上）
        FX.clear()                      -- 场景重置时清除
]]

local FX = {}

-- 活跃特效列表
local _effects = {}

-- ============================================================
-- 内部特效构造
-- ============================================================

local function addEffect(t)
    t.elapsed = 0
    table.insert(_effects, t)
end

-- ============================================================
-- 公共 API
-- ============================================================

-- 触发技能特效
-- @param skillId  技能 id
-- @param player   玩家实例（含 x/y/_dx/_dy）
-- @param ctx      技能上下文（可含 enemies 等）
function FX.spawn(skillId, player, ctx)
    if skillId == "dash" then
        -- 冲刺：方向拖尾线段（从旧位置到新位置）
        local dx = ctx and ctx.dx or 0
        local dy = ctx and ctx.dy or 0
        if dx == 0 and dy == 0 then dx = 1 end
        addEffect({
            type     = "trail",
            x1 = player.x - dx * 50,
            y1 = player.y - dy * 50,
            x2 = player.x,
            y2 = player.y,
            duration = 0.35,
            r = 0.5, g = 0.8, b = 1.0,
        })

    elseif skillId == "bomb_throw" then
        -- 炸弹：爆炸圆圈扩散
        local dx = ctx and ctx.dx or 0
        local dy = ctx and ctx.dy or 1
        if dx == 0 and dy == 0 then dy = 1 end
        addEffect({
            type     = "ring_expand",
            x        = player.x + dx * 200,
            y        = player.y + dy * 200,
            radius   = 0,
            maxR     = 160,
            duration = 0.4,
            r = 1.0, g = 0.6, b = 0.1,
        })

    elseif skillId == "time_slow" or skillId == "emp_burst" then
        -- 全屏减速：屏幕边缘蓝色闪烁
        addEffect({
            type     = "screen_flash",
            duration = 0.3,
            r = 0.2, g = 0.5, b = 1.0, a = 0.25,
        })

    elseif skillId == "blink" then
        -- 传送：玩家位置圆圈消散
        addEffect({
            type     = "ring_expand",
            x        = player.x,
            y        = player.y,
            radius   = 10,
            maxR     = 80,
            duration = 0.3,
            r = 0.8, g = 0.3, b = 1.0,
        })

    elseif skillId == "battle_cry" then
        -- 战吼：扩散大圆
        addEffect({
            type     = "ring_expand",
            x        = player.x,
            y        = player.y,
            radius   = 0,
            maxR     = 320,
            duration = 0.5,
            r = 1.0, g = 0.8, b = 0.1,
        })

    elseif skillId == "mana_shield" then
        -- 魔法护罩：玩家身上出现护盾圈（跟随玩家，存储 playerRef）
        addEffect({
            type       = "orbit_ring",
            x          = player.x,
            y          = player.y,
            playerRef  = player,   -- Feature #8：每帧同步玩家位置
            radius     = 28,
            duration   = 1.5,
            r = 0.3, g = 0.7, b = 1.0,
        })

    elseif skillId == "heal_pulse" then
        -- 治疗：绿色光圈
        addEffect({
            type     = "ring_expand",
            x        = player.x,
            y        = player.y,
            radius   = 0,
            maxR     = 50,
            duration = 0.4,
            r = 0.2, g = 1.0, b = 0.4,
        })

    elseif skillId == "explosion" then
        -- 范围爆炸
        addEffect({
            type     = "ring_expand",
            x        = player.x,
            y        = player.y,
            radius   = 0,
            maxR     = 160,
            duration = 0.45,
            r = 1.0, g = 0.4, b = 0.1,
        })

    elseif skillId == "overload" then
        -- 超载：玩家周围橙色爆发
        addEffect({
            type     = "ring_expand",
            x        = player.x,
            y        = player.y,
            radius   = 0,
            maxR     = 100,
            duration = 0.4,
            r = 1.0, g = 0.5, b = 0.0,
        })
        addEffect({
            type     = "screen_flash",
            duration = 0.2,
            r = 1.0, g = 0.5, b = 0.0, a = 0.15,
        })

    elseif skillId == "rage" or skillId == "counter_shot" then
        -- 受伤反击/狂怒：红色闪光
        addEffect({
            type     = "screen_flash",
            duration = 0.2,
            r = 1.0, g = 0.1, b = 0.1, a = 0.2,
        })

    elseif skillId == "ammo_supply" then
        -- 弹药补给：玩家周围青绿扩散圈
        addEffect({
            type     = "ring_expand",
            x        = player.x,
            y        = player.y,
            radius   = 0,
            maxR     = 60,
            duration = 0.4,
            r = 0.2, g = 1.0, b = 0.7,
        })
        addEffect({
            type     = "screen_flash",
            duration = 0.15,
            r = 0.2, g = 1.0, b = 0.6, a = 0.1,
        })

    elseif skillId == "soul_drain" then
        -- 灵魂汲取：紫色收缩圆（从外往内）
        addEffect({
            type     = "ring_expand",
            x        = player.x,
            y        = player.y,
            radius   = 120,
            maxR     = 10,
            duration = 0.35,
            r = 0.7, g = 0.2, b = 1.0,
        })

    elseif skillId == "thorns" then
        -- 荆棘反射：玩家身上红橙闪光圈
        addEffect({
            type     = "orbit_ring",
            x        = player.x,
            y        = player.y,
            playerRef = player,
            radius   = 22,
            duration = 0.5,
            r = 1.0, g = 0.3, b = 0.1,
        })
        addEffect({
            type     = "screen_flash",
            duration = 0.15,
            r = 1.0, g = 0.3, b = 0.1, a = 0.15,
        })
    end
end

-- 每帧更新
function FX.update(dt)
    local i = 1
    while i <= #_effects do
        local e = _effects[i]
        e.elapsed = e.elapsed + dt
        -- Feature #8：orbit_ring 跟随玩家
        if e.type == "orbit_ring" and e.playerRef then
            e.x = e.playerRef.x
            e.y = e.playerRef.y
        end
        if e.elapsed >= e.duration then
            table.remove(_effects, i)
        else
            i = i + 1
        end
    end
end

-- 每帧绘制世界特效（在 camera:attach() 内调用，跳过 screen_flash）
-- camX, camY 在 camera:attach() 内已为 0（坐标系已变换）
function FX.draw(camX, camY)
    camX = camX or 0
    camY = camY or 0

    for _, e in ipairs(_effects) do
        local t = e.elapsed / e.duration
        local alpha = 1 - t

        if e.type == "trail" then
            love.graphics.setColor(e.r, e.g, e.b, alpha * 0.8)
            love.graphics.setLineWidth(3 * (1 - t) + 1)
            love.graphics.line(e.x1 - camX, e.y1 - camY, e.x2 - camX, e.y2 - camY)
            love.graphics.setLineWidth(1)

        elseif e.type == "ring_expand" then
            local r = e.radius + (e.maxR - e.radius) * t
            love.graphics.setColor(e.r, e.g, e.b, alpha * 0.7)
            love.graphics.setLineWidth(2 + (1 - t) * 2)
            love.graphics.circle("line", e.x - camX, e.y - camY, r)
            love.graphics.setLineWidth(1)

        elseif e.type == "orbit_ring" then
            local pulse = 1 + math.sin(t * math.pi * 4) * 0.1
            love.graphics.setColor(e.r, e.g, e.b, alpha * 0.6)
            love.graphics.setLineWidth(2)
            love.graphics.circle("line", e.x - camX, e.y - camY, e.radius * pulse)
            love.graphics.setLineWidth(1)
        end
        -- screen_flash 交给 drawScreenEffects()
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- 绘制屏幕层特效（在 camera:detach() 之后调用，仅处理 screen_flash）
function FX.drawScreenEffects()
    for _, e in ipairs(_effects) do
        if e.type == "screen_flash" then
            local t     = e.elapsed / e.duration
            local alpha = 1 - t
            love.graphics.setColor(e.r, e.g, e.b, (e.a or 0.2) * alpha)
            love.graphics.rectangle("fill", 0, 0, 1280, 720)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- 清空所有特效
function FX.clear()
    _effects = {}
end

return FX
