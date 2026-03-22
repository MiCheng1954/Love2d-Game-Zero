--[[
    src/states/bagUI.lua
    背包界面状态（push/pop 覆盖层）
    Phase 6：武器背包系统
    Phase 7.1：新增融合交互（FUSION 预览子状态）
    Phase 8（改版）：右侧面板支持 Q/E 键切换「武器详情」和「技能面板」

    模式：
      BROWSE — TAB 打开，方向键移动光标，R 旋转预览，ESC 关闭
               Q/E 切换右侧面板（武器 / 技能）
      PLACE  — 升级获得新武器/背包内移动武器，Enter 确认，ESC 丢弃
      SELECT — 选择背包中某把武器（升级用）
      FUSION — 检测到融合配方后弹出预览，Enter 确认融合，ESC 返回 PLACE

    布局（1280×720）：
      左侧：背包网格（每格 64px）
      右侧：选中武器详情 / 技能面板（Q/E 切换）
      底部：操作提示栏
]]

local Input        = require("src.systems.input")
local Font         = require("src.utils.font")
local Fusion       = require("src.systems.fusion")
local WeaponConfig = require("config.weapons")
local SynergyConfig = require("config.synergies")

local BagUI = {}

-- 模式枚举
local MODE_BROWSE = "browse"
local MODE_PLACE  = "place"
local MODE_SELECT = "select"
local MODE_FUSION = "fusion"  -- Phase 7.1：融合预览子状态

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
    self._player     = data.player   -- 需求4：存储玩家引用（用于技能列表展示）
    self._mode       = data.mode or MODE_BROWSE
    self._onPlace    = data.onPlace
    self._onDiscard  = data.onDiscard
    self._onClose    = data.onClose
    self._onSelect   = data.onSelect
    self._selectHint = data.selectHint
    self._filter     = data.filter

    -- 光标位置（BROWSE / SELECT 模式）
    self._cursorRow = 1
    self._cursorCol = 1

    -- PLACE 模式：待放置武器与当前预览位置
    self._placing  = data.weapon
    self._placeRow = 1
    self._placeCol = 1

    -- Phase 7.1：融合预览状态
    self._fusionRecipe      = nil
    self._fusionTarget      = nil
    self._fusionOrigin      = nil
    self._fusionJustEntered = false
    self._fusionFailMsg     = nil
    self._fusionFailTimer   = 0
    self._detailBottomY     = 480   -- Bug#6/#8：详情面板实际底部Y，供 _drawSynergies 用

    -- 右侧面板切换（Q=武器, E=技能）
    self._panelTab     = "weapon"   -- "weapon" / "skill"
    self._skillCursor  = 1          -- 技能列表当前选中索引

    -- 防止本帧输入残留
    Input.update()
end

-- 退出背包界面
function BagUI:exit()
    self._bag               = nil
    self._player            = nil   -- 需求4
    self._placing           = nil
    self._onPlace           = nil
    self._onDiscard         = nil
    self._onClose           = nil
    self._onSelect          = nil
    self._filter            = nil
    self._fusionRecipe      = nil
    self._fusionTarget      = nil
    self._fusionOrigin      = nil
    self._fusionJustEntered = false
    self._fusionFailMsg     = nil
    self._fusionFailTimer   = 0
    self._panelTab          = "weapon"
    self._skillCursor       = 1
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
    elseif self._mode == MODE_FUSION then
        self:_updateFusion()
    end
end

