--[[
    src/ui/triggerUI.lua
    触发器奖励展示界面 — Phase 11
    作为 StateManager.push 覆盖层弹出，展示固定奖励内容

    进入方式：
        StateManager.push("triggerUI", {
            triggerType = "stat" | "weapon" | "skill" | "bag" | "soul",
            items       = { { icon, label, value }, ... },  -- 奖励条目列表
            onClose     = function() ... end,               -- 关闭回调
        })

    动画：
        - 弹入：面板从屏幕下方弹入（translateY + 弹性缓动）
        - 渐显：整体透明度从 0 渐变到 1
        - 自动关闭：3 秒后或任意键关闭
]]

local Font       = require("src.utils.font")
local Components = require("src.ui.components")

local TriggerUI = {}

-- ============================================================
-- 内部状态
-- ============================================================
local _data       = nil    -- enter 时接收的数据
local _timer      = 0      -- 自动关闭倒计时
local _autoClose  = 3.0    -- 自动关闭时长（秒）
local _animTimer  = 0      -- 动画计时（秒）
local _animIn     = 0.35   -- 弹入动画时长（秒）
local _closing    = false  -- 是否正在关闭（淡出中）
local _closeTimer = 0      -- 淡出计时
local _closeAnim  = 0.2    -- 淡出时长（秒）

-- 类型对应颜色
local TYPE_COLORS = {
    stat   = { 0.3,  0.8,  1.0  },
    weapon = { 1.0,  0.6,  0.2  },
    skill  = { 0.6,  0.3,  0.95 },
    bag    = { 0.3,  0.9,  0.5  },
    soul   = { 0.7,  0.4,  1.0  },
}

-- ============================================================
-- 弹性缓动函数（easeOutBack）
-- @param t — 进度 0~1
-- @return  — 缓动值 0~1（会略微超出 1 产生弹性感）
-- ============================================================
local function easeOutBack(t)
    local c1 = 1.70158
    local c3 = c1 + 1
    return 1 + c3 * (t - 1)^3 + c1 * (t - 1)^2
end

-- ============================================================
-- 进入
-- ============================================================
function TriggerUI:enter(data)
    _data       = data or {}
    _timer      = _autoClose
    _animTimer  = 0
    _closing    = false
    _closeTimer = 0
end

-- ============================================================
-- 退出
-- ============================================================
function TriggerUI:exit()
    _data = nil
end

-- ============================================================
-- 更新
-- ============================================================
function TriggerUI:update(dt)
    if _closing then
        _closeTimer = _closeTimer + dt
        if _closeTimer >= _closeAnim then
            -- 动画结束，真正关闭
            local StateManager = require("src.states.stateManager")
            if _data and _data.onClose then _data.onClose() end
            StateManager.pop()
        end
        return
    end

    -- 弹入动画推进
    _animTimer = math.min(_animTimer + dt, _animIn)

    -- 自动关闭倒计时（弹入完成后才开始）
    if _animTimer >= _animIn then
        _timer = _timer - dt
        if _timer <= 0 then
            _closing = true
            _closeTimer = 0
        end
    end
end

