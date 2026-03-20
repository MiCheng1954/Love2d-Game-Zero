--[[
    src/states/bagUI.lua
    背包界面状态（push/pop 覆盖层）
    Phase 6：武器背包系统

    两种模式：
      BROWSE — TAB 打开，方向键移动光标，R 旋转预览，ESC 关闭
      PLACE  — 升级获得新武器后推入，选择放置位置，Enter 确认，ESC 丢弃

    布局（1280×720）：
      左侧：背包网格（每格 64px）
      右侧：选中武器详情
      底部：操作提示栏
]]

local Input  = require("src.systems.input")
local Font   = require("src.utils.font")

local BagUI = {}

-- 模式枚举
local MODE_BROWSE = "browse"
local MODE_PLACE  = "place"
local MODE_SELECT = "select"   -- 选择背包中某把武器（升级用）

-- 网格渲染参数
local CELL_SIZE  = 64    -- 每格像素大小
local GRID_X     = 80    -- 网格左边距
local GRID_Y     = 120   -- 网格上边距

-- ============================================================
-- 生命周期
-- ============================================================

-- 进入背包界面
-- @param data 字段：
--   data.bag        — Bag 实例（必须）
--   data.mode       — "browse"（默认）/ "place" / "select"
--   data.weapon     — PLACE 模式下待放置的武器实例
--   data.onPlace    — PLACE 模式放置成功回调 function()
--   data.onDiscard  — PLACE 模式丢弃回调 function()
--   data.onClose    — BROWSE 模式关闭回调 function()
--   data.onSelect   — SELECT 模式选中武器回调 function(weapon)
--   data.selectHint — SELECT 模式底部提示文字（可选）
--   data.filter     — SELECT 模式过滤函数 function(weapon) → bool（可选）
function BagUI:enter(data)
    self._bag        = data.bag
    self._mode       = data.mode or MODE_BROWSE
    self._onPlace    = data.onPlace
    self._onDiscard  = data.onDiscard
    self._onClose    = data.onClose
    self._onSelect   = data.onSelect
    self._selectHint = data.selectHint
    self._filter     = data.filter   -- SELECT 模式：哪些武器可选（高亮）

    -- 光标位置（BROWSE / SELECT 模式）
    self._cursorRow = 1
    self._cursorCol = 1

    -- PLACE 模式：待放置武器与当前预览位置
    self._placing  = data.weapon
    self._placeRow = 1
    self._placeCol = 1

    -- 防止本帧输入残留
    Input.update()
end

-- 退出背包界面
function BagUI:exit()
    self._bag        = nil
    self._placing    = nil
    self._onPlace    = nil
    self._onDiscard  = nil
    self._onClose    = nil
    self._onSelect   = nil
    self._filter     = nil
end

-- ============================================================
-- 更新
-- ============================================================

function BagUI:update(dt)
    Input.update()

    if self._mode == MODE_BROWSE then
        self:_updateBrowse()
    elseif self._mode == MODE_PLACE then
        self:_updatePlace()
    elseif self._mode == MODE_SELECT then
        self:_updateSelect()
    end
end

