--[[
    src/ui/components.lua
    通用 UI 组件库 — Phase 11
    封装进度条、面板、图标、浮窗、徽章等常用 UI 元素
    所有函数调用前后保证颜色归位为 (1,1,1,1)
]]

local Font = require("src.utils.font")

local Components = {}

-- ============================================================
-- 颜色规范常量
-- ============================================================
Components.COLORS = {
    HP          = { 0.85, 0.2,  0.2  },   -- 血量红
    HP_LOW      = { 1.0,  0.1,  0.1  },   -- 低血量深红
    EXP         = { 0.2,  0.8,  0.4  },   -- 经验绿
    GOLD        = { 1.0,  0.85, 0.2  },   -- 金色
    SHIELD      = { 0.5,  0.3,  0.95 },   -- 护盾蓝紫
    SOUL        = { 0.5,  0.3,  0.9  },   -- 灵魂紫
    WHITE       = { 1.0,  1.0,  1.0  },   -- 白色
    GRAY        = { 0.5,  0.5,  0.5  },   -- 灰色
    DARK_BG     = { 0.05, 0.05, 0.08 },   -- 深色背景
    PANEL_BG    = { 0.1,  0.1,  0.14 },   -- 面板背景
    BORDER      = { 0.35, 0.35, 0.45 },   -- 边框灰
    SUCCESS     = { 0.3,  1.0,  0.5  },   -- 成功绿
    WARN        = { 1.0,  0.7,  0.1  },   -- 警告橙
    REVIVE      = { 0.9,  0.3,  0.4  },   -- 复活心形红
}

-- ============================================================
-- 字体规范常量
-- ============================================================
Components.FONT_SIZE = {
    TINY   = 10,
    SMALL  = 12,
    NORMAL = 14,
    MEDIUM = 16,
    LARGE  = 20,
    TITLE  = 28,
    BIG    = 40,
}

-- ============================================================
-- Components.drawBar — 进度条
-- @param x, y      — 左上角坐标
-- @param w, h      — 宽高
-- @param ratio     — 进度（0~1）
-- @param fgColor   — 前景色 {r,g,b} 或 {r,g,b,a}
-- @param bgColor   — 背景色（可选，默认深灰）
-- @param radius    — 圆角半径（可选，默认 2）
-- ============================================================
function Components.drawBar(x, y, w, h, ratio, fgColor, bgColor, radius)
    ratio  = math.max(0, math.min(1, ratio or 0))
    radius = radius or 2
    bgColor = bgColor or { 0.15, 0.15, 0.18, 0.85 }

    -- 背景
    love.graphics.setColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 1)
    love.graphics.rectangle("fill", x, y, w, h, radius, radius)

    -- 前景
    if ratio > 0 and fgColor then
        love.graphics.setColor(fgColor[1], fgColor[2], fgColor[3], fgColor[4] or 1)
        love.graphics.rectangle("fill", x, y, w * ratio, h, radius, radius)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================
-- Components.drawBarWithBorder — 带边框的进度条
-- ============================================================
function Components.drawBarWithBorder(x, y, w, h, ratio, fgColor, bgColor, borderColor, radius)
    Components.drawBar(x, y, w, h, ratio, fgColor, bgColor, radius)
    local bc = borderColor or Components.COLORS.BORDER
    love.graphics.setColor(bc[1], bc[2], bc[3], bc[4] or 0.8)
    love.graphics.rectangle("line", x, y, w, h, radius or 2, radius or 2)
    love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================
