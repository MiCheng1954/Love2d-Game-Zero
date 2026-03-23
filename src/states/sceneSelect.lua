--[[
    src/states/sceneSelect.lua
    场景选择界面 — Phase 12
    ← → 切换场景卡片，Enter 确认进入，ESC 返回主菜单
    卡片布局：3 张横排，选中卡片有高亮边框 + 轻微缩放效果
]]

local Font         = require("src.utils.font")
local SceneManager = require("src.systems.sceneManager")
local SceneConfig  = require("config.scenes")

local SceneSelect = {}

-- ============================================================
-- 场景列表（定义顺序 = 卡片顺序）
-- ============================================================
local SCENE_ORDER = { "plains", "arena" }

-- ============================================================
-- 内部状态
-- ============================================================
local _selected   = 1     -- 当前选中索引（1-based）
local _time       = 0     -- 动画时间
local _fadeIn     = 0     -- 淡入（0→1 秒）
local _confirmed  = false -- 已确认，等待淡出

-- ============================================================
-- 布局常量
-- ============================================================
local CARD_W      = 280
local CARD_H      = 340
local CARD_GAP    = 40
local CARD_Y      = 200   -- 卡片顶部 y（屏幕坐标）
local SCREEN_W    = 1280
local SCREEN_H    = 720

-- 难度颜色
local DIFF_COLORS = {
    ["scene.plains.difficulty"]  = { 0.3, 0.85, 0.4  },  -- 绿色：简单
    ["scene.arena.difficulty"]   = { 0.95, 0.65, 0.1 },  -- 橙色：中等
    ["scene.dungeon.difficulty"] = { 0.9,  0.25, 0.25},  -- 红色：挑战
}

-- ============================================================
-- 辅助：计算第 i 张卡片的中心 x
-- ============================================================
local function cardCenterX(i)
    local totalW = #SCENE_ORDER * CARD_W + (#SCENE_ORDER - 1) * CARD_GAP
    local startX = (SCREEN_W - totalW) / 2 + CARD_W / 2
    return startX + (i - 1) * (CARD_W + CARD_GAP)
end

-- ============================================================
-- 生命周期
-- ============================================================
function SceneSelect:enter(data)
    _selected  = 1
    _time      = 0
    _fadeIn    = 0
    _confirmed = false
end

function SceneSelect:exit()
end

-- ============================================================
-- 更新
-- ============================================================
function SceneSelect:update(dt)
    _time   = _time + dt
    _fadeIn = math.min(_fadeIn + dt * 2, 1.0)   -- 0.5s 淡入

    if _confirmed then
        _fadeIn = _fadeIn - dt * 3    -- 快速淡出
        if _fadeIn <= 0 then
            -- 执行切换
            local StateManager = require("src.states.stateManager")
            StateManager.switch("game")
        end
    end
end

