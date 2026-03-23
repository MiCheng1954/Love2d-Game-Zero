--[[
    src/ui/hud.lua
    局内常驻 HUD — Phase 11
    从 game.lua 拆离，统一所有 HUD 绘制，并做视觉升级：
        - 血量条：低血量（<25%）红色脉冲闪烁
        - 经验条：显示当前/升级所需 + 等级数字
        - 灵魂：带六芒星图标 + 数字
        - 武器快览：格子图标（背包所有武器）
        - 复活次数：心形图标列
        - Buff HUD / 技能栏 / 计时器 / 调试面板 / 传承图标 全部迁移此处

    对外接口：
        HUD.update(dt)   — 更新闪烁计时等内部状态
        HUD.draw(ctx)    — 绘制全部 HUD（ctx 见下方注释）
]]

local Font       = require("src.utils.font")
local SkillSynergy = require("src.systems.skillSynergy")
local Components = require("src.ui.components")

local HUD = {}

-- ============================================================
-- 内部状态
-- ============================================================
local _pulseTimer = 0   -- 低血量脉冲计时（秒）
local _PULSE_PERIOD = 0.7  -- 脉冲周期
local _debugVisible = true  -- 需求#11：debug 面板可见开关（默认开）

-- ============================================================
-- HUD.toggleDebug — 切换 debug 面板可见状态（供控制台指令调用）
-- ============================================================
function HUD.toggleDebug()
    _debugVisible = not _debugVisible
end

function HUD.isDebugVisible()
    return _debugVisible
end

-- ============================================================
-- HUD.update — 每帧更新内部动画状态
-- @param dt — 帧时间
-- ============================================================
function HUD.update(dt)
    _pulseTimer = (_pulseTimer + dt) % _PULSE_PERIOD
end

-- ============================================================
-- HUD.draw — 绘制全部 HUD
-- @param ctx 上下文表：
--   ctx.player         — 玩家实例
--   ctx.skillManager   — 技能管理器
--   ctx.rhythm         — 节奏控制器（Phase 9）
--   ctx.boss           — 当前 Boss（可为 nil）
--   ctx.paused         — 是否暂停
--   ctx.levelUpNotice  — 升级浮窗状态 { active, level, timer, duration }
--   ctx.victory        — 是否胜利状态
--   ctx.enemies        — 敌人列表（调试面板用）
--   ctx.projectiles    — 投射物列表（调试面板用）
--   ctx.pickups        — 掉落物列表（调试面板用）
-- ============================================================
function HUD.draw(ctx)
    local player  = ctx.player
    local sm      = ctx.skillManager
    local rhythm  = ctx.rhythm
    if not player then return end

    -- ---- 左上角：HP + EXP + 等级 + 灵魂 + 复活次数 ----
    HUD._drawVitalStats(player)

    -- ---- 右上角：激活羁绊列表 ----
    HUD._drawSynergies(player, sm)

    -- ---- 右上角：计时器 + 节奏阶段 ----
    if rhythm then
        HUD._drawTimer(rhythm)
    end

    -- ---- 左下角：技能栏（主动槽 + 被动列表）----
    HUD._drawSkillBar(player, sm)

    -- ---- 技能栏正上方：Buff HUD ----
    HUD._drawBuffHUD(player, sm)

    -- ---- 技能栏右方：传承图标 ----
    -- （由 _drawSkillBar 内部调用，保持位置联动）

    -- ---- 中下方：武器快览格子 ----
    HUD._drawWeaponGrid(player)

    -- ---- Boss 血条（顶部居中）----
    if ctx.boss and not ctx.boss._isDead then
        ctx.boss:drawHUD(1280, T(ctx.boss._bossName))
    end

    -- ---- 暂停遮罩 ----
    if ctx.paused then
        HUD._drawPauseOverlay()
    end

    -- ---- 升级浮窗 ----
    if ctx.levelUpNotice and ctx.levelUpNotice.active then
        HUD._drawLevelUpNotice(ctx.levelUpNotice)
    end

    -- ---- 胜利覆盖 ----
    if ctx.victory then
        HUD._drawVictoryOverlay()
    end

    -- ---- 调试面板（右侧）----
    if _debugVisible then
        HUD._drawDebugPanel(player, ctx)
    end

    -- ---- 操作提示（底部）----
    love.graphics.setColor(0.4, 0.4, 0.45)
    Font.set(12)
    love.graphics.print(T("hud.hint"), 20, 695)
    Font.reset()
    love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================
