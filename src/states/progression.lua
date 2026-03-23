--[[
    src/states/progression.lua
    局外成长界面 — Phase 13
    push/pop 覆盖层，两个面板：
      · 通用加成（6 个属性，消耗通用点数升级）
      · 英雄技能树（按 trunk A/B 分列，消耗里程碑点数解锁）
]]

local Input              = require("src.systems.input")
local Font               = require("src.utils.font")
local ProgressionManager = require("src.systems.progressionManager")
local CharacterConfig    = require("config.characters")

local Progression = {}

-- ============================================================
-- 常量
-- ============================================================
local SCREEN_W = 1280
local SCREEN_H = 720

-- 面板 Tab 枚举
local TAB_COMMON = "common"
local TAB_TREE   = "tree"

-- 通用属性列表（固定顺序，与 progressionManager 中的 COMMON_ATTRS 对应）
local COMMON_ATTR_ORDER = {
    { id = "attack",   nameKey = "progression.attr.attack",   fmtKey = "progression.common.attack"  },
    { id = "speed",    nameKey = "progression.attr.speed",    fmtKey = "progression.common.speed"   },
    { id = "maxhp",    nameKey = "progression.attr.maxhp",    fmtKey = "progression.common.maxhp"   },
    { id = "critrate", nameKey = "progression.attr.critrate", fmtKey = "progression.common.critrate"},
    { id = "pickup",   nameKey = "progression.attr.pickup",   fmtKey = "progression.common.pickup"  },
    { id = "expmult",  nameKey = "progression.attr.expmult",  fmtKey = "progression.common.expmult" },
}

-- 通用属性名称（直接硬编码，因 i18n 目前未注册 progression.attr.* key，此处作备用）
local ATTR_NAMES = {
    attack   = "攻击力",
    speed    = "移速",
    maxhp    = "最大HP",
    critrate = "暴击率",
    pickup   = "拾取范围",
    expmult  = "经验获取",
}

-- 通用属性最大等级与每级费用（与 progressionManager.lua 中 COMMON_ATTRS 保持同步）
local COMMON_ATTR_DEFS = {
    attack   = { maxLevel = 5, costPerLevel = 10, bonusPerLevel = 5  },
    speed    = { maxLevel = 5, costPerLevel = 8,  bonusPerLevel = 5  },
    maxhp    = { maxLevel = 5, costPerLevel = 8,  bonusPerLevel = 10 },
    critrate = { maxLevel = 3, costPerLevel = 15, bonusPerLevel = 3  },
    pickup   = { maxLevel = 3, costPerLevel = 8,  bonusPerLevel = 10 },
    expmult  = { maxLevel = 3, costPerLevel = 12, bonusPerLevel = 10 },
}

-- 通知消息显示时长（秒）
local NOTICE_DURATION = 1.8

-- ============================================================
-- 界面布局
-- ============================================================
local PANEL_X     = 60
local PANEL_Y     = 130
local PANEL_W     = SCREEN_W - 120
local PANEL_H     = SCREEN_H - 180
local ROW_H       = 52
local LIST_W      = 420     -- 通用加成列表宽
local DETAIL_X    = PANEL_X + LIST_W + 40  -- 右侧说明起始 X
local DETAIL_W    = PANEL_W - LIST_W - 40

-- 技能树列宽
local TREE_COL_W  = (PANEL_W - 40) / 2
local TREE_NODE_H = 64

-- ============================================================
-- enter / exit
-- ============================================================

--- 进入界面
--- @param data table  { characterId: string }
function Progression:enter(data)
    data = data or {}
    self._charId     = data.characterId or "engineer"
    self._tab        = TAB_COMMON
    self._commonIdx  = 1   -- 通用面板当前选中行（1~6）
    self._treeIdx    = 1   -- 技能树面板当前选中节点（在 _flatNodes 中的下标）
    self._noticeText = nil
    self._noticeTimer = 0

    -- 构建技能树扁平节点列表（A 列先、B 列后，整体按 trunk+顺序）
    self._flatNodes = self:_buildFlatNodes()

    -- 防止上一帧输入残留
    Input.update()