-- BROWSE 模式输入处理（支持拾起武器移动 — 修复 #6）
function BagUI:_updateBrowse()
    local bag = self._bag

    -- Q/E 切换右侧面板（武器 / 技能）
    if Input.isPressed("skill2") then   -- Q
        self._panelTab = "weapon"
    elseif Input.isPressed("skill3") then   -- E
        self._panelTab = "skill"
    end

    if self._panelTab == "skill" then
        -- 技能面板：上下键移动技能光标
        local list = self:_getSkillList()
        local cnt  = #list
        if cnt > 0 then
            if Input.isPressed("moveUp") then
                self._skillCursor = math.max(1, self._skillCursor - 1)
            elseif Input.isPressed("moveDown") then
                self._skillCursor = math.min(cnt, self._skillCursor + 1)
            end
        end

        -- ESC 或 TAB 关闭
        if Input.isPressed("cancel") or Input.isPressed("openBag") then
            if self._onClose then self._onClose() end
        end
        return
    end

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
            local originRow = self._cursorRow
            local originCol = self._cursorCol
            bag:remove(w)
            -- 切换为 PLACE 模式，放置/取消后切回 BROWSE（不触发外部回调）
            self._mode          = MODE_PLACE
            self._placing       = w
            self._placeRow      = originRow
            self._placeCol      = originCol
            self._fusionOrigin  = { row = originRow, col = originCol }
            -- 放置成功 → 回到 BROWSE
            self._onPlace  = function()
                self._mode          = MODE_BROWSE
                self._placing       = nil
                self._fusionOrigin  = nil
                self._onPlace       = nil
                self._onDiscard     = nil
            end
            -- ESC 取消 → 把武器放回原位，回到 BROWSE
            self._onDiscard = function()
                local restored = bag:place(w, originRow, originCol)
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
                self._mode          = MODE_BROWSE
                self._placing       = nil
                self._fusionOrigin  = nil
                self._onPlace       = nil
                self._onDiscard     = nil
            end
        end
    end

    -- ESC 或 TAB 关闭
    if Input.isPressed("cancel") or Input.isPressed("openBag") then
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

    -- Enter：检测融合或普通放置
    if Input.isPressed("confirm") then
        if self._placing then
            -- Phase 7.1：检测当前目标位置是否有其他武器且构成融合配方
            local targetWeapon = self:_getFusionTarget()
            if targetWeapon then
                local recipe = Fusion.findRecipe(self._placing.configId, targetWeapon.configId)
                if recipe then
                    -- 进入融合预览模式
                    self._mode              = MODE_FUSION
                    self._fusionRecipe      = recipe
                    self._fusionTarget      = targetWeapon
                    self._fusionJustEntered = true  -- Bug#1：跳过本帧残留 confirm
                    return
                end
            end

            -- 普通放置
            local ok = bag:place(self._placing, self._placeRow, self._placeCol)
            if ok then
                if self._onPlace then self._onPlace() end
            end
            -- 放置失败时留在界面，玩家调整位置后再试
        end
    end

    -- ESC 丢弃/取消
    if Input.isPressed("cancel") then
        if self._onDiscard then self._onDiscard() end
    end
end

-- 检测当前预览位置是否整体与某把武器重叠（且仅与一把）
-- 用于判断是否进入融合检测
-- @return 目标 Weapon 实例（符合融合条件的唯一碰撞武器），或 nil
function BagUI:_getFusionTarget()
    local bag     = self._bag
    local placing = self._placing
    if not placing then return nil end

    local cells = placing:getCells(self._placeRow, self._placeCol)

    -- 越界则不触发融合
    for _, cell in ipairs(cells) do
        if cell.row < 1 or cell.row > bag.rows
        or cell.col < 1 or cell.col > bag.cols then
            return nil
        end
    end

    -- 收集所有碰撞的武器（去重）
    local conflicts = {}
    local seen = {}
    for _, cell in ipairs(cells) do
        local w = bag:getWeaponAt(cell.row, cell.col)
        if w and w.instanceId ~= placing.instanceId and not seen[w.instanceId] then
            seen[w.instanceId] = true
            table.insert(conflicts, w)
        end
    end

    -- 融合只支持恰好撞上 1 把武器
    if #conflicts == 1 then
        return conflicts[1]
    end
    return nil
end