-- 左上角：HP条 + 经验条 + 灵魂 + 等级 + 复活次数
-- ============================================================
function HUD._drawVitalStats(player)
    local X = 20
    local Y = 20
    local BAR_W = 210
    local BAR_H = 18

    -- ===== HP 条 =====
    local hpRatio = math.max(0, player.hp / player.maxHp)
    local isLow   = hpRatio < 0.25

    -- 低血量脉冲：透明度在 0.55~1.0 之间呼吸
    local hpAlpha = 1.0
    if isLow then
        local t = _pulseTimer / _PULSE_PERIOD
        hpAlpha = 0.55 + 0.45 * math.abs(math.sin(t * math.pi))
    end

    local hpColor = isLow and { 1.0, 0.1, 0.1, hpAlpha }
                           or  { 0.85, 0.22, 0.22, 1 }

    Components.drawBarWithBorder(X, Y, BAR_W, BAR_H, hpRatio, hpColor, nil,
        isLow and {1.0, 0.3, 0.3, hpAlpha} or Components.COLORS.BORDER)

    -- HP 数值
    Font.set(12)
    love.graphics.setColor(1, 1, 1, isLow and hpAlpha or 1)
    love.graphics.print(
        T("hud.hp") .. "  " .. player.hp .. " / " .. player.maxHp,
        X + 5, Y + 3)

    -- ===== 经验条 =====
    local expY = Y + BAR_H + 4
    local expRatio = player:getExpProgress()
    Components.drawBarWithBorder(X, expY, BAR_W, 10, expRatio,
        Components.COLORS.EXP, nil, Components.COLORS.BORDER, 2)

    -- 等级徽章（经验条左侧）
    Font.set(12)
    love.graphics.setColor(Components.COLORS.GOLD[1], Components.COLORS.GOLD[2], Components.COLORS.GOLD[3])
    love.graphics.print(T("hud.level") .. player:getLevel(), X, expY + 13)

    -- ===== 灵魂 =====
    local soulY = expY + 28
    Components.drawSoulIcon(X + 8, soulY + 7, 7)
    Font.set(13)
    love.graphics.setColor(0.75, 0.5, 1.0)
    love.graphics.print(T("hud.souls") .. ": " .. player:getSouls(), X + 20, soulY)

    -- ===== 复活次数（心形图标）=====
    local revives = player._revives or 0
    if revives > 0 then
        local revY = soulY + 20
        Font.set(11)
        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.print("复活:", X, revY)
        Components.drawHeartIcons(X + 34, revY, revives, 13)
    end

    Font.reset()
    love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================
-- 右上角：激活羁绊列表
-- ============================================================
function HUD._drawSynergies(player, sm)
    local activeSynergies = player:getBag()._activeSynergies or {}
    local skillPsb = {}
    sm:recalcPassive(skillPsb)
    local skillActiveSyn = SkillSynergy.recalculate(sm, skillPsb)

    local allSyn = {}
    for _, s in ipairs(activeSynergies)  do table.insert(allSyn, s) end
    for _, s in ipairs(skillActiveSyn)   do table.insert(allSyn, s) end

    if #allSyn == 0 then return end

    Font.set(12)
    local sx = 1280 - 20
    local sy = 60    -- 计时器下方
    local lh = 18

    -- 标题
    love.graphics.setColor(Components.COLORS.GOLD[1], Components.COLORS.GOLD[2], Components.COLORS.GOLD[3])
    love.graphics.printf("[羁绊]", sx - 180, sy, 180, "right")
    sy = sy + lh

    for _, syn in ipairs(allSyn) do
        love.graphics.setColor(0.35, 0.95, 0.65)
        love.graphics.printf("+ " .. T(syn.nameKey), sx - 180, sy, 180, "right")
        sy = sy + lh
    end

    Font.reset()
    love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================
