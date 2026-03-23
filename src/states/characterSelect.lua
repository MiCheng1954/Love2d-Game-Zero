--[[
    src/states/characterSelect.lua
    角色选择界面 — Phase 13
    使用 push/pop StateManager 覆盖层模式
    ← → 切换角色卡片，Enter 确认选择后 push "sceneSelect"，ESC 返回上一层
]]

local Font          = require("src.utils.font")
local Input         = require("src.systems.input")
local CharConfig    = require("config.characters")
local SkillConfig   = require("config.skills")

local CharacterSelect = {}

-- ============================================================
-- 角色顺序（定义卡片排列顺序）
-- ============================================================
local CHAR_ORDER = { "engineer", "berserker", "phantom" }

-- ============================================================
-- 布局常量
-- ============================================================
local SCREEN_W  = 1280
local SCREEN_H  = 720
local CARD_W    = 340
local CARD_H    = 460
local CARD_GAP  = 20
local CARD_TOP  = 140    -- 卡片顶部 y（给标题和提示留空间）
local HEADER_H  = 60     -- 顶部彩色色块高度

-- ============================================================
-- 内部状态
-- ============================================================
local _selected  = 1       -- 当前选中索引（1-based）
local _time      = 0       -- 动画累计时间
local _fadeIn    = 0       -- 淡入进度（0→1）
local _onSelect  = nil     -- 可选回调 data.onSelect(charId)

-- ============================================================
-- 辅助：计算第 i 张卡片的左上角 x 坐标
-- ============================================================
local function cardX(i)
    local totalW = #CHAR_ORDER * CARD_W + (#CHAR_ORDER - 1) * CARD_GAP
    local startX = (SCREEN_W - totalW) / 2
    return startX + (i - 1) * (CARD_W + CARD_GAP)
end

-- ============================================================
-- 辅助：将 critRate(0.05) 格式化为 "5%"
-- ============================================================
local function fmtPct(v)
    return string.format("%d%%", math.floor(v * 100 + 0.5))
end

-- ============================================================
-- 绘制单张角色卡片
-- ============================================================
local function drawCard(i, charId, isSelected, time, alpha)
    local cfg      = CharConfig[charId]
    if not cfg then return end

    local skillCfg = SkillConfig[cfg.exclusiveSkill]
    local x        = cardX(i)
    local y        = CARD_TOP
    local w        = CARD_W
    local h        = CARD_H
    local cr       = cfg.color[1]
    local cg       = cfg.color[2]
    local cb       = cfg.color[3]

    -- ---- 阴影 ----
    love.graphics.setColor(0, 0, 0, 0.38 * alpha)
    love.graphics.rectangle("fill", x + 7, y + 9, w, h, 10, 10)

    -- ---- 卡片主体背景 ----
    if isSelected then
        love.graphics.setColor(0.11, 0.10, 0.19, 0.94 * alpha)
    else
        love.graphics.setColor(0.07, 0.07, 0.13, 0.80 * alpha)
    end
    love.graphics.rectangle("fill", x, y, w, h, 10, 10)

    -- ---- 选中高亮边框（使用角色颜色）----
    if isSelected then
        local pulse = (math.sin(time * 3.0) + 1) * 0.5
        love.graphics.setColor(cr, cg, cb, (0.72 + 0.25 * pulse) * alpha)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", x, y, w, h, 10, 10)
        love.graphics.setLineWidth(1)
    else
        love.graphics.setColor(0.28, 0.26, 0.38, 0.45 * alpha)
        love.graphics.setLineWidth(1.5)
        love.graphics.rectangle("line", x, y, w, h, 10, 10)
        love.graphics.setLineWidth(1)
    end

    -- ============================================================
    -- 顶部彩色色块（HEADER_H 高度）
    -- ============================================================
    -- 裁剪到顶部圆角区域
    love.graphics.setScissor(x, y, w, HEADER_H)
    love.graphics.setColor(cr, cg, cb, (isSelected and 0.88 or 0.58) * alpha)
    love.graphics.rectangle("fill", x, y, w, HEADER_H, 10, 10)
    -- 补底部直角（Scissor 已限制高度，直接画矩形）
    love.graphics.setColor(cr, cg, cb, (isSelected and 0.88 or 0.58) * alpha)
    love.graphics.rectangle("fill", x, y + HEADER_H - 12, w, 12)
    love.graphics.setScissor()

    -- 角色名（在彩色色块内居中）
    local charName = T(cfg.nameKey) or charId
    Font.set(22)
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.printf(charName, x, y + 16, w, "center")
    Font.reset()

    -- ============================================================
    -- 卡片主体内容（从 HEADER_H 以下开始）
    -- ============================================================
    local bodyY = y + HEADER_H + 14
    local padX  = 18

    -- ---- 角色描述 ----
    local descStr = T(cfg.descKey) or ""
    Font.set(13)
    love.graphics.setColor(0.72, 0.70, 0.82, 0.90 * alpha)
    love.graphics.printf(descStr, x + padX, bodyY, w - padX * 2, "left")
    Font.reset()

    -- ---- 分隔线 ----
    local afterDescY = bodyY + 82
    love.graphics.setColor(cr * 0.5, cg * 0.5, cb * 0.5, 0.55 * alpha)
    love.graphics.setLineWidth(1)
    love.graphics.line(x + padX, afterDescY, x + w - padX, afterDescY)

    -- ---- 基础属性标题 ----
    local statsY = afterDescY + 10
    Font.set(13)
    love.graphics.setColor(cr, cg, cb, 0.90 * alpha)
    love.graphics.printf(T("char_select.stats"), x + padX, statsY, w - padX * 2, "left")
    Font.reset()

    -- ---- 属性列表 ----
    local stats = cfg.stats
    local statRows = {
        { label = "HP",    value = tostring(stats.maxHp) },
        { label = "速度",  value = tostring(stats.speed) },
        { label = "攻击",  value = tostring(stats.attack) },
        { label = "暴击率", value = fmtPct(stats.critRate) },
    }
    local rowH    = 22
    local statStartY = statsY + 20
    for ri, row in ipairs(statRows) do
        local ry = statStartY + (ri - 1) * rowH
        -- 交替行背景
        if ri % 2 == 0 then
            love.graphics.setColor(1, 1, 1, 0.04 * alpha)
            love.graphics.rectangle("fill", x + padX - 4, ry - 2, w - (padX - 4) * 2, rowH)
        end
        Font.set(13)
        -- 标签
        love.graphics.setColor(0.60, 0.58, 0.72, 0.85 * alpha)
        love.graphics.printf(row.label, x + padX, ry, 80, "left")
        -- 数值（高亮）
        love.graphics.setColor(0.92, 0.90, 1.0, alpha)
        love.graphics.printf(row.value, x + padX + 80, ry, w - padX * 2 - 80, "left")
        Font.reset()
    end

    -- ---- 分隔线 ----
    local afterStatsY = statStartY + #statRows * rowH + 8
    love.graphics.setColor(cr * 0.5, cg * 0.5, cb * 0.5, 0.55 * alpha)
    love.graphics.setLineWidth(1)
    love.graphics.line(x + padX, afterStatsY, x + w - padX, afterStatsY)

    -- ---- 专属技能 ----
    local skillY = afterStatsY + 10
    Font.set(13)
    love.graphics.setColor(cr, cg, cb, 0.90 * alpha)
    love.graphics.printf(T("char_select.exclusive"), x + padX, skillY, w - padX * 2, "left")
    Font.reset()

    local skillName = skillCfg and (T(skillCfg.nameKey) or cfg.exclusiveSkill) or cfg.exclusiveSkill
    Font.set(16)
    local pulse2 = isSelected and ((math.sin(time * 2.0) + 1) * 0.5) or 0
    love.graphics.setColor(
        math.min(1, cr + 0.15 + 0.08 * pulse2),
        math.min(1, cg + 0.10 + 0.06 * pulse2),
        math.min(1, cb + 0.05 + 0.04 * pulse2),
        alpha
    )
    love.graphics.printf(skillName, x + padX, skillY + 20, w - padX * 2, "left")
    Font.reset()

    -- ============================================================
    -- 选中箭头 ▼（卡片底部）
    -- ============================================================
    if isSelected then
        local arrowPulse = (math.sin(time * 3.5) + 1) * 0.5
        love.graphics.setColor(cr, cg, cb, (0.7 + 0.3 * arrowPulse) * alpha)
        Font.set(20)
        love.graphics.printf("▼", x, y + h - 32, w, "center")
        Font.reset()
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================
-- 生命周期
-- ============================================================
function CharacterSelect:enter(data)
    _selected = 1
    _time     = 0
    _fadeIn   = 0
    _onSelect = data and data.onSelect or nil