end

--- 退出界面
function Progression:exit()
    self._charId     = nil
    self._flatNodes  = nil
    self._noticeText = nil
end

-- ============================================================
-- 内部：构建扁平节点列表
-- ============================================================

--- 将角色技能树按 trunk 分组后合并为顺序列表
--- 列表项格式：{ node = nodeDef, trunk = "A"/"B", idxInTrunk = n }
function Progression:_buildFlatNodes()
    local charCfg = CharacterConfig[self._charId]
    if not charCfg or not charCfg.skillTree then return {} end

    local trunkA, trunkB = {}, {}
    for _, node in ipairs(charCfg.skillTree) do
        if node.trunk == "A" then
            table.insert(trunkA, node)
        else
            table.insert(trunkB, node)
        end
    end

    local flat = {}
    for i, n in ipairs(trunkA) do
        table.insert(flat, { node = n, trunk = "A", idxInTrunk = i })
    end
    for i, n in ipairs(trunkB) do
        table.insert(flat, { node = n, trunk = "B", idxInTrunk = i })
    end
    return flat
end

-- ============================================================
-- update
-- ============================================================

function Progression:update(dt)
    Input.update()

    -- 通知计时
    if self._noticeText then
        self._noticeTimer = self._noticeTimer - dt
        if self._noticeTimer <= 0 then
            self._noticeText  = nil
            self._noticeTimer = 0
        end
    end

    -- Tab 切换：Q / E（Bug#54：bagLeft/bagRight不存在，改为 skill2/skill3）
    if Input.isPressed("skill2") then        -- Q
        self._tab = TAB_COMMON
    elseif Input.isPressed("skill3") then   -- E
        self._tab = TAB_TREE
    end

    if self._tab == TAB_COMMON then
        self:_updateCommon()
    else
        self:_updateTree()
    end

    -- ESC 返回
    if Input.isPressed("cancel") then
        local SM = require("src.states.stateManager")
        SM.pop()
    end
end

--- 通用加成面板输入处理
function Progression:_updateCommon()
    local n = #COMMON_ATTR_ORDER
    if Input.isPressed("moveUp") then
        self._commonIdx = math.max(1, self._commonIdx - 1)
    elseif Input.isPressed("moveDown") then
        self._commonIdx = math.min(n, self._commonIdx + 1)
    elseif Input.isPressed("confirm") then
        local attr = COMMON_ATTR_ORDER[self._commonIdx].id
        local ok = ProgressionManager.upgradeCommon(attr)
        if ok then
            self:_showNotice("✓ 升级成功！")
        else
            local def = COMMON_ATTR_DEFS[attr]
            local lv  = ProgressionManager.getCommonLevel(attr)
            if lv >= def.maxLevel then
                self:_showNotice("已达最大等级")
            else
                self:_showNotice(T("progression.insufficient"))
            end
        end
    end
end

--- 技能树面板输入处理
function Progression:_updateTree()
    local n = #self._flatNodes
    if n == 0 then return end

    if Input.isPressed("moveUp") then
        self._treeIdx = math.max(1, self._treeIdx - 1)
    elseif Input.isPressed("moveDown") then
        self._treeIdx = math.min(n, self._treeIdx + 1)
    elseif Input.isPressed("confirm") then
        local item   = self._flatNodes[self._treeIdx]
        if not item then return end
        local nodeId = item.node.id
        local ok = ProgressionManager.unlockNode(self._charId, nodeId)
        if ok then
            self:_showNotice("✓ 节点已解锁！")
        else
            -- 判断原因
            if ProgressionManager.isNodeUnlocked(self._charId, nodeId) then
                self:_showNotice(T("progression.unlocked"))
            else
                -- 检查前置
                local hasPre = true
                for _, reqId in ipairs(item.node.requires or {}) do
                    if not ProgressionManager.isNodeUnlocked(self._charId, reqId) then
                        hasPre = false
                        break
                    end
                end
                if not hasPre then
                    self:_showNotice(T("progression.locked"))
                else
                    self:_showNotice(T("progression.insufficient"))
                end
            end
        end
    end
