--[[
    src/states/achievements.lua
    成就列表界面 — Phase 13
    push/pop 覆盖层，显示所有成就的解锁状态。
    · 已解锁成就：正常亮色显示（上方）
    · 未解锁成就：灰色半透明（下方）
    · 若成就配置为空，显示友好提示
]]

local Font               = require("src.utils.font")
local Input              = require("src.systems.input")
local AchievementConfig  = require("config.achievements")

-- ============================================================
-- 尝试加载 AchievementManager（若尚不存在则容错处理）
-- ============================================================
local AchievementManager = nil
local ok, result = pcall(require, "src.systems.achievementManager")
if ok then
    AchievementManager = result
end

local Achievements = {}

-- ============================================================
-- 常量
-- ============================================================
local SCREEN_W  = 1280
local SCREEN_H  = 720
local ITEM_H    = 68
local LIST_X    = 120
local LIST_W    = SCREEN_W - 240
local LIST_Y    = 140
local VISIBLE_H = SCREEN_H - LIST_Y - 80   -- 可视区高度
local SCROLL_SPEED = 3  -- 每次按键滚动的格数

-- ============================================================
-- enter / exit
-- ============================================================

--- 进入成就界面
--- @param data table  （暂未使用，预留扩展）
function Achievements:enter(data)
    self._scrollIdx = 1    -- 当前选中项（1-indexed）
    self._offset    = 0    -- 滚动偏移（像素）

    -- 从 AchievementManager 获取所有成就解锁状态，构建展示列表
    self._list = self:_buildList()

    Input.update()
end

--- 退出成就界面
function Achievements:exit()
    self._list      = nil
    self._scrollIdx = 1
    self._offset    = 0
end

-- ============================================================
-- 内部：构建展示列表
-- ============================================================

--- 构建排序后的成就列表
--- 已解锁的排在前面，未解锁的排在后面
function Achievements:_buildList()
    -- 若配置为空直接返回空列表（界面将显示友好提示）
    if not AchievementConfig or #AchievementConfig == 0 then
        return {}
    end

    local unlocked = {}
    local locked   = {}

    for _, ach in ipairs(AchievementConfig) do
        local isUnlocked = false
        if AchievementManager and AchievementManager.isUnlocked then
            isUnlocked = AchievementManager.isUnlocked(ach.id)
        end

        local item = {
            id        = ach.id,
            nameKey   = ach.nameKey,
            descKey   = ach.descKey,
            icon      = ach.icon or "★",
            unlocked  = isUnlocked,
        }

        if isUnlocked then
            table.insert(unlocked, item)
        else
            table.insert(locked, item)
        end
    end

    -- 合并：已解锁在前，未解锁在后
    local result = {}
    for _, v in ipairs(unlocked) do table.insert(result, v) end
    for _, v in ipairs(locked)   do table.insert(result, v) end
    return result
end

-- ============================================================
-- update
-- ============================================================

function Achievements:update(dt)
    Input.update()

    local n = #self._list

    if Input.isPressed("moveUp") then
        if n > 0 then
            self._scrollIdx = math.max(1, self._scrollIdx - 1)
            self:_clampScroll()
        end
    elseif Input.isPressed("moveDown") then
        if n > 0 then
            self._scrollIdx = math.min(n, self._scrollIdx + 1)
            self:_clampScroll()
        end
    end

    -- ESC 返回
    if Input.isPressed("cancel") then
        local SM = require("src.states.stateManager")
        SM.pop()
    end
end

--- 调整滚动偏移，确保选中项在可视范围内
function Achievements:_clampScroll()
    local selY   = (self._scrollIdx - 1) * (ITEM_H + 8)  -- 选中项相对 Y
    local bottom = selY + ITEM_H

    -- 向上滚动
    if selY < self._offset then
        self._offset = selY
    end

    -- 向下滚动
    if bottom > self._offset + VISIBLE_H then
        self._offset = bottom - VISIBLE_H
    end

    -- 防止偏移量为负
    if self._offset < 0 then self._offset = 0 end
end

-- ============================================================
-- draw
-- ============================================================

function Achievements:draw()
    -- 半透明遮罩
    love.graphics.setColor(0, 0, 0, 0.82)
    love.graphics.rectangle("fill", 0, 0, SCREEN_W, SCREEN_H)

    -- 标题
    Font.set(28)
    love.graphics.setColor(1.0, 0.85, 0.2)
    love.graphics.printf(T("achievements.title"), 0, 22, SCREEN_W, "center")

    -- 成就计数
    local total    = #self._list
    local unlockedN = 0
    for _, item in ipairs(self._list) do
        if item.unlocked then unlockedN = unlockedN + 1 end
    end

    Font.set(15)
    love.graphics.setColor(0.65, 0.65, 0.7)
    love.graphics.printf(
        string.format("%s：%d / %d",
            T("achievements.unlocked"), unlockedN, total),
        0, 68, SCREEN_W, "center")

    -- 分隔线
    love.graphics.setColor(0.25, 0.25, 0.3, 0.8)
    love.graphics.rectangle("fill", LIST_X, LIST_Y - 12, LIST_W, 1)

    if total == 0 then
        -- 友好空状态提示
        self:_drawEmpty()
    else
        -- 裁剪区域（防止列表项超出边界）
        love.graphics.setScissor(LIST_X, LIST_Y, LIST_W, VISIBLE_H)
        self:_drawList()
        love.graphics.setScissor()

        -- 滚动条（若列表超出可视区）
        self:_drawScrollbar(total)
    end

    -- 底部操作提示
    Font.set(14)
    love.graphics.setColor(0.45, 0.45, 0.5)
    love.graphics.printf(T("achievements.hint"), 0, SCREEN_H - 28, SCREEN_W, "center")

    Font.reset()
    love.graphics.setColor(1, 1, 1, 1)
