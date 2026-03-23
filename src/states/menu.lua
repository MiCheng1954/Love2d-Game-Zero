--[[
    src/states/menu.lua
    主菜单状态 — Phase 11
    特性：
        - 深色渐变背景（顶部深蓝→底部深紫）
        - 粒子漂浮动画（细小光点随机上升）
        - 动态标题（"ZERO" 波浪式呼吸光效）
        - 菜单项：开始游戏 / 设置（占位） / 退出游戏
        - 角色选择占位（灰色，无法选中）
        - 键盘 ↑↓ 导航，Enter/Space 确认
]]

local Font = require("src.utils.font")

local Menu = {}

-- ============================================================
-- 内部状态
-- ============================================================
local _time       = 0      -- 全局时间（用于动画）
local _selected   = 1      -- 当前选中菜单项索引
local _fadeIn     = 0      -- 淡入计时（0→1 秒）
local _exitTimer  = -1     -- 退出动画计时（-1=未触发）
local _exitAction = nil    -- 退出后的操作函数

-- 菜单项定义
-- enabled=false 的项目显示为灰色且不可选
local _menuItems = {
    { key = "menu.start",        enabled = true,  action = "charSelect"  },
    { key = "menu.progression",  enabled = true,  action = "progression" },
    { key = "menu.achievements", enabled = true,  action = "achievements"},
    { key = "menu.settings",     enabled = false, action = nil           },
    { key = "menu.exit",         enabled = true,  action = "exit"        },
}

-- 粒子系统
local _particles = {}
local PARTICLE_COUNT = 60

-- ============================================================
-- 粒子初始化
-- ============================================================
local function initParticles()
    _particles = {}
    for i = 1, PARTICLE_COUNT do
        _particles[i] = {
            x     = math.random(0, 1280),
            y     = math.random(0, 720),
            vy    = math.random(15, 45) / 10,      -- 上升速度（像素/秒）
            vx    = (math.random() - 0.5) * 0.6,  -- 水平漂移
            size  = math.random(1, 3) + math.random() * 0.5,
            alpha = math.random(20, 80) / 100,
            twinkle = math.random() * math.pi * 2, -- 闪烁相位
        }
    end
end

-- ============================================================
-- 粒子更新
-- ============================================================
local function updateParticles(dt)
    for _, p in ipairs(_particles) do
        p.y = p.y - p.vy * dt
        p.x = p.x + p.vx * dt
        p.twinkle = p.twinkle + dt * 2.5
        -- 超出顶部后从底部重新出现
        if p.y < -5 then
            p.y = 725
            p.x = math.random(0, 1280)
        end
        -- 超出左右边界回绕
        if p.x < -5  then p.x = 1285 end
        if p.x > 1285 then p.x = -5  end
    end
end

-- ============================================================
-- 获取当前选中的可用菜单项索引（跳过 disabled）
-- ============================================================
local function nextEnabled(dir)
    local n = #_menuItems
    local idx = _selected
    for _ = 1, n do
        idx = ((idx - 1 + dir) % n) + 1
        if _menuItems[idx].enabled then return idx end
    end
    return _selected
end

-- ============================================================
-- 触发菜单选择（带淡出动画）
-- ============================================================
local function triggerSelect(item)
    if not item.enabled then return end
    if item.action == "charSelect" then
        _exitTimer  = 0
        _exitAction = function()
            local StateManager = require("src.states.stateManager")
            StateManager.push("characterSelect")
        end
    elseif item.action == "progression" then
        _exitTimer  = 0
        _exitAction = function()
            local StateManager = require("src.states.stateManager")
            StateManager.push("progression", { characterId = "engineer" })
        end
    elseif item.action == "achievements" then
        _exitTimer  = 0
        _exitAction = function()
            local StateManager = require("src.states.stateManager")
            StateManager.push("achievements")
        end
    elseif item.action == "exit" then
        _exitTimer  = 0
        _exitAction = function()
            love.event.quit()
        end
    end
end

-- ============================================================
-- 进入
-- ============================================================
function Menu:enter()
    _time      = 0
    _selected  = 1
    _fadeIn    = 0
    _exitTimer = -1
    _exitAction = nil
    initParticles()