-- 右上角：计时器 + 节奏阶段
-- ============================================================
function HUD._drawTimer(rhythm)
    local elapsed = rhythm:getElapsed()
    local minutes = math.floor(elapsed / 60)
    local seconds = math.floor(elapsed % 60)
    local timeStr = string.format("%02d:%02d", minutes, seconds)

    Font.set(16)
    love.graphics.setColor(0.9, 0.9, 0.9, 0.9)
    love.graphics.printf(timeStr, 0, 20, 1260, "right")

    -- 节奏阶段
    local phaseColors = {
        calm   = { 0.5, 0.8, 0.5 },
        rising = { 0.9, 0.8, 0.3 },
        peak   = { 1.0, 0.4, 0.2 },
        rest   = { 0.5, 0.7, 0.9 },
        surge  = { 1.0, 0.2, 0.6 },
    }
    local phase = rhythm:getPhaseName()
    local c = phaseColors[phase] or { 0.7, 0.7, 0.7 }
    Font.set(11)
    love.graphics.setColor(c[1], c[2], c[3], 0.7)
    love.graphics.printf(phase, 0, 40, 1260, "right")

    Font.reset()
    love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================
-- 左下角：技能栏（主动槽 × 4 + 被动列表 + 传承图标）
-- ============================================================
function HUD._drawSkillBar(player, sm)
    local bag = player:getBag()
    local psb = bag._playerSynergyBonus or {}
    local skillPsb = {}
    sm:recalcPassive(skillPsb)
    SkillSynergy.recalculate(sm, skillPsb)
    local cdReduce = (psb.cdReduce or 0) + (skillPsb.cdReduce or 0)

    local slots    = sm._slots
    local passives = sm:getPassives()

    Font.set(12)

    local baseX = 20
    local slotW = 58
    local slotH = 54
    local slotGap = 6
    local startY = 640

    local slotOrder = { "skill1", "skill2", "skill3", "skill4" }
    local slotKeys  = { skill1 = "空格", skill2 = "Q", skill3 = "E", skill4 = "F" }
    local totalSlotsW = slotW * 4 + slotGap * 3

    -- 背景
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", baseX - 4, startY - 4, totalSlotsW + 8, slotH + 8, 4, 4)

    for i, slotKey in ipairs(slotOrder) do
        local inst = slots[slotKey]
        local x = baseX + (i - 1) * (slotW + slotGap)
        local y = startY

        -- 槽背景
        if inst then
            local ratio = sm:getCooldownRatio(inst.id, cdReduce)
            local ready = ratio >= 1.0
            if ready then
                love.graphics.setColor(0.2, 0.5, 0.2, 0.9)
            else
                love.graphics.setColor(0.14, 0.14, 0.22, 0.9)
            end
        else
            love.graphics.setColor(0.1, 0.1, 0.13, 0.7)
        end
        love.graphics.rectangle("fill", x, y, slotW, slotH, 4, 4)

        -- 槽边框
        if inst then
            love.graphics.setColor(0.5, 0.35, 0.9)
        else
            love.graphics.setColor(0.3, 0.3, 0.35)
        end
        love.graphics.rectangle("line", x, y, slotW, slotH, 4, 4)

        -- 按键标签
        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.print("[" .. slotKeys[slotKey] .. "]", x + 3, y + 3)

        if inst then
            local cfg   = inst.cfg
            local ratio = sm:getCooldownRatio(inst.id, cdReduce)
            local ready = ratio >= 1.0

            if ready then
                love.graphics.setColor(0.3, 1.0, 0.5)
            else
                love.graphics.setColor(0.85, 0.85, 0.85)
            end
            love.graphics.printf(T(cfg.nameKey), x + 2, y + 18, slotW - 4, "left")

            -- CD 进度条
            local barY = y + slotH - 10
            love.graphics.setColor(0.2, 0.2, 0.2)
            love.graphics.rectangle("fill", x + 3, barY, slotW - 6, 6, 2, 2)
            if ready then
                love.graphics.setColor(0.3, 1.0, 0.5)
            else
                love.graphics.setColor(0.5, 0.3, 0.8)
            end
            love.graphics.rectangle("fill", x + 3, barY, (slotW - 6) * ratio, 6, 2, 2)
        else
            love.graphics.setColor(0.35, 0.35, 0.4)
            love.graphics.printf("空", x, y + 20, slotW, "center")
        end
    end

    -- 被动列表（需求#9：已取消被动技能的面板显示）
    -- 原逻辑已移除，被动效果仍正常生效，只是不在 HUD 显示

    Font.reset()

    -- 传承图标（技能槽右侧）
    HUD._drawLegacyIcon(baseX + totalSlotsW + 10, startY, slotH, player)
