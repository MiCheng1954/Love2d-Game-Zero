--[[
    src/states/legacySelect.lua
    传承技能三选一界面
    Phase 10：玩家选择传承后，写入 data/legacy.json，再跳转死亡结算界面
]]

local LegacySelect = {}

local Font          = require("src.utils.font")
local LegacyManager = require("src.systems.legacyManager")

-- 界面布局常量
local SCREEN_W  = 1280
local SCREEN_H  = 720
local CARD_W    = 310
local CARD_H    = 340
local CARD_GAP  = 40
local CARD_Y    = 180

-- 进入界面
-- @param data: { player, summaryData, activeSynergies, onDone }
function LegacySelect:enter(data)
    self._data       = data or {}
    self._player     = data.player
    self._onDone     = data.onDone
    self._selected   = 1
    self._confirmed  = false
    self._animTimer  = 0

    -- 根据本局激活的羁绊抽取 3 张传承候选
    self._candidates = LegacyManager.drawCandidates(data.activeSynergies or {})

    -- 若不足 3 张（理论上不会发生），补 nil 占位
    while #self._candidates < 3 do
        table.insert(self._candidates, nil)
    end
end

-- 退出界面
function LegacySelect:exit()
    self._data       = nil
    self._player     = nil
    self._onDone     = nil
    self._candidates = {}
    self._confirmed  = false
end

-- 每帧更新
function LegacySelect:update(dt)
    self._animTimer = self._animTimer + dt
end

-- 每帧绘制
function LegacySelect:draw()
    -- 深色半透明背景
    love.graphics.setBackgroundColor(0.04, 0.03, 0.08)

    -- 顶部标题区背景
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", 0, 0, SCREEN_W, 160)

    -- 主标题
    Font.set(40)
    love.graphics.setColor(1.0, 0.85, 0.2)
    love.graphics.printf(T("legacy_select.title"), 0, 40, SCREEN_W, "center")

    -- 副标题
    Font.set(17)
    love.graphics.setColor(0.75, 0.65, 0.9)
    love.graphics.printf(T("legacy_select.subtitle"), 0, 100, SCREEN_W, "center")

    -- 金色分隔线
    love.graphics.setColor(1.0, 0.85, 0.2, 0.4)
    love.graphics.rectangle("fill", 100, 148, SCREEN_W - 200, 1)

    -- 三张卡片
    local totalW = CARD_W * 3 + CARD_GAP * 2
    local startX = (SCREEN_W - totalW) / 2

    for i = 1, 3 do
        local legacy     = self._candidates[i]
        local cardX      = startX + (i - 1) * (CARD_W + CARD_GAP)
        local isSelected = (i == self._selected)
        -- 入场动画：依次从下方浮入
        local delay  = (i - 1) * 0.12
        local t      = math.max(0, math.min(1, (self._animTimer - delay) / 0.4))
        local eased  = 1 - (1 - t) * (1 - t)
        local offY   = (1 - eased) * 80

        love.graphics.push()
        love.graphics.translate(0, offY)
        love.graphics.setColor(1, 1, 1, eased)
        self:_drawCard(cardX, CARD_Y, legacy, isSelected)
        love.graphics.pop()
    end

    -- 操作提示
    Font.set(15)
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.printf(T("legacy_select.hint"), 0, CARD_Y + CARD_H + 30, SCREEN_W, "center")

    Font.reset()
    love.graphics.setColor(1, 1, 1, 1)
end

