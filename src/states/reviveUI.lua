--[[
    src/states/reviveUI.lua
    复活/传承二选一界面（全屏暂停 overlay，push 叠加在游戏状态之上）
    Phase 10：玩家死亡且还有复活机会时弹出，无倒计时，等待玩家操作
]]

local ReviveUI = {}

local Font = require("src.utils.font")

-- 界面布局常量
local SCREEN_W  = 1280
local SCREEN_H  = 720
local CARD_W    = 340
local CARD_H    = 300
local CARD_GAP  = 80
local CARD_Y    = 220

-- 选项定义
local OPTIONS = {
    {
        key      = "revive",
        titleKey = "revive.revive",
        descKey  = "revive.revive_desc",
        color    = { 0.3, 0.9, 0.5 },   -- 绿色：复活
        bgColor  = { 0.05, 0.2, 0.1 },
        borderColor = { 0.3, 0.9, 0.5 },
        icon     = "♻",
    },
    {
        key      = "legacy",
        titleKey = "revive.legacy",
        descKey  = "revive.legacy_desc",
        color    = { 1.0, 0.75, 0.2 },  -- 金色：传承
        bgColor  = { 0.2, 0.15, 0.03 },
        borderColor = { 1.0, 0.75, 0.2 },
        icon     = "◈",
    },
}

-- 进入界面
-- @param data: { player, summaryData, enemies, onRevive, onLegacy }
function ReviveUI:enter(data)
    self._data       = data or {}
    self._player     = data.player
    self._onRevive   = data.onRevive
    self._onLegacy   = data.onLegacy
    self._selected   = 1   -- 1=复活, 2=传承
    self._confirmed  = false
    self._animTimer  = 0    -- 入场动画计时
    self._shakeTimer = 0    -- 标题抖动
end

-- 退出界面
function ReviveUI:exit()
    self._data    = nil
    self._player  = nil
    self._onRevive = nil
    self._onLegacy = nil
    self._confirmed = false
end

-- 每帧更新
function ReviveUI:update(dt)
    self._animTimer  = self._animTimer + dt
    self._shakeTimer = self._shakeTimer + dt
end

-- 每帧绘制（叠加在游戏画面之上）
function ReviveUI:draw()
    -- 半透明黑色遮罩
    love.graphics.setColor(0, 0, 0, 0.82)
    love.graphics.rectangle("fill", 0, 0, SCREEN_W, SCREEN_H)

    -- 入场动画：从上方滑入
    local slideY = math.max(0, (1 - math.min(1, self._animTimer / 0.35)) * (-SCREEN_H * 0.15))

    love.graphics.push()
    love.graphics.translate(0, slideY)

    -- 警告标题
    local shake = math.sin(self._shakeTimer * 8) * 2
    Font.set(36)
    love.graphics.setColor(0.95, 0.3, 0.3)
    love.graphics.printf(T("revive.title"), shake, 70, SCREEN_W, "center")

    -- 副标题
    Font.set(18)
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.printf(T("revive.subtitle"), 0, 120, SCREEN_W, "center")

    -- 复活次数
    if self._player then
        Font.set(15)
        love.graphics.setColor(0.7, 0.9, 0.7)
        love.graphics.printf(
            T("revive.remaining"):format(self._player._revives or 1),
            0, 154, SCREEN_W, "center")
    end

    -- 两张卡片
    local totalW = CARD_W * 2 + CARD_GAP
    local startX = (SCREEN_W - totalW) / 2

    for i, opt in ipairs(OPTIONS) do
        local cardX   = startX + (i - 1) * (CARD_W + CARD_GAP)
        local isSelected = (i == self._selected)
        self:_drawCard(cardX, CARD_Y, opt, isSelected)
    end

    -- 操作提示
    Font.set(15)
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.printf(T("revive.hint"), 0, CARD_Y + CARD_H + 30, SCREEN_W, "center")

    love.graphics.pop()

    Font.reset()
    love.graphics.setColor(1, 1, 1, 1)
end

-- 绘制单张卡片
function ReviveUI:_drawCard(x, y, opt, isSelected)
    local w = CARD_W
    local h = CARD_H

    -- 选中时轻微放大
    local scale = isSelected and 1.03 or 1.0
    local offX  = isSelected and -w * 0.015 or 0
    local offY  = isSelected and -h * 0.015 or 0

    love.graphics.push()
    love.graphics.translate(x + offX, y + offY)
    love.graphics.scale(scale, scale)

    -- 卡片背景
    local bg = opt.bgColor
    if isSelected then
        love.graphics.setColor(bg[1] * 1.8, bg[2] * 1.8, bg[3] * 1.8, 0.95)
    else
        love.graphics.setColor(bg[1], bg[2], bg[3], 0.85)
    end
    love.graphics.rectangle("fill", 0, 0, w, h, 10, 10)

    -- 卡片边框
    local bc = opt.borderColor
    local borderAlpha = isSelected and 1.0 or 0.4
    if isSelected then
        -- 选中时发光边框（双重描边）
        love.graphics.setColor(bc[1], bc[2], bc[3], 0.25)
        love.graphics.setLineWidth(6)
        love.graphics.rectangle("line", -2, -2, w + 4, h + 4, 11, 11)
    end
    love.graphics.setColor(bc[1], bc[2], bc[3], borderAlpha)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", 0, 0, w, h, 10, 10)
    love.graphics.setLineWidth(1)

    -- 图标
    Font.set(40)
    love.graphics.setColor(bc[1], bc[2], bc[3], isSelected and 1.0 or 0.6)
    love.graphics.printf(opt.icon, 0, 28, w, "center")

    -- 标题
    Font.set(24)
    love.graphics.setColor(bc[1], bc[2], bc[3])
    love.graphics.printf(T(opt.titleKey), 0, 86, w, "center")

    -- 分隔线
    love.graphics.setColor(bc[1], bc[2], bc[3], 0.3)
    love.graphics.rectangle("fill", 20, 120, w - 40, 1)

    -- 描述（多行）
    Font.set(14)
    love.graphics.setColor(0.85, 0.85, 0.85, isSelected and 1.0 or 0.7)
    love.graphics.printf(T(opt.descKey), 20, 132, w - 40, "center")

    -- 选中指示器（底部箭头）
    if isSelected then
        Font.set(18)
        local pulse = 0.7 + 0.3 * math.sin(love.timer.getTime() * 4)
        love.graphics.setColor(bc[1], bc[2], bc[3], pulse)
        love.graphics.printf("▼ 确认", 0, h - 34, w, "center")
    end

    love.graphics.pop()
end

-- 键盘按下事件
function ReviveUI:keypressed(key)
    if self._confirmed then return end

    if key == "left" or key == "a" then
        self._selected = 1
    elseif key == "right" or key == "d" then
        self._selected = 2
    elseif key == "return" then
        self._confirmed = true
        if self._selected == 1 then
            -- 选择复活
            if self._onRevive then self._onRevive() end
        else
            -- 选择传承
            if self._onLegacy then self._onLegacy() end
        end
    end
end

return ReviveUI