-- BROWSE 模式输入处理（支持拾起武器移动 — 修复 #6）
function BagUI:_updateBrowse()
    local bag = self._bag

    if Input.isPressed("moveUp") then
        self._cursorRow = math.max(1, self._cursorRow - 1)
    elseif Input.isPressed("moveDown") then
        self._cursorRow = math.min(bag.rows, self._cursorRow + 1)
    elseif Input.isPressed("moveLeft") then
        self._cursorCol = math.max(1, self._cursorCol - 1)
    elseif Input.isPressed("moveRight") then
        self._cursorCol = math.min(bag.cols, self._cursorCol + 1)
    end

    -- Enter / E：拾起光标下的武器，进入 PLACE 移动模式
    if Input.isPressed("confirm") then
        local w = bag:getWeaponAt(self._cursorRow, self._cursorCol)
        if w then
            bag:remove(w)
            -- 切换为 PLACE 模式，放置/取消后切回 BROWSE（不触发外部回调）
            self._mode     = MODE_PLACE
            self._placing  = w
            self._placeRow = self._cursorRow
            self._placeCol = self._cursorCol
            -- 放置成功 → 回到 BROWSE
            self._onPlace  = function()
                self._mode    = MODE_BROWSE
                self._placing = nil
                self._onPlace   = nil
                self._onDiscard = nil
            end
            -- ESC 取消 → 把武器放回原位，回到 BROWSE
            self._onDiscard = function()
                -- 尽量放回原位，放不下就扫描第一个空位
                local restored = bag:place(w, self._cursorRow, self._cursorCol)
                if not restored then
                    for r = 1, bag.rows do
                        for c = 1, bag.cols do
                            if bag:place(w, r, c) then
                                restored = true; break
                            end
                        end
                        if restored then break end
                    end
                end
                self._mode    = MODE_BROWSE
                self._placing = nil
                self._onPlace   = nil
                self._onDiscard = nil
            end
        end
    end

    -- ESC 关闭
    if Input.isPressed("cancel") then
        if self._onClose then self._onClose() end
    end
end

-- SELECT 模式输入处理（供 weapon_upgrade 等选武器场景使用）
function BagUI:_updateSelect()
    local bag = self._bag

    if Input.isPressed("moveUp") then
        self._cursorRow = math.max(1, self._cursorRow - 1)
    elseif Input.isPressed("moveDown") then
        self._cursorRow = math.min(bag.rows, self._cursorRow + 1)
    elseif Input.isPressed("moveLeft") then
        self._cursorCol = math.max(1, self._cursorCol - 1)
    elseif Input.isPressed("moveRight") then
        self._cursorCol = math.min(bag.cols, self._cursorCol + 1)
    end

    -- Enter 确认选中
    if Input.isPressed("confirm") then
        local w = bag:getWeaponAt(self._cursorRow, self._cursorCol)
        -- 只允许选通过 filter 的武器
        local ok = w and (not self._filter or self._filter(w))
        if ok and self._onSelect then
            self._onSelect(w)
        end
    end

    -- ESC 取消，不选任何武器
    if Input.isPressed("cancel") then
        if self._onSelect then self._onSelect(nil) end
    end
end

-- PLACE 模式输入处理
function BagUI:_updatePlace()
    local bag = self._bag

    if Input.isPressed("moveUp") then
        self._placeRow = math.max(1, self._placeRow - 1)
    elseif Input.isPressed("moveDown") then
        self._placeRow = math.min(bag.rows, self._placeRow + 1)
    elseif Input.isPressed("moveLeft") then
        self._placeCol = math.max(1, self._placeCol - 1)
    elseif Input.isPressed("moveRight") then
        self._placeCol = math.min(bag.cols, self._placeCol + 1)
    end

    -- R 旋转武器
    if Input.isPressed("rotateWeapon") then
        if self._placing then
            self._placing:rotate()
        end
    end

    -- Enter 放置
    if Input.isPressed("confirm") then
        if self._placing then
            local ok = bag:place(self._placing, self._placeRow, self._placeCol)
            if ok then
                if self._onPlace then self._onPlace() end
            end
            -- 放置失败时留在界面，玩家调整位置后再试
        end
    end

    -- ESC 丢弃武器并关闭
    if Input.isPressed("cancel") then
        if self._onDiscard then self._onDiscard() end
    end
end

-- keypressed 接收来自 stateManager 的一次性按键
-- 注意：旋转统一由 Input.isPressed("rotateWeapon") 处理，此处不重复处理 R 键
function BagUI:keypressed(key)
end

-- ============================================================
-- 绘制
-- ============================================================