-- 绘制单张传承卡片
function LegacySelect:_drawCard(x, y, legacy, isSelected)
    local w = CARD_W
    local h = CARD_H

    if not legacy then
        -- 空卡
        love.graphics.setColor(0.1, 0.1, 0.12)
        love.graphics.rectangle("fill", x, y, w, h, 10, 10)
        return
    end

    -- 根据类别决定主题色
    local categoryColors = {
        ["伤害"] = { 1.0, 0.4, 0.3 },
        ["科技"] = { 0.3, 0.8, 1.0 },
        ["生存"] = { 0.4, 1.0, 0.5 },
        ["爆发"] = { 1.0, 0.65, 0.15 },
        ["经济"] = { 0.8, 0.6, 1.0 },
    }
    local tc = categoryColors[legacy.category] or { 0.8, 0.8, 0.8 }

    -- 选中时放大
    local scale  = isSelected and 1.04 or 1.0
    local scaleOffX = isSelected and -w * 0.02 or 0
    local scaleOffY = isSelected and -h * 0.02 or 0

    love.graphics.push()
    love.graphics.translate(x + scaleOffX, y + scaleOffY)
    love.graphics.scale(scale, scale)

    -- 卡片背景
    if isSelected then
        love.graphics.setColor(tc[1] * 0.12, tc[2] * 0.12, tc[3] * 0.12, 0.97)
    else
        love.graphics.setColor(0.06, 0.06, 0.10, 0.92)
    end
    love.graphics.rectangle("fill", 0, 0, w, h, 10, 10)

    -- 顶部类别色带
    love.graphics.setColor(tc[1], tc[2], tc[3], isSelected and 0.85 or 0.45)
    love.graphics.rectangle("fill", 0, 0, w, 8, 10, 10)
    love.graphics.rectangle("fill", 0, 4, w, 4)   -- 下半填充去圆角

    -- 边框
    local borderAlpha = isSelected and 1.0 or 0.35
    if isSelected then
        -- 外发光
        love.graphics.setColor(tc[1], tc[2], tc[3], 0.2)
        love.graphics.setLineWidth(5)
        love.graphics.rectangle("line", -2, -2, w + 4, h + 4, 11, 11)
    end
    love.graphics.setColor(tc[1], tc[2], tc[3], borderAlpha)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", 0, 0, w, h, 10, 10)
    love.graphics.setLineWidth(1)

    -- 「传承」金色角标（左上）
    love.graphics.setColor(1.0, 0.85, 0.2, 0.9)
    Font.set(11)
    love.graphics.print("传承", 10, 14)

    -- 类别标签（右上）
    Font.set(12)
    love.graphics.setColor(tc[1], tc[2], tc[3], 0.9)
    love.graphics.printf(T("legacy_select.category"):format(legacy.category), 0, 14, w - 10, "right")

    -- 传承名称
    Font.set(22)
    love.graphics.setColor(1.0, 0.95, 0.85)
    love.graphics.printf(T(legacy.nameKey), 0, 58, w, "center")

    -- 图标区（用几何形状绘制）
    self:_drawLegacyIcon(legacy, w / 2, 130, tc, isSelected)

    -- 分隔线
    love.graphics.setColor(tc[1], tc[2], tc[3], 0.2)
    love.graphics.rectangle("fill", 20, 185, w - 40, 1)

    -- 效果描述
    Font.set(15)
    love.graphics.setColor(0.9, 0.9, 0.9, isSelected and 1.0 or 0.75)
    love.graphics.printf(T(legacy.descKey), 18, 196, w - 36, "center")

    -- 选中底部脉冲指示
    if isSelected then
        local pulse = 0.7 + 0.3 * math.sin(love.timer.getTime() * 3.5)
        Font.set(16)
        love.graphics.setColor(tc[1], tc[2], tc[3], pulse)
        love.graphics.printf("▼ Enter 选择", 0, h - 36, w, "center")
    end

    love.graphics.pop()
end

-- 绘制传承图标（代码几何图案）
function LegacySelect:_drawLegacyIcon(legacy, cx, cy, tc, bright)
    local alpha = bright and 0.9 or 0.5
    love.graphics.setColor(tc[1], tc[2], tc[3], alpha)

    local cat = legacy.category
    if cat == "伤害" then
        -- 剑形：一条竖线 + 十字
        love.graphics.setLineWidth(3)
        love.graphics.line(cx, cy - 22, cx, cy + 22)
        love.graphics.line(cx - 12, cy - 8, cx + 12, cy - 8)
        love.graphics.setLineWidth(1)
        love.graphics.circle("fill", cx, cy - 22, 3)
    elseif cat == "科技" then
        -- 齿轮形：圆 + 8条短线
        love.graphics.circle("line", cx, cy, 16)
        for i = 0, 7 do
            local a = i * math.pi / 4
            love.graphics.line(
                cx + math.cos(a) * 16, cy + math.sin(a) * 16,
                cx + math.cos(a) * 22, cy + math.sin(a) * 22)
        end
        love.graphics.circle("fill", cx, cy, 5)
    elseif cat == "生存" then
        -- 盾牌形：五边形近似
        love.graphics.setLineWidth(2)
        local pts = {}
        for i = 0, 4 do
            local a = i * math.pi * 2 / 5 - math.pi / 2
            table.insert(pts, cx + math.cos(a) * 20)
            table.insert(pts, cy + math.sin(a) * 20)
        end
        table.insert(pts, pts[1])
        table.insert(pts, pts[2])
        love.graphics.line(pts)
        love.graphics.setLineWidth(1)
        love.graphics.circle("fill", cx, cy, 5)
    elseif cat == "爆发" then
        -- 闪电形：Z字
        love.graphics.setLineWidth(3)
        love.graphics.line(cx + 8, cy - 22, cx - 5, cy - 2, cx + 8, cy - 2, cx - 8, cy + 22)
        love.graphics.setLineWidth(1)
    else  -- 经济
        -- 星形：六角
        love.graphics.setLineWidth(2)
        for i = 0, 5 do
            local a1 = i * math.pi / 3
            local a2 = a1 + math.pi / 6
            love.graphics.line(
                cx + math.cos(a1) * 20, cy + math.sin(a1) * 20,
                cx + math.cos(a2) * 10, cy + math.sin(a2) * 10)
        end
        love.graphics.setLineWidth(1)
    end

    love.graphics.setLineWidth(1)
end

-- 键盘按下事件
function LegacySelect:keypressed(key)
    if self._confirmed then return end

    if key == "left" or key == "a" then
        self._selected = math.max(1, self._selected - 1)
    elseif key == "right" or key == "d" then
        self._selected = math.min(3, self._selected + 1)
    elseif key == "return" then
        local chosen = self._candidates[self._selected]
        if chosen then
            self._confirmed = true
            -- 保存传承
            LegacyManager.save(chosen)
            -- 回调（跳转死亡结算）
            if self._onDone then self._onDone() end
        end
    end
end

return LegacySelect