end

-- ============================================================
-- 退出
-- ============================================================
function Menu:exit()
end

-- ============================================================
-- 更新
-- ============================================================
function Menu:update(dt)
    _time   = _time + dt
    _fadeIn = math.min(_fadeIn + dt, 1.0)
    updateParticles(dt)

    if _exitTimer >= 0 then
        _exitTimer = _exitTimer + dt
        if _exitTimer >= 0.45 then
            if _exitAction then _exitAction() end
            _exitTimer = -1
        end
    end
end

-- ============================================================
-- 绘制渐变背景
-- ============================================================
local function drawBackground()
    -- 顶部颜色：深蓝偏黑
    -- 底部颜色：深紫偏黑
    -- Love2D 没有原生渐变，用多条水平矩形模拟
    local steps = 24
    local h     = 720 / steps
    for i = 0, steps - 1 do
        local t  = i / (steps - 1)
        -- 顶部: (0.04, 0.04, 0.12)  底部: (0.08, 0.03, 0.16)
        local r = 0.04 + 0.04 * t
        local g = 0.04 - 0.01 * t
        local b = 0.12 + 0.04 * t
        love.graphics.setColor(r, g, b, 1)
        love.graphics.rectangle("fill", 0, i * h, 1280, h + 1)
    end
end

-- ============================================================
-- 绘制粒子
-- ============================================================
local function drawParticles(globalAlpha)
    for _, p in ipairs(_particles) do
        local tw = (math.sin(p.twinkle) + 1) * 0.5  -- 0~1 闪烁系数
        local a  = p.alpha * (0.5 + 0.5 * tw) * globalAlpha
        -- 蓝紫色系粒子
        local hue = 0.55 + 0.15 * math.sin(p.twinkle * 0.7)  -- 蓝→紫
        love.graphics.setColor(0.5 + 0.3 * (1 - hue), 0.5, hue + 0.3, a)
        love.graphics.circle("fill", p.x, p.y, p.size)
    end
end

-- ============================================================
-- 绘制动态标题（波浪 + 呼吸光效）
-- ============================================================
local function drawTitle(globalAlpha, time)
    local titleStr = T("menu.title") or "ZERO"
    local cx   = 1280 / 2
    local baseY = 200

    -- 呼吸光圈（标题后面的光晕）
    local breathe = (math.sin(time * 1.2) + 1) * 0.5   -- 0~1
    local glowR   = 180 + 80 * breathe
    love.graphics.setColor(0.3, 0.2, 0.7, 0.12 * breathe * globalAlpha)
    love.graphics.circle("fill", cx, baseY + 30, glowR)
    love.graphics.setColor(0.4, 0.25, 0.85, 0.07 * breathe * globalAlpha)
    love.graphics.circle("fill", cx, baseY + 30, glowR * 0.6)

    -- 装饰横线（标题上下）
    local lineAlpha = 0.35 * globalAlpha
    local lineW = 360
    love.graphics.setColor(0.55, 0.35, 0.95, lineAlpha)
    love.graphics.setLineWidth(1.5)
    love.graphics.line(cx - lineW/2, baseY - 18, cx - 80, baseY - 18)
    love.graphics.line(cx + 80,     baseY - 18, cx + lineW/2, baseY - 18)
    love.graphics.line(cx - lineW/2, baseY + 80, cx - 80, baseY + 80)
    love.graphics.line(cx + 80,     baseY + 80, cx + lineW/2, baseY + 80)
    love.graphics.setLineWidth(1)

    -- 标题主体：逐字符波浪偏移（模拟用 printf 整体偏移代替）
    -- Love2D 没有原生逐字符渲染，用整体轻微 Y 浮动 + 颜色变化
    local waveY  = math.sin(time * 1.8) * 4
    local colorT = (math.sin(time * 0.9) + 1) * 0.5  -- 0~1 颜色插值

    -- 阴影层
    Font.set(72)
    love.graphics.setColor(0, 0, 0, 0.5 * globalAlpha)
    love.graphics.printf(titleStr, 0 + 3, baseY + 3 + waveY, 1280, "center")

    -- 主颜色：在青白和蓝紫间渐变
    local r = 0.7  + 0.3  * colorT
    local g = 0.75 - 0.15 * colorT
    local b = 1.0
    love.graphics.setColor(r, g, b, globalAlpha)
    love.graphics.printf(titleStr, 0, baseY + waveY, 1280, "center")

    -- 高光层（更亮的中心）
    love.graphics.setColor(1, 1, 1, 0.25 * breathe * globalAlpha)
    love.graphics.printf(titleStr, 0, baseY + waveY, 1280, "center")

    Font.reset()