function BagUI:draw()
    Font.set(15)

    -- 半透明遮罩
    love.graphics.setColor(0, 0, 0, 0.82)
    love.graphics.rectangle("fill", 0, 0, 1280, 720)

    -- 标题
    love.graphics.setColor(1, 0.85, 0.1)
    love.graphics.printf(T("bag.title"), 0, 30, 1280, "center")

    -- 背包网格
    self:_drawGrid()

    -- 右侧详情面板
    self:_drawDetail()

    -- 底部提示
    self:_drawHint()

    Font.reset()
end
-- 绘制背包网格
function BagUI:_drawGrid()
    local bag  = self._bag
    local mode = self._mode

    for r = 1, bag.rows do
        for c = 1, bag.cols do
            local px = GRID_X + (c - 1) * CELL_SIZE
            local py = GRID_Y + (r - 1) * CELL_SIZE

            -- 空格背景
            love.graphics.setColor(0.12, 0.12, 0.18, 0.95)
            love.graphics.rectangle("fill", px, py, CELL_SIZE - 2, CELL_SIZE - 2, 4, 4)

            -- 网格边框
            love.graphics.setColor(0.28, 0.28, 0.38)
            love.graphics.rectangle("line", px, py, CELL_SIZE - 2, CELL_SIZE - 2, 4, 4)

            -- 已放置武器颜色
            local w = bag:getWeaponAt(r, c)
            if w then
                local col = w.color

                -- SELECT 模式：不可选武器变暗
                local dimmed = (mode == MODE_SELECT) and self._filter and not self._filter(w)
                if dimmed then
                    love.graphics.setColor(col[1] * 0.25, col[2] * 0.25, col[3] * 0.25, 0.7)
                else
                    love.graphics.setColor(col[1] * 0.7, col[2] * 0.7, col[3] * 0.7, 0.9)
                end
                love.graphics.rectangle("fill", px + 2, py + 2, CELL_SIZE - 6, CELL_SIZE - 6, 3, 3)

                -- 等级标签在格子循环后统一绘制（见下方）
            end
        end
    end

    -- 武器等级标签：遍历所有武器，在其视觉中心绘制（避免被相邻格遮挡）
    local drawn = {}  -- 避免同一把武器绘制多次
    for r = 1, bag.rows do
        for c = 1, bag.cols do
            local w = bag:getWeaponAt(r, c)
            if w and w._bagRow and not drawn[w.instanceId] then
                drawn[w.instanceId] = true
                local dimmed = (mode == MODE_SELECT) and self._filter and not self._filter(w)

                -- 计算武器所有格子的像素中心均值
                local cells = w:getCells(w._bagRow, w._bagCol)
                local sumX, sumY = 0, 0
                for _, cell in ipairs(cells) do
                    sumX = sumX + GRID_X + (cell.col - 1) * CELL_SIZE + CELL_SIZE * 0.5
                    sumY = sumY + GRID_Y + (cell.row - 1) * CELL_SIZE + CELL_SIZE * 0.5
                end
                local cx = sumX / #cells
                local cy = sumY / #cells

                -- 绘制等级标签（深色背景 + 白色/暗白文字）
                Font.set(11)
                local label = "Lv" .. w.level
                local tw = Font.get(11):getWidth(label)
                local th = Font.get(11):getHeight()
                local lx = math.floor(cx - tw * 0.5)
                local ly = math.floor(cy - th * 0.5)
                -- 背景框
                love.graphics.setColor(0, 0, 0, dimmed and 0.35 or 0.65)
                love.graphics.rectangle("fill", lx - 2, ly - 1, tw + 4, th + 2, 2, 2)
                -- 文字
                local br = dimmed and 0.4 or 1
                love.graphics.setColor(br, br, br)
                love.graphics.print(label, lx, ly)
                Font.set(15)
            end

    -- 光标（BROWSE / SELECT 模式共用）
    if mode == MODE_BROWSE or mode == MODE_SELECT then
        local px = GRID_X + (self._cursorCol - 1) * CELL_SIZE
        local py = GRID_Y + (self._cursorRow - 1) * CELL_SIZE
        -- SELECT 模式光标颜色随可选性变化
        if mode == MODE_SELECT then
            local w  = bag:getWeaponAt(self._cursorRow, self._cursorCol)
            local ok = w and (not self._filter or self._filter(w))
            if ok then
                love.graphics.setColor(0.2, 1.0, 0.3, 0.9)
            else
                love.graphics.setColor(0.6, 0.6, 0.6, 0.6)
            end
        else
            love.graphics.setColor(1, 1, 1, 0.9)
        end
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", px, py, CELL_SIZE - 2, CELL_SIZE - 2, 4, 4)
        love.graphics.setLineWidth(1)
    end

    -- PLACE 模式：放置预览
    if mode == MODE_PLACE and self._placing then
        local canPlace = self._bag:canPlace(self._placing, self._placeRow, self._placeCol)
        local cells    = self._placing:getCells(self._placeRow, self._placeCol)

        for _, cell in ipairs(cells) do
            if cell.row >= 1 and cell.row <= bag.rows
            and cell.col >= 1 and cell.col <= bag.cols then
                local px = GRID_X + (cell.col - 1) * CELL_SIZE
                local py = GRID_Y + (cell.row - 1) * CELL_SIZE
                if canPlace then
                    love.graphics.setColor(0.2, 1.0, 0.3, 0.55)
                else
                    love.graphics.setColor(1.0, 0.2, 0.2, 0.55)
                end
                love.graphics.rectangle("fill", px + 2, py + 2, CELL_SIZE - 6, CELL_SIZE - 6, 3, 3)
                if canPlace then
                    love.graphics.setColor(0.2, 1.0, 0.3, 0.9)
                else
                    love.graphics.setColor(1.0, 0.2, 0.2, 0.9)
                end
                love.graphics.setLineWidth(2)
                love.graphics.rectangle("line", px, py, CELL_SIZE - 2, CELL_SIZE - 2, 4, 4)
                love.graphics.setLineWidth(1)
            end
        end
    end