end

-- ============================================================
-- 技能栏正上方：Buff HUD
-- ============================================================
function HUD._drawBuffHUD(player, sm)
    if not player._buffManager then return end

    local buffList = player._buffManager:getAll()

    -- global_slow 虚拟条目（Bug#38：加入 remaining/duration 以显示倒计时）
    local slowRate = sm:getGlobalSlow()
    if slowRate and slowRate > 0 then
        local slowTimer    = sm._globalSlowTimer or 0
        -- duration 取历史最大值（首次设置时记录在 sm._globalSlowDuration）
        local slowDuration = sm._globalSlowDuration or slowTimer
        table.insert(buffList, {
            id       = "global_slow",
            buffType = "timer",
            remaining = slowTimer,
            duration  = math.max(slowDuration, slowTimer),
            def      = { nameKey = "buff.global_slow.name", color = { 0.4, 0.8, 0.9 } },
        })
    end

    if #buffList == 0 then return end

    local BLOCK_W   = 64
    local BLOCK_H   = 28
    local BLOCK_GAP = 4
    local MAX_BLOCKS = 8
    local startX = 20
    local startY = 608

    Font.set(11)

    for i, entry in ipairs(buffList) do
        if i > MAX_BLOCKS then break end
        local x   = startX + (i - 1) * (BLOCK_W + BLOCK_GAP)
        local y   = startY
        local def = entry.def
        local color = def and def.color or { 0.6, 0.6, 0.6 }

        -- 深色底
        love.graphics.setColor(0.05, 0.05, 0.08, 0.85)
        love.graphics.rectangle("fill", x, y, BLOCK_W, BLOCK_H, 3, 3)

        -- 进度条
        local ratio = 1.0
        if entry.buffType == "timer" and entry.duration and entry.duration > 0 then
            ratio = math.max(0, entry.remaining / entry.duration)
        end
        love.graphics.setColor(color[1], color[2], color[3], 0.7)
        love.graphics.rectangle("fill", x, y, BLOCK_W * ratio, BLOCK_H, 3, 3)

        -- 边框
        love.graphics.setColor(color[1], color[2], color[3], 0.9)
        love.graphics.rectangle("line", x, y, BLOCK_W, BLOCK_H, 3, 3)

        -- Buff 名
        love.graphics.setColor(1, 1, 1, 0.95)
        love.graphics.print(T(def and def.nameKey or entry.id) or entry.id, x + 3, y + 3)

        -- 右下角标签
        love.graphics.setColor(1, 1, 0.8, 0.9)
        local label = ""
        if entry.buffType == "timer" and entry.remaining then
            label = string.format("%.1fs", math.max(0, entry.remaining))
        elseif entry.buffType == "stack" and entry.stacks then
            label = "×" .. tostring(entry.stacks)
        end
        if label ~= "" then
            love.graphics.printf(label, x, y + BLOCK_H - 14, BLOCK_W - 3, "right")
        end
    end

    Font.reset()
    love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================