end

-- ============================================================
-- 绘制菜单项
-- ============================================================
local function drawMenuItems(globalAlpha, time)
    local cx       = 1280 / 2
    local startY   = 340
    local itemH    = 54
    local itemW    = 280

    for i, item in ipairs(_menuItems) do
        local iy = startY + (i - 1) * itemH
        local isSelected = (i == _selected) and item.enabled

        -- 选中高亮背景
        if isSelected then
            local pulse = (math.sin(time * 3.5) + 1) * 0.5
            local bgAlpha = (0.15 + 0.08 * pulse) * globalAlpha
            love.graphics.setColor(0.45, 0.25, 0.85, bgAlpha)
            love.graphics.rectangle("fill", cx - itemW/2, iy - 6, itemW, 38, 6, 6)
            -- 选中框线
            love.graphics.setColor(0.65, 0.4, 0.95, (0.6 + 0.3 * pulse) * globalAlpha)
            love.graphics.rectangle("line", cx - itemW/2, iy - 6, itemW, 38, 6, 6)
            -- 左侧装饰箭头
            love.graphics.setColor(0.8, 0.55, 1.0, globalAlpha)
            love.graphics.printf("▶", cx - itemW/2 - 30, iy + 2, 24, "center")
        end

        -- 文字颜色
        local label = T(item.key) or item.key
        Font.set(20)
        if not item.enabled then
            love.graphics.setColor(0.35, 0.35, 0.42, globalAlpha * 0.7)
        elseif isSelected then
            local pulse = (math.sin(time * 3.5) + 1) * 0.5
            love.graphics.setColor(0.92, 0.82 + 0.12 * pulse, 1.0, globalAlpha)
        else
            love.graphics.setColor(0.7, 0.68, 0.82, globalAlpha)
        end
        love.graphics.printf(label, cx - itemW/2, iy, itemW, "center")

        Font.reset()
    end
end

-- ============================================================
-- 绘制底部版本号
-- ============================================================
local function drawFooter(globalAlpha)
    Font.set(11)
    love.graphics.setColor(0.3, 0.3, 0.4, globalAlpha * 0.7)
    love.graphics.printf(T("menu.version") or "v0.11", 0, 700, 1270, "right")
    Font.reset()
end

-- ============================================================
-- 绘制
-- ============================================================
function Menu:draw()
    -- 计算全局透明度（淡入 / 淡出）
    local globalAlpha = _fadeIn
    if _exitTimer >= 0 then
        globalAlpha = globalAlpha * math.max(0, 1 - _exitTimer / 0.45)
    end

    -- 背景渐变
    drawBackground()

    -- 粒子
    drawParticles(globalAlpha)

    -- 标题
    drawTitle(globalAlpha, _time)

    -- 菜单项
    drawMenuItems(globalAlpha, _time)

    -- 版本号
    drawFooter(globalAlpha)

    love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================
-- 键盘事件
-- ============================================================
function Menu:keypressed(key)
    -- 退出动画中不响应
    if _exitTimer >= 0 then return end

    if key == "up" or key == "w" then
        _selected = nextEnabled(-1)
    elseif key == "down" or key == "s" then
        _selected = nextEnabled(1)
    elseif key == "return" or key == "space" then
        triggerSelect(_menuItems[_selected])
    elseif key == "escape" then
        -- Esc 直接退出
        triggerSelect({ enabled = true, action = "exit" })
    end
end

return Menu