end

-- 绘制右侧武器详情面板
function BagUI:_drawDetail()
    local panelX = GRID_X + self._bag.cols * CELL_SIZE + 40
    local panelY = GRID_Y
    local panelW = 1280 - panelX - 20

    -- 取当前选中或待放置的武器
    local w = nil
    if self._mode == MODE_BROWSE then
        w = self._bag:getWeaponAt(self._cursorRow, self._cursorCol)
    elseif self._mode == MODE_PLACE then
        w = self._placing
    end

    if not w then
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.printf(T("bag.empty"), panelX, panelY, panelW, "left")
        return
    end

    local col = w.color
    love.graphics.setColor(col)
    love.graphics.printf(T(w.nameKey), panelX, panelY, panelW, "left")

    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.printf(T(w.descKey), panelX, panelY + 28, panelW, "left")

    local lh = 22
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(string.format("等级:   %d / %d",  w.level, w.maxLevel),             panelX, panelY + 72)
    love.graphics.print(string.format("伤害:   %d",       w.damage),                         panelX, panelY + 72 + lh)
    love.graphics.print(string.format("射速:   %.2f /s",  w.attackSpeed),                    panelX, panelY + 72 + lh * 2)
    love.graphics.print(string.format("弹速:   %d px/s",  w.bulletSpeed),                    panelX, panelY + 72 + lh * 3)
    love.graphics.print(string.format("射程:   %d px",    w.range),                          panelX, panelY + 72 + lh * 4)
end

-- 绘制底部操作提示
function BagUI:_drawHint()
    love.graphics.setColor(0.5, 0.5, 0.5)
    if self._mode == MODE_BROWSE then
        love.graphics.printf(T("bag.hint.browse"), 0, 688, 1280, "center")
    elseif self._mode == MODE_PLACE then
        love.graphics.printf(T("bag.hint.place"), 0, 688, 1280, "center")
    elseif self._mode == MODE_SELECT then
        local hint = self._selectHint or T("bag.hint.select")
        love.graphics.printf(hint, 0, 688, 1280, "center")
    end
end

return BagUI