-- 武器快览格子（右下角，技能栏右侧同高度）
-- 每个武器一个小格子（32×32），显示武器名缩写 + 等级
-- ============================================================
function HUD._drawWeaponGrid(player)
    local bag     = player:getBag()
    local weapons = bag:getAllWeapons()
    if #weapons == 0 then return end

    local CELL      = 32
    local GAP       = 4
    local PER_ROW   = 8    -- Bug#42：每行最多 8 个，超出换行
    local MAX_ROWS  = 4    -- 最多 4 行（支持到 32 个武器）
    local baseY     = 672  -- 最底行的顶部 Y（向上堆叠）
    local baseX     = 1280 - 20 - CELL  -- 右对齐基准

    Font.set(10)

    local count = math.min(#weapons, PER_ROW * MAX_ROWS)

    -- 从右向左、从下往上排列（第 1 行最底部，超出 8 个往上开第 2 行）
    for i = 1, count do
        local w    = weapons[i]
        local col  = (i - 1) % PER_ROW         -- 当前行内第几个（0-based，从右往左）
        local row  = math.floor((i - 1) / PER_ROW)  -- 第几行（0-based，0=最底行）
        local x    = baseX - col * (CELL + GAP)
        local y    = baseY - row * (CELL + GAP)

        -- 格子背景（使用武器颜色）
        local wc = w.color or { 0.5, 0.5, 0.6 }
        love.graphics.setColor(wc[1] * 0.5, wc[2] * 0.5, wc[3] * 0.5, 0.85)
        love.graphics.rectangle("fill", x, y, CELL, CELL, 3, 3)

        -- 需求#10：充能进度弧形（在格子边框内侧画充能扇形）
        local interval = (w.getEffectiveAttackSpeed and 1.0 / math.max(0.01, w:getEffectiveAttackSpeed())) or 1.0
        local chargeRatio = math.min(1.0, (w._attackTimer or 0) / interval)
        local ready = chargeRatio >= 1.0

        if ready then
            -- 满充能：亮色描边闪光
            love.graphics.setColor(wc[1], wc[2], wc[3], 0.85)
            love.graphics.rectangle("fill", x + 1, y + 1, CELL - 2, CELL - 2, 2, 2)
        else
            -- 充能中：底部到顶部填充矩形（从下往上）
            local fillH = math.floor((CELL - 2) * chargeRatio)
            love.graphics.setColor(wc[1] * 0.4, wc[2] * 0.4, wc[3] * 0.4, 0.55)
            love.graphics.rectangle("fill", x + 1, y + 1, CELL - 2, CELL - 2, 2, 2)
            if fillH > 0 then
                love.graphics.setColor(wc[1], wc[2], wc[3], 0.55)
                love.graphics.rectangle("fill", x + 1, y + CELL - 1 - fillH, CELL - 2, fillH, 2, 2)
            end
        end

        -- 边框
        if ready then
            love.graphics.setColor(1.0, 1.0, 0.8, 0.95)
        else
            love.graphics.setColor(wc[1], wc[2], wc[3], 0.8)
        end
        love.graphics.rectangle("line", x, y, CELL, CELL, 3, 3)

        -- 武器名缩写（取前 2 字）
        local name = T(w.cfg and w.cfg.nameKey or ("weapon." .. w.configId .. ".name")) or w.configId
        local abbr = string.sub(name, 1, 6)   -- 取前 6 字节（约 2 中文字）
        love.graphics.setColor(1, 1, 1, 0.95)
        love.graphics.printf(abbr, x, y + 6, CELL, "center")

        -- 等级小徽章（右下）
        if w.level and w.level > 1 then
            love.graphics.setColor(Components.COLORS.GOLD[1], Components.COLORS.GOLD[2], Components.COLORS.GOLD[3], 0.9)
            love.graphics.printf("Lv" .. w.level, x, y + CELL - 13, CELL - 2, "right")
        end
    end

    Font.reset()
    love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================
-- 传承图标（技能槽右侧）
-- ============================================================
function HUD._drawLegacyIcon(x, y, h, player)
    if not player then return end

    local radius = h / 2
    local cx     = x + radius
    local cy     = y + radius

    local legacy = player._legacyData

    if legacy then
        love.graphics.setColor(1.0, 0.85, 0.2, 0.2)
        love.graphics.circle("fill", cx, cy, radius + 4)
        love.graphics.setColor(0.18, 0.14, 0.04, 0.95)
        love.graphics.circle("fill", cx, cy, radius)
        love.graphics.setColor(1.0, 0.85, 0.2, 0.9)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", cx, cy, radius)
        love.graphics.setLineWidth(1)
        Font.set(16)
        love.graphics.setColor(1.0, 0.85, 0.2)
        love.graphics.printf("传", cx - radius, cy - 11, radius * 2, "center")
        Font.set(11)
        love.graphics.setColor(1.0, 0.95, 0.7, 0.9)
        love.graphics.printf(T(legacy.nameKey), cx - 50, cy + radius + 4, 100, "center")
    else
        love.graphics.setColor(0.12, 0.12, 0.14, 0.85)
        love.graphics.circle("fill", cx, cy, radius)
        love.graphics.setColor(0.3, 0.3, 0.33, 0.7)
        love.graphics.setLineWidth(1)
        love.graphics.circle("line", cx, cy, radius)
        Font.set(11)
        love.graphics.setColor(0.4, 0.4, 0.4)
        love.graphics.printf(T("hud.legacy_none"), cx - 40, cy + radius + 3, 80, "center")
    end

    Font.reset()
    love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================
-- 暂停遮罩
-- ============================================================
function HUD._drawPauseOverlay()
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", 0, 0, 1280, 720)
    love.graphics.setColor(1, 0.85, 0.1)
    Font.set(28)
    love.graphics.printf(T("hud.paused"), 0, 320, 1280, "center")
    Font.set(15)
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.printf(T("hud.pause_hint"), 0, 368, 1280, "center")
    Font.reset()
    love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================
-- 升级浮窗
-- ============================================================
function HUD._drawLevelUpNotice(notice)
    local alpha = 1.0
    if notice.timer < 0.8 then
        alpha = notice.timer / 0.8
    end
    love.graphics.setColor(0.1, 0.1, 0.1, 0.85 * alpha)
    love.graphics.rectangle("fill", 490, 280, 300, 70, 8, 8)
    love.graphics.setColor(1, 0.85, 0.1, alpha)
    love.graphics.rectangle("line", 490, 280, 300, 70, 8, 8)
    Font.set(14)
    love.graphics.setColor(1, 0.85, 0.1, alpha)
    love.graphics.printf(T("upgrade.title"), 490, 292, 300, "center")
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.printf(T("upgrade.reached", notice.level), 490, 316, 300, "center")
    Font.reset()
    love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================
-- 胜利覆盖
-- ============================================================
function HUD._drawVictoryOverlay()
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, 1280, 720)
    Font.set(40)
    love.graphics.setColor(1.0, 0.9, 0.2)
    love.graphics.printf(T("hud.victory") or "胜利！", 0, 280, 1280, "center")
    Font.set(18)
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.printf(T("hud.victory_hint") or "你击败了虚空领主！", 0, 340, 1280, "center")
    Font.reset()
    love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================