-- ============================================================
-- 绘制
-- ============================================================
function TriggerUI:draw()
    if not _data then return end

    local PANEL_W = 500
    local PANEL_H = 300
    local cx      = 1280 / 2
    local cy      = 720  / 2

    -- ---- 计算动画参数 ----
    local animProgress = _animIn > 0 and (_animTimer / _animIn) or 1
    animProgress = math.min(animProgress, 1)

    -- 淡出进度
    local fadeOut = 1.0
    if _closing then
        fadeOut = 1.0 - math.min(_closeTimer / _closeAnim, 1.0)
    end

    -- 透明度：弹入时渐显，关闭时渐隐
    local alpha = math.min(animProgress * 1.5, 1.0) * fadeOut

    -- Y 偏移：从 +120px（屏幕下方）弹到 0（居中）
    local yOffset = (1 - easeOutBack(animProgress)) * 120

    local px = cx - PANEL_W / 2
    local py = cy - PANEL_H / 2 + yOffset

    -- ---- 背景遮罩 ----
    love.graphics.setColor(0, 0, 0, 0.55 * alpha)
    love.graphics.rectangle("fill", 0, 0, 1280, 720)

    -- ---- 面板主体 ----
    local triggerType = _data.triggerType or "stat"
    local typeColor   = TYPE_COLORS[triggerType] or TYPE_COLORS.stat

    -- 面板背景
    love.graphics.setColor(0.06, 0.06, 0.1, 0.96 * alpha)
    love.graphics.rectangle("fill", px, py, PANEL_W, PANEL_H, 10, 10)

    -- 顶部装饰色条
    love.graphics.setColor(typeColor[1], typeColor[2], typeColor[3], alpha)
    love.graphics.rectangle("fill", px, py, PANEL_W, 6, 10, 10)
    love.graphics.rectangle("fill", px, py, PANEL_W, 3)  -- 底边修正为直角

    -- 边框
    love.graphics.setColor(typeColor[1] * 0.7, typeColor[2] * 0.7, typeColor[3] * 0.7, alpha * 0.8)
    love.graphics.rectangle("line", px, py, PANEL_W, PANEL_H, 10, 10)

    -- ---- 标题 ----
    Font.set(22)
    love.graphics.setColor(typeColor[1], typeColor[2], typeColor[3], alpha)
    love.graphics.printf(T("trigger.title") or "获得奖励", px, py + 18, PANEL_W, "center")

    -- 类型标签
    local typeLabel = T("trigger.type." .. triggerType) or triggerType
    Font.set(13)
    love.graphics.setColor(1, 1, 1, alpha * 0.75)
    love.graphics.printf("[ " .. typeLabel .. " ]", px, py + 46, PANEL_W, "center")

    -- 分割线
    love.graphics.setColor(typeColor[1], typeColor[2], typeColor[3], alpha * 0.4)
    love.graphics.line(px + 30, py + 68, px + PANEL_W - 30, py + 68)

    -- ---- 奖励条目 ----
    local items = _data.items or {}
    local itemY = py + 80
    local ITEM_H = 36

    for i, item in ipairs(items) do
        local iy = itemY + (i - 1) * ITEM_H

        -- 条目背景（交替淡色）
        if i % 2 == 0 then
            love.graphics.setColor(1, 1, 1, 0.04 * alpha)
            love.graphics.rectangle("fill", px + 20, iy, PANEL_W - 40, ITEM_H - 2, 4, 4)
        end

        -- 图标（小方块）
        if item.iconColor then
            local ic = item.iconColor
            love.graphics.setColor(ic[1], ic[2], ic[3], alpha * 0.9)
            love.graphics.rectangle("fill", px + 30, iy + 8, 20, 20, 3, 3)
            love.graphics.setColor(1, 1, 1, alpha * 0.5)
            love.graphics.rectangle("line", px + 30, iy + 8, 20, 20, 3, 3)
        else
            -- 默认：类型颜色圆点
            love.graphics.setColor(typeColor[1], typeColor[2], typeColor[3], alpha * 0.85)
            love.graphics.circle("fill", px + 40, iy + 18, 8)
        end

        -- 标签
        Font.set(14)
        love.graphics.setColor(1, 1, 1, alpha * 0.9)
        love.graphics.print(item.label or "", px + 60, iy + 11)

        -- 数值（右对齐）
        if item.value then
            Font.set(14)
            love.graphics.setColor(typeColor[1], typeColor[2], typeColor[3], alpha)
            love.graphics.printf(tostring(item.value), px, iy + 11, PANEL_W - 30, "right")
        end
    end

    -- ---- 底部倒计时 / 提示 ----
    local footerY = py + PANEL_H - 36
    Font.set(12)
    if _animTimer >= _animIn and not _closing then
        -- 显示倒计时进度条
        local closeRatio = math.max(0, _timer / _autoClose)
        love.graphics.setColor(0.2, 0.2, 0.25, alpha * 0.8)
        love.graphics.rectangle("fill", px + 20, footerY + 16, PANEL_W - 40, 4, 2, 2)
        love.graphics.setColor(typeColor[1], typeColor[2], typeColor[3], alpha * 0.7)
        love.graphics.rectangle("fill", px + 20, footerY + 16, (PANEL_W - 40) * closeRatio, 4, 2, 2)

        love.graphics.setColor(0.6, 0.6, 0.6, alpha * 0.8)
        local hint = string.format(T("trigger.auto_close") or "%.1f 秒后自动关闭", math.max(0, _timer))
        love.graphics.printf(hint, px, footerY, PANEL_W, "center")
    else
        love.graphics.setColor(0.5, 0.5, 0.55, alpha * 0.7)
        love.graphics.printf(T("trigger.confirm") or "按任意键确认", px, footerY, PANEL_W, "center")
    end

    Font.reset()
    love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================
-- 键盘事件：任意键提前关闭
-- ============================================================
function TriggerUI:keypressed(key)
    if not _closing and _animTimer >= _animIn then
        _closing = true
        _closeTimer = 0
    end
end

return TriggerUI