end

--- 绘制空状态提示
function Achievements:_drawEmpty()
    Font.set(18)
    love.graphics.setColor(0.5, 0.5, 0.55)
    love.graphics.printf(T("achievements.empty"), 0, SCREEN_H / 2 - 40, SCREEN_W, "center")

    Font.set(15)
    love.graphics.setColor(0.38, 0.38, 0.42)
    love.graphics.printf("成就内容即将开放", 0, SCREEN_H / 2, SCREEN_W, "center")
end

--- 绘制成就列表
function Achievements:_drawList()
    for i, item in ipairs(self._list) do
        local itemY    = LIST_Y + (i - 1) * (ITEM_H + 8) - self._offset
        local selected = (i == self._scrollIdx)

        -- 只绘制可视区内的项目
        if itemY + ITEM_H >= LIST_Y and itemY <= LIST_Y + VISIBLE_H then
            self:_drawItem(item, LIST_X, itemY, LIST_W, selected)
        end
    end
end

--- 绘制单个成就项
function Achievements:_drawItem(item, x, y, w, selected)
    local alpha = item.unlocked and 1.0 or 0.38

    -- 背景
    if selected then
        love.graphics.setColor(0.15, 0.22, 0.35, 0.92)
    elseif item.unlocked then
        love.graphics.setColor(0.1, 0.13, 0.18, 0.85)
    else
        love.graphics.setColor(0.07, 0.07, 0.1, 0.6)
    end
    love.graphics.rectangle("fill", x, y, w, ITEM_H - 4, 6, 6)

    -- 边框
    if selected then
        love.graphics.setColor(0.3, 0.55, 1.0)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x, y, w, ITEM_H - 4, 6, 6)
        love.graphics.setLineWidth(1)
    elseif item.unlocked then
        love.graphics.setColor(0.35, 0.55, 0.35, 0.7)
        love.graphics.rectangle("line", x, y, w, ITEM_H - 4, 6, 6)
    else
        love.graphics.setColor(0.2, 0.2, 0.25, 0.5)
        love.graphics.rectangle("line", x, y, w, ITEM_H - 4, 6, 6)
    end

    -- 图标
    Font.set(22)
    if item.unlocked then
        love.graphics.setColor(1.0, 0.85, 0.2, alpha)
    else
        love.graphics.setColor(0.4, 0.4, 0.45, alpha)
    end
    love.graphics.print(item.icon, x + 14, y + (ITEM_H - 4) / 2 - 12)

    -- 名称
    Font.set(16)
    if item.unlocked then
        if selected then
            love.graphics.setColor(1.0, 1.0, 1.0)
        else
            love.graphics.setColor(0.9, 0.9, 0.85)
        end
    else
        love.graphics.setColor(0.45, 0.45, 0.48)
    end
    love.graphics.print(T(item.nameKey), x + 56, y + 8)

    -- 描述
    Font.set(13)
    if item.unlocked then
        love.graphics.setColor(0.65, 0.7, 0.72, alpha)
    else
        love.graphics.setColor(0.35, 0.35, 0.38)
    end
    love.graphics.print(T(item.descKey), x + 56, y + 30)

    -- 解锁/未解锁标签（右侧）
    Font.set(12)
    if item.unlocked then
        love.graphics.setColor(0.3, 0.85, 0.45)
        love.graphics.printf(T("achievements.unlocked"), x, y + (ITEM_H - 4) / 2 - 8, w - 16, "right")
    else
        love.graphics.setColor(0.38, 0.38, 0.42)
        love.graphics.printf(T("achievements.locked"), x, y + (ITEM_H - 4) / 2 - 8, w - 16, "right")
    end
end

--- 绘制右侧滚动条（列表超出时显示）
function Achievements:_drawScrollbar(total)
    local totalH    = total * (ITEM_H + 8)
    if totalH <= VISIBLE_H then return end

    local sbX       = LIST_X + LIST_W + 8
    local sbY       = LIST_Y
    local sbH       = VISIBLE_H
    local sbW       = 6
    local thumbRatio = VISIBLE_H / totalH
    local thumbH    = math.max(24, sbH * thumbRatio)
    local thumbY    = sbY + (self._offset / (totalH - VISIBLE_H)) * (sbH - thumbH)

    -- 轨道
    love.graphics.setColor(0.15, 0.15, 0.2)
    love.graphics.rectangle("fill", sbX, sbY, sbW, sbH, 3, 3)

    -- 滑块
    love.graphics.setColor(0.35, 0.45, 0.65)
    love.graphics.rectangle("fill", sbX, thumbY, sbW, thumbH, 3, 3)
end

-- ============================================================
-- keypressed（Input 系统统一处理，此处留空）
-- ============================================================
function Achievements:keypressed(key)
end

return Achievements