-- Components.drawPanel — 带可选标题的面板
-- @param x, y      — 左上角
-- @param w, h      — 宽高
-- @param title     — 标题文字（可选）
-- @param alpha     — 整体透明度（可选，默认 0.9）
-- @param titleColor — 标题颜色（可选）
-- ============================================================
function Components.drawPanel(x, y, w, h, title, alpha, titleColor)
    alpha = alpha or 0.9
    local bg = Components.COLORS.PANEL_BG

    -- 面板背景
    love.graphics.setColor(bg[1], bg[2], bg[3], alpha)
    love.graphics.rectangle("fill", x, y, w, h, 6, 6)

    -- 边框
    local bc = Components.COLORS.BORDER
    love.graphics.setColor(bc[1], bc[2], bc[3], alpha * 0.8)
    love.graphics.rectangle("line", x, y, w, h, 6, 6)

    -- 标题
    if title and title ~= "" then
        local tc = titleColor or Components.COLORS.GOLD
        Font.set(Components.FONT_SIZE.SMALL)
        love.graphics.setColor(tc[1], tc[2], tc[3], alpha)
        love.graphics.printf(title, x, y + 6, w, "center")
        Font.reset()
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================
-- Components.drawIcon — 小方块图标（格子样式）
-- @param x, y      — 左上角
-- @param size      — 边长（像素）
-- @param color     — 图标背景色
-- @param text      — 图标内文字（可选，1~2 字）
-- @param textColor — 文字颜色（可选）
-- ============================================================
function Components.drawIcon(x, y, size, color, text, textColor)
    -- 图标背景
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 0.85)
    love.graphics.rectangle("fill", x, y, size, size, 3, 3)

    -- 边框
    love.graphics.setColor(1, 1, 1, 0.3)
    love.graphics.rectangle("line", x, y, size, size, 3, 3)

    -- 文字
    if text and text ~= "" then
        local tc = textColor or { 1, 1, 1 }
        love.graphics.setColor(tc[1], tc[2], tc[3], tc[4] or 1)
        local fs = size >= 28 and Components.FONT_SIZE.SMALL or Components.FONT_SIZE.TINY
        Font.set(fs)
        love.graphics.printf(text, x, y + size * 0.3, size, "center")
        Font.reset()
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================
-- Components.drawToast — 浮窗文字提示
-- @param x, y      — 中心点 x，顶部 y
-- @param w         — 宽度
-- @param text      — 内容文字
-- @param alpha     — 透明度（0~1）
-- @param color     — 文字颜色（可选）
-- ============================================================
function Components.drawToast(x, y, w, text, alpha, color)
    alpha = alpha or 1.0
    -- 背景
    love.graphics.setColor(0.08, 0.08, 0.12, alpha * 0.85)
    love.graphics.rectangle("fill", x - w/2, y, w, 28, 4, 4)
    -- 边框
    love.graphics.setColor(0.4, 0.4, 0.5, alpha * 0.7)
    love.graphics.rectangle("line", x - w/2, y, w, 28, 4, 4)
    -- 文字
    local tc = color or { 1, 1, 1 }
    love.graphics.setColor(tc[1], tc[2], tc[3], alpha)
    Font.set(Components.FONT_SIZE.SMALL)
    love.graphics.printf(text, x - w/2, y + 7, w, "center")
    Font.reset()
    love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================
-- Components.drawBadge — 小徽章（圆角矩形 + 文字）
-- @param x, y      — 左上角
-- @param text      — 徽章文字
-- @param color     — 背景色
-- ============================================================
function Components.drawBadge(x, y, text, color)
    Font.set(Components.FONT_SIZE.TINY)
    local tw = love.graphics.getFont():getWidth(text)
    local w  = tw + 8
    local h  = 14
    local bc = color or Components.COLORS.GOLD
    love.graphics.setColor(bc[1], bc[2], bc[3], 0.85)
    love.graphics.rectangle("fill", x, y, w, h, 3, 3)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.print(text, x + 4, y + 2)
    Font.reset()
    love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================
-- Components.drawHeartIcons — 心形图标列表（复活次数）
-- @param x, y      — 起始左上角
-- @param count     — 显示数量
-- @param size      — 每颗心大小（默认 14）
-- ============================================================
function Components.drawHeartIcons(x, y, count, size)
    size = size or 14
    local gap = size + 3
    for i = 1, count do
        local hx = x + (i - 1) * gap
        -- 简单心形：两个错位圆 + 三角形
        love.graphics.setColor(0.9, 0.2, 0.3, 0.95)
        love.graphics.circle("fill", hx + size * 0.3,  y + size * 0.3, size * 0.28)
        love.graphics.circle("fill", hx + size * 0.7,  y + size * 0.3, size * 0.28)
        -- 填充下半部分三角形
        local pts = {
            hx,            y + size * 0.45,
            hx + size,     y + size * 0.45,
            hx + size/2,   y + size,
        }
        love.graphics.polygon("fill", pts)
        -- 遮住圆和三角的间隙（填充中间矩形）
        love.graphics.rectangle("fill", hx + size*0.02, y + size*0.15, size*0.96, size*0.3)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================
-- Components.drawSoulIcon — 灵魂图标（六芒星形状）
-- @param x, y      — 中心坐标
-- @param size      — 半径
-- ============================================================
function Components.drawSoulIcon(x, y, size)
    size = size or 7
    love.graphics.setColor(0.6, 0.3, 0.95, 0.9)
    -- 六边形近似
    local pts = {}
    for i = 0, 5 do
        local angle = math.pi / 3 * i - math.pi / 6
        table.insert(pts, x + math.cos(angle) * size)
        table.insert(pts, y + math.sin(angle) * size)
    end
    love.graphics.polygon("fill", pts)
    -- 内圈
    love.graphics.setColor(0.85, 0.6, 1.0, 0.7)
    local pts2 = {}
    for i = 0, 5 do
        local angle = math.pi / 3 * i
        table.insert(pts2, x + math.cos(angle) * size * 0.5)
        table.insert(pts2, y + math.sin(angle) * size * 0.5)
    end
    love.graphics.polygon("fill", pts2)
    love.graphics.setColor(1, 1, 1, 1)
end

return Components