end

function CharacterSelect:exit()
    _onSelect = nil
end

-- ============================================================
-- 更新
-- ============================================================
function CharacterSelect:update(dt)
    _time   = _time + dt
    _fadeIn = math.min(_fadeIn + dt * 2.5, 1.0)   -- 约 0.4s 淡入
end

-- ============================================================
-- 绘制
-- ============================================================
function CharacterSelect:draw()
    local alpha = math.max(0, math.min(1, _fadeIn))

    -- ---- 渐变背景 ----
    local steps = 16
    local sh    = SCREEN_H / steps
    for i = 0, steps - 1 do
        local t = i / (steps - 1)
        love.graphics.setColor(0.04 + 0.02 * t, 0.03 + 0.01 * t, 0.10 + 0.05 * t, 1)
        love.graphics.rectangle("fill", 0, i * sh, SCREEN_W, sh + 1)
    end

    -- ---- 标题 ----
    Font.set(28)
    love.graphics.setColor(0.88, 0.82, 1.0, alpha)
    love.graphics.printf(T("char_select.title"), 0, 60, SCREEN_W, "center")
    Font.reset()

    -- ---- 操作提示 ----
    Font.set(14)
    love.graphics.setColor(0.58, 0.55, 0.72, 0.80 * alpha)
    love.graphics.printf(T("char_select.hint"), 0, 100, SCREEN_W, "center")
    Font.reset()

    -- ---- 绘制 3 张角色卡片 ----
    for i, charId in ipairs(CHAR_ORDER) do
        drawCard(i, charId, (i == _selected), _time, alpha)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================
-- 键盘事件
-- ============================================================
function CharacterSelect:keypressed(key)
    if key == "left" or key == "a" then
        _selected = math.max(1, _selected - 1)

    elseif key == "right" or key == "d" then
        _selected = math.min(#CHAR_ORDER, _selected + 1)

    elseif key == "return" or key == "kpenter" then
        local charId = CHAR_ORDER[_selected]
        -- 写入全局选中角色
        _G._selectedCharId = charId
        -- 触发可选回调
        if _onSelect then
            _onSelect(charId)
        end
        -- 推入场景选择界面
        local StateManager = require("src.states.stateManager")
        StateManager.push("sceneSelect")

    elseif key == "escape" then
        local StateManager = require("src.states.stateManager")
        StateManager.pop()
    end
end

return CharacterSelect