-- FUSION 模式输入处理（融合预览确认/取消）
function BagUI:_updateFusion()
    -- Bug#1：进入 MODE_FUSION 当帧跳过 confirm，防止残留输入立即触发
    if self._fusionJustEntered then
        self._fusionJustEntered = false
        return
    end

    -- 倒计时更新（失败提示）
    if self._fusionFailTimer > 0 then
        self._fusionFailTimer = self._fusionFailTimer - (love and love.timer and love.timer.getDelta() or 0.016)
        if self._fusionFailTimer <= 0 then
            self._fusionFailMsg   = nil
            self._fusionFailTimer = 0
        end
    end

    -- Enter：确认融合
    if Input.isPressed("confirm") then
        local result = Fusion.apply(self._bag, self._placing, self._fusionTarget, self._fusionRecipe)
        if result then
            -- 融合成功，清理状态
            local onPlace   = self._onPlace
            local onDiscard = self._onDiscard
            self._mode              = MODE_BROWSE
            self._placing           = nil
            self._fusionRecipe      = nil
            self._fusionTarget      = nil
            self._fusionOrigin      = nil
            self._fusionFailMsg     = nil
            self._fusionFailTimer   = 0
            self._onPlace           = nil
            self._onDiscard         = nil
            -- Bug#5：融合成功后也要调用 onPlace 回调（供 SELECT/升级流程返回游戏）
            if onPlace then onPlace() end
        else
            -- Bug#3：背包放不下，显示失败提示，保留 FUSION 界面让玩家看到原因再按 ESC
            self._fusionFailMsg   = T("bag.fusion.no_space")
            self._fusionFailTimer = 2.5
        end
    end

    -- ESC：取消融合，回到 PLACE 继续调整位置
    if Input.isPressed("cancel") then
        self._mode              = MODE_PLACE
        self._fusionRecipe      = nil
        self._fusionTarget      = nil
        self._fusionFailMsg     = nil
        self._fusionFailTimer   = 0
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

    -- Tab 标签（仅 BROWSE 模式）
    self:_drawPanelTabs()

    -- BROWSE 技能面板：隐藏背包网格，撑满全区
    local showSkillPanel = (self._mode == MODE_BROWSE) and (self._panelTab == "skill")

    if not showSkillPanel then
        -- 背包网格（武器面板 / PLACE / SELECT / FUSION 时显示）
        self:_drawGrid()

        -- 右侧面板
        if self._mode == MODE_PLACE or self._mode == MODE_SELECT or self._mode == MODE_FUSION then
            self:_drawDetail()
        else
            self:_drawDetail()
        end

        -- 右侧羁绊（空函数，占位）
        self:_drawSynergies()
    else
        -- 技能面板撑满全区
        self:_drawSkillPanel()
    end

    -- FUSION 模式：覆盖绘制融合预览浮窗
    if self._mode == MODE_FUSION then
        self:_drawFusionPreview()
    end

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
        end
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

        -- Phase 7.1：检测是否触发融合预览（高亮为金色）
        local fusionTarget = self:_getFusionTarget()
        local isFusionPreview = fusionTarget ~= nil
            and Fusion.findRecipe(self._placing.configId, fusionTarget.configId) ~= nil

        for _, cell in ipairs(cells) do
            if cell.row >= 1 and cell.row <= bag.rows
            and cell.col >= 1 and cell.col <= bag.cols then
                local px = GRID_X + (cell.col - 1) * CELL_SIZE
                local py = GRID_Y + (cell.row - 1) * CELL_SIZE
                if isFusionPreview then
                    love.graphics.setColor(1.0, 0.85, 0.1, 0.55)
                elseif canPlace then
                    love.graphics.setColor(0.2, 1.0, 0.3, 0.55)
                else
                    love.graphics.setColor(1.0, 0.2, 0.2, 0.55)
                end
                love.graphics.rectangle("fill", px + 2, py + 2, CELL_SIZE - 6, CELL_SIZE - 6, 3, 3)
                if isFusionPreview then
                    love.graphics.setColor(1.0, 0.85, 0.1, 0.95)
                elseif canPlace then
                    love.graphics.setColor(0.2, 1.0, 0.3, 0.9)
                else
                    love.graphics.setColor(1.0, 0.2, 0.2, 0.9)
                end
                love.graphics.setLineWidth(2)
                love.graphics.rectangle("line", px, py, CELL_SIZE - 2, CELL_SIZE - 2, 4, 4)
                love.graphics.setLineWidth(1)
            end
        end

        -- 融合预览时在目标武器上叠加金色高亮边框
        if isFusionPreview and fusionTarget and fusionTarget._bagRow then
            local tCells = fusionTarget:getCells(fusionTarget._bagRow, fusionTarget._bagCol)
            love.graphics.setColor(1.0, 0.7, 0.0, 0.5)
            for _, cell in ipairs(tCells) do
                local px = GRID_X + (cell.col - 1) * CELL_SIZE
                local py = GRID_Y + (cell.row - 1) * CELL_SIZE
                love.graphics.rectangle("fill", px + 2, py + 2, CELL_SIZE - 6, CELL_SIZE - 6, 3, 3)
            end
            love.graphics.setColor(1.0, 0.85, 0.1, 1.0)
            love.graphics.setLineWidth(3)
            for _, cell in ipairs(tCells) do
                local px = GRID_X + (cell.col - 1) * CELL_SIZE
                local py = GRID_Y + (cell.row - 1) * CELL_SIZE
                love.graphics.rectangle("line", px, py, CELL_SIZE - 2, CELL_SIZE - 2, 4, 4)
            end
            love.graphics.setLineWidth(1)
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
    -- Bug #27：武器名字 + 标签（方括号形式显示在名字同行）
    local cfg0 = WeaponConfig[w.configId]
    local cfgTags0 = cfg0 and cfg0.tags or {}
    love.graphics.setColor(col)
    local nameStr = T(w.nameKey)
    love.graphics.print(nameStr, panelX, panelY)
    if #cfgTags0 > 0 then
        local nameW = Font.get(15):getWidth(nameStr) + 8
        love.graphics.setColor(1.0, 0.85, 0.3)
        Font.set(13)
        local tagStr = ""
        for _, tg in ipairs(cfgTags0) do
            tagStr = tagStr .. "[" .. T("tag." .. tg) .. "]"
        end
        love.graphics.print(tagStr, panelX + nameW, panelY + 2)
        Font.set(15)
    end

    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.printf(T(w.descKey), panelX, panelY + 28, panelW, "left")

    local lh = 22
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(string.format("等级:   %d / %d",  w.level, w.maxLevel),             panelX, panelY + 72)
    love.graphics.print(string.format("伤害:   %d",       w.damage),                         panelX, panelY + 72 + lh)
    love.graphics.print(string.format("射速:   %.2f /s",  w.attackSpeed),                    panelX, panelY + 72 + lh * 2)
    love.graphics.print(string.format("弹速:   %d px/s",  w.bulletSpeed),                    panelX, panelY + 72 + lh * 3)
    love.graphics.print(string.format("射程:   %d px",    w.range),                          panelX, panelY + 72 + lh * 4)

    -- ── 被动效果（原 adjacencyBonus，现重新定义为武器的固有被动）──
    local cfg = WeaponConfig[w.configId]
    local curY = panelY + 72 + lh * 5 + 8
    if cfg and cfg.passiveKey then
        love.graphics.setColor(0.4, 0.9, 1.0)
        love.graphics.print("* 被动效果", panelX, curY)   -- Bug#7: 去掉 emoji 符号
        curY = curY + lh
        love.graphics.setColor(0.75, 0.92, 1.0)
        Font.set(13)
        love.graphics.printf(T(cfg.passiveKey), panelX + 4, curY, panelW - 4, "left")
        Font.set(15)
        curY = curY + lh
        -- 实际获得的相邻加成数值（来自邻居的加成）
        local adj = w._adjBonus
        local hasAdj = adj and (adj.damage ~= 0 or adj.attackSpeed ~= 0 or adj.range ~= 0 or adj.bulletSpeed ~= 0)
        if hasAdj then
            curY = curY + 4
            love.graphics.setColor(0.4, 0.9, 1.0)
            love.graphics.print("  > 当前加成:", panelX, curY)   -- Bug#7: 去掉 ▸
            curY = curY + lh
            Font.set(13)
            love.graphics.setColor(0.6, 0.85, 1.0)
            if adj.damage ~= 0      then love.graphics.print(string.format("    +%d 伤害", adj.damage),         panelX, curY) curY = curY + lh end
            if adj.attackSpeed ~= 0 then love.graphics.print(string.format("    +%.2f 射速", adj.attackSpeed), panelX, curY) curY = curY + lh end
            if adj.range ~= 0       then love.graphics.print(string.format("    +%d 射程", adj.range),         panelX, curY) curY = curY + lh end
            if adj.bulletSpeed ~= 0 then love.graphics.print(string.format("    +%d 弹速", adj.bulletSpeed),   panelX, curY) curY = curY + lh end
            Font.set(15)
        end
    else
        curY = panelY + 72 + lh * 5 + 8
    end

    -- ── Phase 7.2：显示该武器的 tags + 相关羁绊进度（Bug#18：合并入详情，只显示本武器的 tag）──
    local cfgTags = cfg and cfg.tags or {}
    if #cfgTags > 0 then
        curY = curY + 10
        love.graphics.setColor(1.0, 0.85, 0.3)
        Font.set(15)
        love.graphics.print("* 武器标签 & 羁绊", panelX, curY)
        curY = curY + lh

        local tagCounts    = self._bag._tagCounts or {}
        local activeSynIds = {}
        for _, s in ipairs(self._bag._activeSynergies or {}) do
            activeSynIds[s.id] = s
        end

        for _, tag in ipairs(cfgTags) do
            local tagCount = tagCounts[tag] or 0

            -- 找到该 tag 在 SynergyConfig 中的配置
            local tagEntry = nil
            for _, entry in ipairs(SynergyConfig) do
                if entry.tag == tag then tagEntry = entry; break end
            end
            if not tagEntry then goto continue end

            local maxCount = tagEntry.tiers[#tagEntry.tiers].count

            -- 找当前激活的最高档
            local activeTier = nil
            for _, tier in ipairs(tagEntry.tiers) do
                if activeSynIds[tier.id] then activeTier = tier end
            end

            -- 进度块
            local barStr = ""
            for _, tier in ipairs(tagEntry.tiers) do
                if tagCount >= tier.count then
                    barStr = barStr .. "█"
                elseif tagCount > 0 then
                    barStr = barStr .. "▒"
                else
                    barStr = barStr .. "░"
                end
            end

            -- tag 行：[速射] ██ 2/3
            Font.set(13)
            if activeTier then
                love.graphics.setColor(0.3, 1.0, 0.5)
            elseif tagCount > 0 then
                love.graphics.setColor(1.0, 0.85, 0.3)
            else
                love.graphics.setColor(0.45, 0.45, 0.45)
            end
            love.graphics.print(
                string.format("[%s]  %s  %d/%d", T("tag." .. tag), barStr, tagCount, maxCount),
                panelX, curY)
            curY = curY + lh - 4

            -- 激活效果行 / 还差 N 把
            Font.set(12)
            if activeTier then
                love.graphics.setColor(0.4, 1.0, 0.7)
                love.graphics.print("  + " .. T(activeTier.nameKey), panelX, curY)
                curY = curY + lh - 6
                love.graphics.setColor(0.55, 0.8, 0.6)
                love.graphics.printf("    " .. T(activeTier.descKey), panelX, curY, panelW - 4, "left")
                curY = curY + lh - 4
            elseif tagCount > 0 then
                for _, tier in ipairs(tagEntry.tiers) do
                    if tagCount < tier.count then
                        love.graphics.setColor(0.5, 0.5, 0.5)
                        love.graphics.print(
                            string.format("  还差 %d 把激活「%s」", tier.count - tagCount, T(tier.nameKey)),
                            panelX, curY)
                        curY = curY + lh - 6
                        break
                    end
                end
            end

            curY = curY + 2
            ::continue::
        end
        Font.set(15)
    end

    self._detailBottomY = curY + 16
end

-- Bug#18：羁绊进度条已合并入武器详情面板，此函数保留为空
function BagUI:_drawSynergies()
end

-- ============================================================
-- 面板 Tab 标签栏（Q=武器, E=技能）
-- ============================================================

function BagUI:_drawPanelTabs()
    -- PLACE / SELECT / FUSION 不显示切换 tab（强制武器面板）
    if self._mode ~= MODE_BROWSE then return end

    local tabX = GRID_X     -- 固定在内容区左边缘
    local tabY = GRID_Y - 28
    local tabW = 90
    local tabH = 22

    Font.set(13)

    local tabs = {
        { key = "weapon", label = "Q 武器" },
        { key = "skill",  label = "E 技能" },
    }
    local tx = tabX
    for _, tab in ipairs(tabs) do
        local active = (self._panelTab == tab.key)
        if active then
            love.graphics.setColor(0.25, 0.18, 0.5, 0.95)
            love.graphics.rectangle("fill", tx, tabY, tabW, tabH, 4, 4)
            love.graphics.setColor(0.7, 0.5, 1.0)
            love.graphics.rectangle("line", tx, tabY, tabW, tabH, 4, 4)
            love.graphics.setColor(1.0, 1.0, 1.0)
        else
            love.graphics.setColor(0.1, 0.1, 0.15, 0.8)
            love.graphics.rectangle("fill", tx, tabY, tabW, tabH, 4, 4)
            love.graphics.setColor(0.35, 0.35, 0.4)
            love.graphics.rectangle("line", tx, tabY, tabW, tabH, 4, 4)
            love.graphics.setColor(0.5, 0.5, 0.55)
        end
        love.graphics.printf(tab.label, tx, tabY + 4, tabW, "center")
        tx = tx + tabW + 6
    end

    Font.reset()
end

-- ============================================================
-- 辅助：返回技能面板的扁平列表（主动槽 + 被动）
-- 每项 { inst, slotKey }   slotKey=nil 表示被动
-- ============================================================

function BagUI:_getSkillList()
    if not self._player then return {} end
    local sm = self._player._skillManager
    if not sm then return {} end

    local list = {}
    local slotOrder = { "skill1", "skill2", "skill3", "skill4" }
    for _, sk in ipairs(slotOrder) do
        local inst = sm._slots[sk]
        if inst then
            table.insert(list, { inst = inst, slotKey = sk })
        end
    end
    for _, inst in ipairs(sm:getPassives()) do
        table.insert(list, { inst = inst, slotKey = nil })
    end

    -- Phase 10：将传承技能追加到列表末尾（金色角标「传承」区分）
    local legacy = self._player._legacyData
    if legacy then
        table.insert(list, { isLegacy = true, legacy = legacy })
    end

    return list
end

-- ============================================================
-- 技能面板：左列列表 + 右列详情
-- ============================================================

function BagUI:_drawSkillPanel()
    -- 撑满整个内容区（从 GRID_X 开始，横跨到右边）
    local areaX = GRID_X
    local areaY = GRID_Y
    local areaW = 1280 - areaX - 20

    -- 左列：技能列表
    local listW = 220
    -- 右列：技能详情
    local detX  = areaX + listW + 20
    local detW  = areaW - listW - 20

    local list = self:_getSkillList()

    if #list == 0 then
        Font.set(13)
        love.graphics.setColor(0.5, 0.5, 0.55)
        love.graphics.printf("（尚未获得任何技能）", areaX, areaY + 20, areaW, "left")
        love.graphics.setColor(0.35, 0.35, 0.4)
        Font.set(12)
        love.graphics.printf("升级时选择「技能获取」可以获得技能", areaX, areaY + 46, areaW, "left")
        Font.reset()
        return
    end

    -- 保证光标合法
    self._skillCursor = math.max(1, math.min(self._skillCursor, #list))

    local slotLabel = { skill1 = "空格", skill2 = "Q", skill3 = "E", skill4 = "F" }
    local typeLabel = {
        active         = "主动",
        passive_timed  = "自动被动",
        passive_onkill = "击杀被动",
        passive_onhit  = "受击被动",
        passive        = "纯被动",
    }

    -- ── 左列：技能列表 ──
    local lh   = 22
    local curY = areaY

    Font.set(13)
    love.graphics.setColor(0.5, 0.35, 0.9)
    love.graphics.print("技能列表", areaX, curY)
    curY = curY + lh

    for i, entry in ipairs(list) do
        local selected = (i == self._skillCursor)

        if selected then
            love.graphics.setColor(0.2, 0.12, 0.38, 0.9)
            love.graphics.rectangle("fill", areaX - 2, curY - 1, listW, lh, 3, 3)
            love.graphics.setColor(0.6, 0.4, 1.0)
            love.graphics.rectangle("line", areaX - 2, curY - 1, listW, lh, 3, 3)
            love.graphics.setColor(1.0, 1.0, 1.0)
        else
            love.graphics.setColor(0.7, 0.7, 0.75)
        end

        if entry.isLegacy then
            -- 传承条目：金色名称
            local name = T(entry.legacy.nameKey)
            if selected then
                love.graphics.setColor(1.0, 0.95, 0.6)
            else
                love.graphics.setColor(0.9, 0.78, 0.3)
            end
            love.graphics.print(name, areaX + 2, curY)
            -- 右侧「传承」金色角标
            Font.set(11)
            love.graphics.setColor(selected and 1.0 or 0.75, selected and 0.85 or 0.65, 0.2)
            love.graphics.printf("[传承]", areaX, curY + 2, listW - 2, "right")
            Font.set(13)
        else
            local inst = entry.inst
            local cfg  = inst.cfg

            -- 名称 + 等级
            local name = T(cfg.nameKey)
            love.graphics.print(name .. "  Lv" .. inst.level, areaX + 2, curY)

            -- 右侧小标签（按键 / 被动）
            Font.set(11)
            if entry.slotKey then
                love.graphics.setColor(selected and 0.8 or 0.45, selected and 0.6 or 0.35, selected and 1.0 or 0.7)
                love.graphics.printf("[" .. (slotLabel[entry.slotKey] or "?") .. "]",
                    areaX, curY + 2, listW - 2, "right")
            else
                love.graphics.setColor(selected and 0.6 or 0.4, selected and 0.85 or 0.6, selected and 0.6 or 0.45)
                love.graphics.printf("[被动]", areaX, curY + 2, listW - 2, "right")
            end
            Font.set(13)
        end

        curY = curY + lh
    end

    -- 分割线（列表和详情之间）
    love.graphics.setColor(0.3, 0.3, 0.4)
    love.graphics.line(detX - 10, areaY, detX - 10, areaY + 560)

    -- ── 右列：选中技能详情 ──
    local detY = areaY

    local sel = list[self._skillCursor]
    if not sel then
        Font.reset()
        return
    end

    -- Phase 10：传承条目单独渲染详情
    if sel.isLegacy then
        local leg = sel.legacy
        -- 标题（金色）
        Font.set(15)
        love.graphics.setColor(1.0, 0.88, 0.3)
        love.graphics.print(T(leg.nameKey), detX, detY)
        -- 「传承」标签
        Font.set(12)
        love.graphics.setColor(1.0, 0.75, 0.2)
        love.graphics.print("◈  传承被动  [" .. (leg.category or "?") .. "]", detX, detY + 22)
        -- 描述
        Font.set(13)
        love.graphics.setColor(0.68, 0.68, 0.68)
        love.graphics.printf(T(leg.descKey), detX, detY + 44, detW, "left")
        -- 分割线
        love.graphics.setColor(0.3, 0.3, 0.4)
        love.graphics.line(detX, detY + 90, detX + detW, detY + 90)
        -- 说明
        Font.set(12)
        love.graphics.setColor(0.55, 0.55, 0.55)
        love.graphics.printf("传承效果已在本局生效，作为隐形被动持续有效。\n下局开始时自动应用，不占用技能槽。", detX, detY + 102, detW, "left")
        Font.reset()
        return
    end

    local inst = sel.inst
    local cfg  = inst.cfg

    -- 技能名（大字，紫色）
    Font.set(15)
    love.graphics.setColor(0.75, 0.5, 1.0)
    love.graphics.print(T(cfg.nameKey), detX, detY)

    -- 类型 + 按键标签（同行）
    Font.set(13)
    local typeTxt = typeLabel[cfg.type] or cfg.type
    local keyTxt  = sel.slotKey and ("[" .. (slotLabel[sel.slotKey] or "?") .. "]") or "[被动]"
    love.graphics.setColor(0.55, 0.55, 0.65)
    love.graphics.print(typeTxt .. "  " .. keyTxt, detX, detY + 22)

    -- 描述（灰色，自动换行）
    love.graphics.setColor(0.68, 0.68, 0.68)
    love.graphics.printf(T(cfg.descKey), detX, detY + 44, detW, "left")

    -- 分割线
    local lineY = detY + 90
    love.graphics.setColor(0.3, 0.3, 0.4)
    love.graphics.line(detX, lineY, detX + detW, lineY)

    local statY = lineY + 10
    local slh   = 20
    Font.set(13)
    love.graphics.setColor(0.85, 0.85, 0.85)

    -- 等级
    love.graphics.print(string.format("等级:   %d / %d", inst.level, cfg.maxLevel or 1), detX, statY)
    statY = statY + slh

    -- CD / 间隔 / 触发条件
    if cfg.type == "active" or cfg.type == "passive_onhit" then
        local cd = cfg.cooldown or 0
        if cfg.levelBonus and cfg.levelBonus.cooldown then
            cd = math.max(0.5, cd + cfg.levelBonus.cooldown * (inst.level - 1))
        end
        love.graphics.print(string.format("冷却:   %.1f s", cd), detX, statY)
        statY = statY + slh
    elseif cfg.type == "passive_timed" then
        local interval = cfg.trigger and cfg.trigger.interval or 10
        if cfg.levelBonus and cfg.levelBonus.interval then
            interval = math.max(2, interval + cfg.levelBonus.interval * (inst.level - 1))
        end
        love.graphics.print(string.format("间隔:   %.0f s 自动触发", interval), detX, statY)
        statY = statY + slh
    elseif cfg.type == "passive_onkill" then
        local kc = cfg.trigger and cfg.trigger.killCount or 5
        love.graphics.print(string.format("触发:   每 %d 次击杀", kc), detX, statY)
        statY = statY + slh
    end

    -- 纯被动：显示加成数值
    if cfg.type == "passive" and cfg.passive then
        local p = cfg.passive
        local base    = p.base    or 0
        local lvBonus = p.lvBonus or 0
        local value   = base + lvBonus * (inst.level - 1)
        love.graphics.setColor(0.4, 1.0, 0.6)
        love.graphics.print(string.format("加成:   %s +%s", p.key, tostring(value)), detX, statY)
        statY = statY + slh
    end

    -- 升级加成预览（有 levelBonus 且未满级）
    if cfg.levelBonus and inst.level < (cfg.maxLevel or 1) then
        statY = statY + 4
        love.graphics.setColor(1.0, 0.85, 0.3)
        love.graphics.print("下一级:", detX, statY)
        statY = statY + slh
        Font.set(12)
        love.graphics.setColor(0.9, 0.8, 0.4)
        for k, v in pairs(cfg.levelBonus) do
            if k ~= "cooldown" and k ~= "interval" and k ~= "cd" then
                love.graphics.print(string.format("  %s +%s", k, tostring(v)), detX, statY)
                statY = statY + slh - 4
            end
        end
        Font.set(13)
    end

    -- 角色专属标记
    if cfg.characterId then
        statY = statY + 8
        love.graphics.setColor(1.0, 0.5, 0.2)
        love.graphics.print("★ 角色专属技能", detX, statY)
    end

    Font.reset()
end

-- 绘制底部操作提示
function BagUI:_drawHint()
    Font.set(13)
    love.graphics.setColor(0.5, 0.5, 0.5)
    if self._mode == MODE_BROWSE then
        if self._panelTab == "skill" then
            love.graphics.printf("方向键 上下选择技能  |  Q 武器面板  |  ESC 关闭", 0, 688, 1280, "center")
        else
            love.graphics.printf(T("bag.hint.browse"), 0, 688, 1280, "center")
        end
    elseif self._mode == MODE_PLACE then
        love.graphics.printf(T("bag.hint.place"), 0, 688, 1280, "center")
    elseif self._mode == MODE_SELECT then
        local hint = self._selectHint or T("bag.hint.select")
        love.graphics.printf(hint, 0, 688, 1280, "center")
    elseif self._mode == MODE_FUSION then
        love.graphics.printf(T("bag.hint.fusion"), 0, 688, 1280, "center")
    end
    Font.reset()
end

-- 绘制融合预览浮窗（Phase 7.1）
function BagUI:_drawFusionPreview()
    local recipe  = self._fusionRecipe
    local wA      = self._placing
    local wB      = self._fusionTarget
    if not recipe or not wA or not wB then return end

    local resultCfg = WeaponConfig[recipe.result]
    if not resultCfg then return end

    -- 浮窗尺寸和位置（Bug#16：加高以容纳 tags 行）
    local W, H   = 580, 390
    local bx     = (1280 - W) * 0.5
    local by     = (720  - H) * 0.5
    local lh     = 24

    -- 背景
    love.graphics.setColor(0.05, 0.05, 0.1, 0.96)
    love.graphics.rectangle("fill", bx, by, W, H, 10, 10)

    -- 外框（融合主题：金色）
    love.graphics.setColor(1.0, 0.8, 0.1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", bx, by, W, H, 10, 10)
    love.graphics.setLineWidth(1)

    -- 标题
    Font.set(18)
    love.graphics.setColor(1.0, 0.85, 0.1)
    love.graphics.printf(T("bag.fusion.title"), bx, by + 18, W, "center")

    -- 材料行：武器A  +  武器B  →  结果
    local midY = by + 68
    Font.set(15)

    -- 武器 A
    love.graphics.setColor(wA.color)
    love.graphics.printf(T(wA.nameKey), bx + 20, midY, 150, "center")

    -- + 符号
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("+", bx + 175, midY, 40, "center")

    -- 武器 B
    love.graphics.setColor(wB.color)
    love.graphics.printf(T(wB.nameKey), bx + 220, midY, 150, "center")

    -- → 符号
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("→", bx + 375, midY, 40, "center")

    -- 结果武器名
    love.graphics.setColor(resultCfg.color)
    love.graphics.printf(T(resultCfg.nameKey), bx + 420, midY, 120, "center")

    -- 分割线
    love.graphics.setColor(0.3, 0.3, 0.4)
    love.graphics.line(bx + 20, midY + 30, bx + W - 20, midY + 30)

    -- 结果武器属性
    Font.set(14)
    local statY = midY + 44
    love.graphics.setColor(0.85, 0.85, 0.85)
    -- Bug#4/#19：正确计算结果武器占格尺寸（遍历 shape 求最大 row/col）
    local shape = resultCfg.shape or {{0,0}}
    local maxR, maxC = 0, 0
    for _, cell in ipairs(shape) do
        if cell[1] > maxR then maxR = cell[1] end
        if cell[2] > maxC then maxC = cell[2] end
    end
    local rows = maxR + 1
    local cols = maxC + 1
    love.graphics.print(string.format("伤害:  %d     射速: %.2f/s     射程: %d px     弹速: %d px/s     尺寸: %d×%d",
        resultCfg.damage, resultCfg.attackSpeed, resultCfg.range, resultCfg.bulletSpeed, rows, cols),
        bx + 30, statY)
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.printf(T(resultCfg.descKey), bx + 30, statY + lh, W - 60, "left")

    -- Bug#9：显示融合结果武器的被动效果
    if resultCfg.passiveKey then
        Font.set(13)
        local passY = statY + lh * 2 + 4
        love.graphics.setColor(0.4, 0.9, 1.0)
        love.graphics.print("* 被动效果: ", bx + 30, passY)
        love.graphics.setColor(0.75, 0.92, 1.0)
        love.graphics.printf(T(resultCfg.passiveKey), bx + 110, passY, W - 140, "left")
        Font.set(14)
    end

    -- Bug#16：显示融合结果武器的标签
    local resultTags = resultCfg.tags or {}
    if #resultTags > 0 then
        Font.set(13)
        local tagY = statY + lh * 3 + 8
        love.graphics.setColor(1.0, 0.85, 0.3)
        love.graphics.print("* 标签: ", bx + 30, tagY)
        local tx = bx + 90
        for _, tag in ipairs(resultTags) do
            love.graphics.setColor(0.9, 0.8, 0.3)
            love.graphics.print("[" .. T("tag." .. tag) .. "]", tx, tagY)
            tx = tx + Font.get(13):getWidth("[" .. T("tag." .. tag) .. "]") + 6
        end
        Font.set(14)
    end

    -- Bug#3：融合失败提示（背包空间不足）
    if self._fusionFailMsg then
        Font.set(15)
        love.graphics.setColor(1.0, 0.3, 0.3)
        love.graphics.printf(self._fusionFailMsg, bx, by + H - 82, W, "center")
    end

    -- 警告：消耗提示
    Font.set(13)
    love.graphics.setColor(1.0, 0.5, 0.3)
    love.graphics.printf(
        T("bag.fusion.warning", T(wA.nameKey), T(wB.nameKey)),
        bx + 20, by + H - 58, W - 40, "center")

    -- 操作提示（由 _drawHint 覆盖在底部，此处不重复）
    Font.set(15)
end

return BagUI