-- ============================================================
-- 绘制单张场景卡片
-- ============================================================
local function drawCard(i, cfg, isSelected, time, globalAlpha)
    local cx   = cardCenterX(i)
    local cy   = CARD_Y + CARD_H / 2
    local scale = isSelected and (1.0 + 0.018 * math.sin(time * 2.5)) or 0.95
    local w    = CARD_W * scale
    local h    = CARD_H * scale
    local x    = cx - w / 2
    local y    = cy - h / 2

    -- ---- 卡片阴影 ----
    love.graphics.setColor(0, 0, 0, 0.35 * globalAlpha)
    love.graphics.rectangle("fill", x + 6, y + 8, w, h, 10, 10)

    -- ---- 卡片主体背景 ----
    if isSelected then
        love.graphics.setColor(0.12, 0.11, 0.20, 0.92 * globalAlpha)
    else
        love.graphics.setColor(0.08, 0.08, 0.14, 0.80 * globalAlpha)
    end
    love.graphics.rectangle("fill", x, y, w, h, 10, 10)

    -- ---- 选中高亮边框 ----
    if isSelected then
        local pulse = (math.sin(time * 3.0) + 1) * 0.5
        love.graphics.setColor(0.55, 0.35, 1.0, (0.7 + 0.25 * pulse) * globalAlpha)
        love.graphics.setLineWidth(3)
    else
        love.graphics.setColor(0.3, 0.28, 0.40, 0.5 * globalAlpha)
        love.graphics.setLineWidth(1.5)
    end
    love.graphics.rectangle("line", x, y, w, h, 10, 10)
    love.graphics.setLineWidth(1)

    -- ---- 场景名称 ----
    local nameStr = T(cfg.nameKey) or cfg.id
    Font.set(22)
    if isSelected then
        local pulse = (math.sin(time * 2.5) + 1) * 0.5
        love.graphics.setColor(0.85 + 0.12 * pulse, 0.75, 1.0, globalAlpha)
    else
        love.graphics.setColor(0.65, 0.62, 0.78, globalAlpha)
    end
    love.graphics.printf(nameStr, x, y + 20, w, "center")
    Font.reset()

    -- ---- 分隔线 ----
    love.graphics.setColor(0.35, 0.30, 0.50, 0.5 * globalAlpha)
    love.graphics.setLineWidth(1)
    love.graphics.line(x + 20, y + 52, x + w - 20, y + 52)

    -- ---- 场景预览（简单几何图案）----
    local previewX = x + w / 2
    local previewY = y + 110
    local previewR = 48
    love.graphics.setScissor(math.floor(x + 4), math.floor(y + 55), math.floor(w - 8), 110)
    if cfg.id == "plains" then
        -- 绿色草地感
        love.graphics.setColor(0.08, 0.18, 0.08, 0.7 * globalAlpha)
        love.graphics.rectangle("fill", x + 4, y + 55, w - 8, 110)
        love.graphics.setColor(0.18, 0.45, 0.18, 0.6 * globalAlpha)
        for j = 1, 6 do
            local ox = x + 20 + (j - 1) * (w - 40) / 5
            love.graphics.circle("fill", ox, previewY + 15, 14 + math.sin(time * 1.2 + j) * 2)
        end
    elseif cfg.id == "arena" then
        -- 深灰竞技场方形边框
        love.graphics.setColor(0.10, 0.10, 0.14, 0.85 * globalAlpha)
        love.graphics.rectangle("fill", x + 4, y + 55, w - 8, 110)
        love.graphics.setColor(0.28, 0.22, 0.18, 0.9 * globalAlpha)
        love.graphics.rectangle("fill", x + 20, y + 65, w - 40, 90)
        love.graphics.setColor(0.85, 0.20, 0.15, 0.5 * globalAlpha)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", x + 20, y + 65, w - 40, 90)
        love.graphics.setLineWidth(1)
    elseif cfg.id == "dungeon" then
        -- 深色地牢石块感
        love.graphics.setColor(0.06, 0.06, 0.08, 0.9 * globalAlpha)
        love.graphics.rectangle("fill", x + 4, y + 55, w - 8, 110)
        love.graphics.setColor(0.18, 0.16, 0.22, 0.7 * globalAlpha)
        local cellS = 22
        for row = 0, 4 do
            for col = 0, 11 do
                if (row + col) % 2 == 0 then
                    love.graphics.rectangle("fill",
                        x + 4  + col * cellS,
                        y + 55 + row * cellS,
                        cellS - 1, cellS - 1)
                end
            end
        end
        love.graphics.setColor(0.45, 0.35, 0.60, 0.4 * globalAlpha)
        love.graphics.setLineWidth(1.5)
        love.graphics.rectangle("line", x + 20, y + 65, w - 40, 90)
        love.graphics.setLineWidth(1)
    end
    love.graphics.setScissor()

    -- ---- 难度标签 ----
    local diffKey   = cfg.difficultyKey
    local diffStr   = T(diffKey) or "?"
    local diffColor = DIFF_COLORS[diffKey] or { 0.7, 0.7, 0.7 }
    love.graphics.setColor(diffColor[1] * 0.25, diffColor[2] * 0.25, diffColor[3] * 0.25, 0.85 * globalAlpha)
    love.graphics.rectangle("fill", x + 20, y + 175, w - 40, 24, 4, 4)
    love.graphics.setColor(diffColor[1], diffColor[2], diffColor[3], globalAlpha)
    Font.set(13)
    love.graphics.printf(diffStr, x + 20, y + 178, w - 40, "center")
    Font.reset()

    -- ---- 场景描述 ----
    local descStr = T(cfg.descKey) or ""
    Font.set(13)
    love.graphics.setColor(0.68, 0.65, 0.78, 0.85 * globalAlpha)
    love.graphics.printf(descStr, x + 14, y + 210, w - 28, "left")
    Font.reset()

    -- ---- 掉落倍率角标（Arena/Dungeon 特殊标注）----
    local dm = cfg.dropMultiplier
    if dm and (dm.soul ~= 1.0 or dm.exp ~= 1.0) then
        Font.set(11)
        love.graphics.setColor(0.95, 0.85, 0.30, 0.8 * globalAlpha)
        local lines = {}
        if dm.soul ~= 1.0 then
            lines[#lines+1] = string.format("灵魂 ×%.1f", dm.soul)
        end
        if dm.exp ~= 1.0 then
            lines[#lines+1] = string.format("经验 ×%.1f", dm.exp)
        end
        love.graphics.printf(table.concat(lines, "  "), x + 14, y + h - 36, w - 28, "right")
        Font.reset()
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================
-- 绘制
-- ============================================================
function SceneSelect:draw()
    local globalAlpha = math.max(0, math.min(1, _fadeIn))

    -- 渐变背景（暗色调）
    local steps = 16
    local sh    = SCREEN_H / steps
    for i = 0, steps - 1 do
        local t = i / (steps - 1)
        love.graphics.setColor(0.04 + 0.03 * t, 0.04 - 0.01 * t, 0.10 + 0.04 * t, 1)
        love.graphics.rectangle("fill", 0, i * sh, SCREEN_W, sh + 1)
    end

    -- 标题
    Font.set(26)
    love.graphics.setColor(0.85, 0.78, 1.0, globalAlpha)
    love.graphics.printf(T("scene_select.title") or "选择场景", 0, 140, SCREEN_W, "center")
    Font.reset()

    -- 绘制卡片
    for i, sceneId in ipairs(SCENE_ORDER) do
        local cfg = SceneConfig[sceneId]
        if cfg then
            drawCard(i, cfg, (i == _selected), _time, globalAlpha)
        end
    end

    -- 当前选中名称高亮提示
    local selCfg = SceneConfig[SCENE_ORDER[_selected]]
    if selCfg then
        Font.set(14)
        love.graphics.setColor(0.7, 0.65, 0.90, 0.7 * globalAlpha)
        local hint = T("scene_select.hint") or "← → 切换   Enter 确认   ESC 返回"
        love.graphics.printf(hint, 0, CARD_Y + CARD_H + 30, SCREEN_W, "center")
        Font.reset()
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================
-- 键盘事件
-- ============================================================
function SceneSelect:keypressed(key)
    if _confirmed then return end

    if key == "left" or key == "a" then
        _selected = math.max(1, _selected - 1)
    elseif key == "right" or key == "d" then
        _selected = math.min(#SCENE_ORDER, _selected + 1)
    elseif key == "return" or key == "space" then
        local sceneId = SCENE_ORDER[_selected]
        SceneManager.set(sceneId)
        _confirmed = true
    elseif key == "escape" then
        local StateManager = require("src.states.stateManager")
        StateManager.pop()
    end
end

return SceneSelect