end

--- 显示临时通知
function Progression:_showNotice(text)
    self._noticeText  = text
    self._noticeTimer = NOTICE_DURATION
end

-- ============================================================
-- draw
-- ============================================================

function Progression:draw()
    -- 半透明遮罩背景
    love.graphics.setColor(0, 0, 0, 0.82)
    love.graphics.rectangle("fill", 0, 0, SCREEN_W, SCREEN_H)

    -- 标题
    Font.set(28)
    love.graphics.setColor(1.0, 0.85, 0.2)
    love.graphics.printf(T("progression.title"), 0, 22, SCREEN_W, "center")

    -- Tab 切换栏
    self:_drawTabs()

    -- 面板内容
    if self._tab == TAB_COMMON then
        self:_drawCommonPanel()
    else
        self:_drawTreePanel()
    end

    -- 通知
    if self._noticeText then
        self:_drawNotice()
    end

    -- 操作提示
    Font.set(14)
    love.graphics.setColor(0.45, 0.45, 0.5)
    love.graphics.printf(T("progression.hint"), 0, SCREEN_H - 28, SCREEN_W, "center")

    Font.reset()
    love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================
-- 绘制：Tab 栏
-- ============================================================
function Progression:_drawTabs()
    local tabs = {
        { id = TAB_COMMON, label = T("progression.tab.common") },
        { id = TAB_TREE,   label = T("progression.tab.tree")   },
    }
    local tabW  = 200
    local tabH  = 36
    local tabY  = 68
    local startX = (SCREEN_W - #tabs * tabW - (#tabs - 1) * 10) / 2

    for i, tab in ipairs(tabs) do
        local tx       = startX + (i - 1) * (tabW + 10)
        local selected = (self._tab == tab.id)

        if selected then
            love.graphics.setColor(0.2, 0.5, 0.9, 0.9)
        else
            love.graphics.setColor(0.15, 0.15, 0.2, 0.85)
        end
        love.graphics.rectangle("fill", tx, tabY, tabW, tabH, 6, 6)

        if selected then
            love.graphics.setColor(0.4, 0.7, 1.0)
        else
            love.graphics.setColor(0.35, 0.35, 0.45)
        end
        love.graphics.rectangle("line", tx, tabY, tabW, tabH, 6, 6)

        Font.set(16)
        if selected then
            love.graphics.setColor(1.0, 1.0, 1.0)
        else
            love.graphics.setColor(0.65, 0.65, 0.7)
        end
        love.graphics.printf(tab.label, tx, tabY + 9, tabW, "center")
    end
end

-- ============================================================
-- 绘制：通用加成面板
-- ============================================================
function Progression:_drawCommonPanel()
    -- 当前通用点数
    local pts = ProgressionManager.getCommonPoints()
    Font.set(17)
    love.graphics.setColor(0.9, 0.75, 0.2)
    love.graphics.printf(
        string.format(T("progression.points"), pts),
        PANEL_X, PANEL_Y - 4, PANEL_W, "left")

    -- 列表标题栏
    local headerY = PANEL_Y + 26
    Font.set(13)
    love.graphics.setColor(0.5, 0.5, 0.55)
    love.graphics.print("属性",       PANEL_X + 16,         headerY)
    love.graphics.print("等级",       PANEL_X + 170,        headerY)
    love.graphics.print("当前加成",   PANEL_X + 240,        headerY)
    love.graphics.print("升级费用",   PANEL_X + 340,        headerY)

    -- 分隔线
    love.graphics.setColor(0.25, 0.25, 0.3)
    love.graphics.rectangle("fill", PANEL_X, headerY + 18, LIST_W, 1)

    -- 属性列表
    local listStartY = headerY + 26
    for i, attr in ipairs(COMMON_ATTR_ORDER) do
        local ry       = listStartY + (i - 1) * ROW_H
        local selected = (i == self._commonIdx)
        local def      = COMMON_ATTR_DEFS[attr.id]
        local lv       = ProgressionManager.getCommonLevel(attr.id)
        local bonus    = lv * def.bonusPerLevel
        local maxed    = (lv >= def.maxLevel)

        -- 行背景
        if selected then
            love.graphics.setColor(0.15, 0.3, 0.6, 0.85)
            love.graphics.rectangle("fill", PANEL_X, ry, LIST_W, ROW_H - 4, 5, 5)
            love.graphics.setColor(0.3, 0.55, 1.0)
            love.graphics.rectangle("line", PANEL_X, ry, LIST_W, ROW_H - 4, 5, 5)
        else
            love.graphics.setColor(0.1, 0.1, 0.14, 0.75)
            love.graphics.rectangle("fill", PANEL_X, ry, LIST_W, ROW_H - 4, 5, 5)
        end

        -- 选中箭头
        if selected then
            Font.set(14)
            love.graphics.setColor(0.4, 0.7, 1.0)
            love.graphics.print("▶", PANEL_X + 4, ry + (ROW_H - 4) / 2 - 7)
        end

        -- 属性名
        Font.set(15)
        if selected then
            love.graphics.setColor(1.0, 1.0, 1.0)
        else
            love.graphics.setColor(0.82, 0.82, 0.85)
        end
        love.graphics.print(ATTR_NAMES[attr.id], PANEL_X + 20, ry + 10)

        -- 等级
        Font.set(14)
        if maxed then
            love.graphics.setColor(1.0, 0.75, 0.2)
        else
            love.graphics.setColor(0.7, 0.9, 0.7)
        end
        love.graphics.print(
            string.format("Lv.%d/%d", lv, def.maxLevel),
            PANEL_X + 170, ry + 10)

        -- 当前加成数值
        Font.set(14)
        love.graphics.setColor(0.55, 0.85, 1.0)
        local bonusStr = self:_formatBonus(attr.id, bonus)
        love.graphics.print(bonusStr, PANEL_X + 240, ry + 10)

        -- 升级费用
        Font.set(14)
        if maxed then
            love.graphics.setColor(0.5, 0.5, 0.5)
            love.graphics.print("MAX", PANEL_X + 340, ry + 10)
        else
            local costColor = (pts >= def.costPerLevel) and {0.9, 0.85, 0.3} or {0.8, 0.3, 0.3}
            love.graphics.setColor(costColor)
            love.graphics.print(tostring(def.costPerLevel) .. " 点", PANEL_X + 340, ry + 10)
        end
    end

    -- 右侧详情说明（选中属性的展开说明）
    self:_drawCommonDetail()
end

--- 格式化通用加成显示值
function Progression:_formatBonus(attrId, bonus)
    if attrId == "maxhp" then
        return string.format("+%d HP", bonus)
    elseif attrId == "attack" or attrId == "speed" or
           attrId == "pickup" or attrId == "expmult" then
        return string.format("+%d%%", bonus)
    elseif attrId == "critrate" then
        return string.format("+%d%%", bonus)
    end
    return string.format("+%d", bonus)
end

--- 绘制右侧说明框
function Progression:_drawCommonDetail()
    local attr     = COMMON_ATTR_ORDER[self._commonIdx]
    local def      = COMMON_ATTR_DEFS[attr.id]
    local lv       = ProgressionManager.getCommonLevel(attr.id)

    local bx = DETAIL_X
    local by = PANEL_Y + 22
    local bw = DETAIL_W
    local bh = 220

    -- 外框
    love.graphics.setColor(0.12, 0.14, 0.2, 0.9)
    love.graphics.rectangle("fill", bx, by, bw, bh, 8, 8)
    love.graphics.setColor(0.25, 0.4, 0.7, 0.7)
    love.graphics.rectangle("line", bx, by, bw, bh, 8, 8)

    -- 属性名
    Font.set(20)
    love.graphics.setColor(1.0, 0.9, 0.5)
    love.graphics.printf(ATTR_NAMES[attr.id], bx + 16, by + 16, bw - 32, "left")

    -- 等级进度条
    Font.set(14)
    love.graphics.setColor(0.65, 0.65, 0.7)
    love.graphics.print(string.format("当前等级：%d / %d", lv, def.maxLevel), bx + 16, by + 52)

    -- 进度条背景
    local barX = bx + 16
    local barY = by + 74
    local barW = bw - 32
    local barH = 10
    love.graphics.setColor(0.2, 0.2, 0.25)
    love.graphics.rectangle("fill", barX, barY, barW, barH, 4, 4)
    -- 进度填充
    local ratio = lv / def.maxLevel
    if ratio > 0 then
        love.graphics.setColor(0.3, 0.6, 1.0)
        love.graphics.rectangle("fill", barX, barY, barW * ratio, barH, 4, 4)
    end

    -- 当前加成
    local bonus = lv * def.bonusPerLevel
    Font.set(15)
    love.graphics.setColor(0.6, 0.9, 0.7)
    love.graphics.print("当前加成：" .. self:_formatBonus(attr.id, bonus), bx + 16, by + 94)

    -- 下一级加成（若未满级）
    if lv < def.maxLevel then
        local nextBonus = (lv + 1) * def.bonusPerLevel
        love.graphics.setColor(0.85, 0.85, 0.5)
        love.graphics.print("升级后：" .. self:_formatBonus(attr.id, nextBonus), bx + 16, by + 118)

        -- 费用
        local pts = ProgressionManager.getCommonPoints()
        local affordable = (pts >= def.costPerLevel)
        if affordable then
            love.graphics.setColor(0.3, 0.9, 0.4)
        else
            love.graphics.setColor(0.9, 0.3, 0.3)
        end
        love.graphics.print(
            string.format("费用：%d 点（当前：%d 点）", def.costPerLevel, pts),
            bx + 16, by + 142)

        Font.set(14)
        if affordable then
            love.graphics.setColor(0.4, 0.8, 0.4)
            love.graphics.printf("[ Enter 升级 ]", bx, by + 170, bw, "center")
        else
            love.graphics.setColor(0.6, 0.3, 0.3)
            love.graphics.printf("点数不足，无法升级", bx, by + 170, bw, "center")
        end
    else
        Font.set(15)
        love.graphics.setColor(1.0, 0.75, 0.2)
        love.graphics.printf("★ 已达最大等级", bx, by + 130, bw, "center")
    end
end

-- ============================================================
-- 绘制：英雄技能树面板
-- ============================================================
function Progression:_drawTreePanel()
    local charCfg = CharacterConfig[self._charId]
    if not charCfg then return end

    -- 当前里程碑点数
    local mpts = ProgressionManager.getMilestonePoints(self._charId)
    Font.set(17)
    love.graphics.setColor(0.75, 0.6, 1.0)
    love.graphics.printf(
        string.format("里程碑点数：%d", mpts),
        PANEL_X, PANEL_Y - 4, PANEL_W, "left")

    -- 角色名 + 颜色
    local charColor = charCfg.color or {0.7, 0.7, 0.9}
    Font.set(17)
    love.graphics.setColor(charColor)
    love.graphics.printf(T(charCfg.nameKey), PANEL_X, PANEL_Y - 4, PANEL_W, "right")

    -- 主干标题
    local colAX = PANEL_X
    local colBX = PANEL_X + TREE_COL_W + 20
    local titleY = PANEL_Y + 28

    Font.set(15)
    love.graphics.setColor(0.5, 0.75, 1.0)
    love.graphics.printf("主干 A", colAX, titleY, TREE_COL_W, "center")
    love.graphics.setColor(1.0, 0.6, 0.4)
    love.graphics.printf("主干 B", colBX, titleY, TREE_COL_W, "center")

    -- 分隔线
    love.graphics.setColor(0.25, 0.25, 0.3)
    love.graphics.rectangle("fill", PANEL_X, titleY + 20, PANEL_W, 1)

    -- 绘制节点列表
    local nodeStartY = titleY + 30
    local trunkAIdx  = 0
    local trunkBIdx  = 0

    for i, item in ipairs(self._flatNodes) do
        local node     = item.node
        local isA      = (item.trunk == "A")
        local selected = (i == self._treeIdx)

        -- 计算该节点 Y 坐标（按 trunk 内序号）
        local nx, ny
        if isA then
            trunkAIdx = trunkAIdx + 1
            nx = colAX
            ny = nodeStartY + (trunkAIdx - 1) * (TREE_NODE_H + 8)
        else
            trunkBIdx = trunkBIdx + 1
            nx = colBX
            ny = nodeStartY + (trunkBIdx - 1) * (TREE_NODE_H + 8)
        end

        local nw = TREE_COL_W - 10

        -- 解锁状态
        local unlocked = ProgressionManager.isNodeUnlocked(self._charId, node.id)
        local canUnlock = self:_canUnlock(node)
        local hasPoints = mpts >= (node.cost or 0)

        -- 节点背景颜色
        if unlocked then
            love.graphics.setColor(0.1, 0.28, 0.15, 0.9)
        elseif selected then
            love.graphics.setColor(0.15, 0.2, 0.38, 0.9)
        elseif canUnlock and hasPoints then
            love.graphics.setColor(0.12, 0.12, 0.22, 0.85)
        else
            love.graphics.setColor(0.08, 0.08, 0.1, 0.75)
        end
        love.graphics.rectangle("fill", nx, ny, nw, TREE_NODE_H - 4, 5, 5)

        -- 边框
        if selected then
            local bc = isA and {0.4, 0.7, 1.0} or {1.0, 0.55, 0.3}
            love.graphics.setColor(bc)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", nx, ny, nw, TREE_NODE_H - 4, 5, 5)
            love.graphics.setLineWidth(1)
        elseif unlocked then
            love.graphics.setColor(0.3, 0.7, 0.4, 0.8)
            love.graphics.rectangle("line", nx, ny, nw, TREE_NODE_H - 4, 5, 5)
        else
            love.graphics.setColor(0.2, 0.2, 0.28)
            love.graphics.rectangle("line", nx, ny, nw, TREE_NODE_H - 4, 5, 5)
        end

        -- 图标（状态符号）
        Font.set(15)
        local icon
        if unlocked then
            love.graphics.setColor(0.4, 0.9, 0.5)
            icon = "✓"
        elseif canUnlock and hasPoints then
            love.graphics.setColor(0.8, 0.8, 0.3)
            icon = "○"
        else
            love.graphics.setColor(0.4, 0.4, 0.45)
            icon = "🔒"
        end
        love.graphics.print(icon, nx + 8, ny + (TREE_NODE_H - 4) / 2 - 8)

        -- 节点名称
        Font.set(14)
        if unlocked then
            love.graphics.setColor(0.7, 1.0, 0.75)
        elseif selected then
            love.graphics.setColor(1.0, 1.0, 1.0)
        elseif canUnlock and hasPoints then
            love.graphics.setColor(0.9, 0.9, 0.9)
        else
            love.graphics.setColor(0.45, 0.45, 0.5)
        end
        love.graphics.print(T(node.nameKey), nx + 30, ny + 8)

        -- 消耗点数
        Font.set(12)
        if unlocked then
            love.graphics.setColor(0.4, 0.7, 0.45)
            love.graphics.print("已解锁", nx + 30, ny + 28)
        else
            if hasPoints then
                love.graphics.setColor(0.75, 0.7, 0.3)
            else
                love.graphics.setColor(0.7, 0.3, 0.3)
            end
            love.graphics.print(string.format("消耗 %d 点", node.cost or 0), nx + 30, ny + 28)
        end

        -- 选中时右侧显示描述（仅选中节点）
        if selected then
            self:_drawNodeDetail(node, unlocked, canUnlock, mpts)
        end
    end
end

--- 检查某节点的前置是否全部解锁
function Progression:_canUnlock(node)
    if not node.requires or #node.requires == 0 then return true end
    for _, reqId in ipairs(node.requires) do
        if not ProgressionManager.isNodeUnlocked(self._charId, reqId) then
            return false
        end
    end
    return true
end

--- 绘制技能树节点右侧详情
function Progression:_drawNodeDetail(node, unlocked, canUnlock, mpts)
    local bx = PANEL_X + PANEL_W / 2 + 10
    local by = PANEL_Y + 54
    local bw = PANEL_W / 2 - 10
    local bh = 200

    love.graphics.setColor(0.1, 0.1, 0.18, 0.92)
    love.graphics.rectangle("fill", bx, by, bw, bh, 8, 8)
    love.graphics.setColor(0.25, 0.3, 0.55)
    love.graphics.rectangle("line", bx, by, bw, bh, 8, 8)

    -- 节点名
    Font.set(18)
    love.graphics.setColor(1.0, 0.9, 0.6)
    love.graphics.printf(T(node.nameKey), bx + 12, by + 12, bw - 24, "left")

    -- 描述
    Font.set(14)
    love.graphics.setColor(0.8, 0.82, 0.85)
    love.graphics.printf(T(node.descKey), bx + 12, by + 42, bw - 24, "left")

    -- 费用与点数状态
    Font.set(13)
    local costY = by + 110
    if unlocked then
        love.graphics.setColor(0.4, 0.85, 0.5)
        love.graphics.printf(T("progression.unlocked"), bx, costY, bw, "center")
    else
        -- 前置状态
        if not canUnlock then
            love.graphics.setColor(0.75, 0.4, 0.4)
            love.graphics.printf(T("progression.locked"), bx, costY, bw, "center")
        else
            local enough = mpts >= (node.cost or 0)
            if enough then
                love.graphics.setColor(0.4, 0.8, 0.4)
                love.graphics.printf(
                    string.format(T("progression.unlock"), node.cost or 0),
                    bx, costY, bw, "center")
            else
                love.graphics.setColor(0.85, 0.35, 0.35)
                love.graphics.printf(
                    string.format("需要 %d 点（当前 %d 点）", node.cost or 0, mpts),
                    bx, costY, bw, "center")
            end

            Font.set(14)
            if enough then
                love.graphics.setColor(0.35, 0.75, 0.35)
                love.graphics.printf("[ Enter 解锁 ]", bx, costY + 28, bw, "center")
            end
        end
    end
end

-- ============================================================
-- 绘制：临时通知提示
-- ============================================================
function Progression:_drawNotice()
    local alpha = math.min(1.0, self._noticeTimer / 0.3)
    if self._noticeTimer < 0.5 then
        alpha = self._noticeTimer / 0.5
    end

    Font.set(16)
    local tw = 280
    local tx = (SCREEN_W - tw) / 2
    local ty = SCREEN_H / 2 - 60

    love.graphics.setColor(0.08, 0.12, 0.08, 0.88 * alpha)
    love.graphics.rectangle("fill", tx, ty, tw, 40, 6, 6)
    love.graphics.setColor(0.3, 0.8, 0.4, alpha)
    love.graphics.rectangle("line", tx, ty, tw, 40, 6, 6)
    love.graphics.setColor(0.8, 1.0, 0.8, alpha)
    love.graphics.printf(self._noticeText, tx, ty + 10, tw, "center")
end

-- ============================================================
-- keypressed（Input 系统统一处理，此处留空）
-- ============================================================
function Progression:keypressed(key)
end

return Progression