-- 调试面板
-- ============================================================
function HUD._drawDebugPanel(player, ctx)
    local x  = 900
    local y  = 20
    local lh = 16

    local bag      = player:getBag()
    local weapons  = bag:getAllWeapons()
    local synergies = bag._activeSynergies or {}
    local panelH   = lh * (12 + math.max(1, #weapons) + math.max(1, #synergies)) + 8

    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", x - 8, y - 4, 370, panelH)

    love.graphics.setColor(0.4, 1, 0.4)
    Font.set(13)
    love.graphics.print(T("debug.title"), x, y)

    love.graphics.setColor(1, 1, 1)
    love.graphics.print(string.format("Pos:    (%.0f, %.0f)", player.x, player.y), x, y + lh * 1)
    love.graphics.print(string.format("HP:     %d / %d", player.hp, player.maxHp), x, y + lh * 2)
    love.graphics.print(string.format("Speed:  %.0f  | Lv: %d  Exp: %d/%d",
        player.speed, player:getLevel(), player._exp, player._expToNext), x, y + lh * 3)
    love.graphics.print(string.format("Souls:  %d  | PickupR: %.0f",
        player:getSouls(), player.pickupRadius), x, y + lh * 4)
    love.graphics.print(string.format("Enemies: %d  | Projs: %d  | Pickups: %d",
        ctx.enemies and #ctx.enemies or 0,
        ctx.projectiles and #ctx.projectiles or 0,
        ctx.pickups and #ctx.pickups or 0), x, y + lh * 5)
    love.graphics.print(string.format("Bag: %dx%d  | Weapons: %d",
        bag.cols, bag.rows, #weapons), x, y + lh * 6)

    if #weapons == 0 then
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.print("  (no weapon - fallback)", x, y + lh * 7)
    else
        for i, w in ipairs(weapons) do
            love.graphics.setColor(w.color[1], w.color[2], w.color[3])
            love.graphics.print(string.format(
                "  W%d: %-8s Lv%d  spd=%.1f(+%.1f) tmr=%.2f",
                i, w.configId, w.level,
                w.attackSpeed, w._adjBonus.attackSpeed + w._synergyBonus.attackSpeed,
                w._attackTimer), x, y + lh * (6 + i))
        end
    end

    local weaponRows = math.max(1, #weapons)
    local baseRow    = 7 + weaponRows

    -- Tag 计数
    local tagCounts = bag._tagCounts or {}
    local tagStr = ""
    local SynConfig = require("config.synergies")
    for _, entry in ipairs(SynConfig) do
        local tag = entry.tag
        local cnt = tagCounts[tag] or 0
        if cnt > 0 then tagStr = tagStr .. tag .. ":" .. cnt .. " " end
    end
    love.graphics.setColor(1, 0.75, 0.3)
    if tagStr == "" then
        love.graphics.print("  Tag计数: (无)", x, y + lh * baseRow)
    else
        love.graphics.print("  Tag计数: " .. tagStr, x, y + lh * baseRow)
    end
    baseRow = baseRow + 1

    -- 激活羁绊
    love.graphics.setColor(1, 0.85, 0.4)
    if #synergies == 0 then
        love.graphics.print("  激活羁绊: (无)", x, y + lh * baseRow)
    else
        love.graphics.print("  激活羁绊:", x, y + lh * baseRow)
        for i, syn in ipairs(synergies) do
            love.graphics.setColor(0.4, 1.0, 0.7)
            love.graphics.print("    + " .. T(syn.nameKey), x, y + lh * (baseRow + i))
        end
    end
    local synergyRows = math.max(1, #synergies + 1)
    baseRow = baseRow + synergyRows

    love.graphics.setColor(1, 1, 0.4)
    love.graphics.print(string.format("FPS: %d", love.timer.getFPS()), x, y + lh * baseRow)

    if ctx.rhythm then
        love.graphics.setColor(1, 1, 1)
        local params = ctx.rhythm:getSpawnParams()
        love.graphics.print(string.format(
            "Rhythm: interval=%.2f  batch=%d  elite=%.0f%%  ranger=%.0f%%",
            params.interval, params.batchSize,
            params.eliteChance * 100, params.rangerChance * 100),
            x, y + lh * (baseRow + 1))
        love.graphics.print(string.format(
            "Elapsed: %.1f s  | Phase: %s  | Boss: %s",
            ctx.rhythm:getElapsed(), ctx.rhythm:getPhaseName(),
            ctx.boss and ctx.boss._typeName or "none"),
            x, y + lh * (baseRow + 2))
    end

    Font.reset()
    love.graphics.setColor(1, 1, 1, 1)
end

return HUD
