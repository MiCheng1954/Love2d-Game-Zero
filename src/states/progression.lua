--[[
    src/states/progression.lua
    局外成长界面 — Phase 13
    push/pop 覆盖层，两个面板：
      · 通用加成（左：6 属性升级列表 + 右：通用机制树星形扩散图）
      · 英雄技能树（按 trunk A/B 分列，消耗里程碑点数解锁）
]]

local Input              = require("src.systems.input")
local Font               = require("src.utils.font")
local ProgressionManager = require("src.systems.progressionManager")
local CharacterConfig    = require("config.characters")

-- 安全加载通用机制树配置（文件缺失时不崩溃）
local _treeConfigOk, ProgressionTreeConfig = pcall(require, "config.progressionTree")
if not _treeConfigOk then ProgressionTreeConfig = {} end

local Progression = {}

-- ============================================================
-- 常量
-- ============================================================
local SCREEN_W = 1280
local SCREEN_H = 720

-- 面板 Tab 枚举
local TAB_COMMON = "common"
local TAB_TREE   = "tree"

-- Tab 1 焦点枚举：左侧属性列表 / 右侧机制树
local FOCUS_LIST = "list"
local FOCUS_GRAPH = "graph"

-- 通用属性列表（固定顺序，与 progressionManager 中的 COMMON_ATTRS 对应）
local COMMON_ATTR_ORDER = {
    { id = "attack",   nameKey = "progression.attr.attack",   fmtKey = "progression.common.attack"  },
    { id = "speed",    nameKey = "progression.attr.speed",    fmtKey = "progression.common.speed"   },
    { id = "maxhp",    nameKey = "progression.attr.maxhp",    fmtKey = "progression.common.maxhp"   },
    { id = "critrate", nameKey = "progression.attr.critrate", fmtKey = "progression.common.critrate"},
    { id = "pickup",   nameKey = "progression.attr.pickup",   fmtKey = "progression.common.pickup"  },
    { id = "expmult",  nameKey = "progression.attr.expmult",  fmtKey = "progression.common.expmult" },
}

-- 通用属性名称
local ATTR_NAMES = {
    attack   = "攻击力",
    speed    = "移速",
    maxhp    = "最大HP",
    critrate = "暴击率",
    pickup   = "拾取范围",
    expmult  = "经验获取",
}

-- 通用属性最大等级与每级费用
local COMMON_ATTR_DEFS = {
    attack   = { maxLevel = 5, costPerLevel = 10, bonusPerLevel = 5  },
    speed    = { maxLevel = 5, costPerLevel = 8,  bonusPerLevel = 5  },
    maxhp    = { maxLevel = 5, costPerLevel = 8,  bonusPerLevel = 10 },
    critrate = { maxLevel = 3, costPerLevel = 15, bonusPerLevel = 3  },
    pickup   = { maxLevel = 3, costPerLevel = 8,  bonusPerLevel = 10 },
    expmult  = { maxLevel = 3, costPerLevel = 12, bonusPerLevel = 10 },
}

-- 通用机制树：5维度定义（顺序决定扩散方向）
local TREE_DIMS = {
    { id = "attack",  label = "攻击",    color = {1.0, 0.4, 0.3},  angle = -math.pi/2           },  -- 上
    { id = "survive", label = "生存",    color = {0.3, 0.9, 0.4},  angle = -math.pi/2 + math.pi*2/5 },  -- 右上
    { id = "weapon",  label = "武器",    color = {0.4, 0.7, 1.0},  angle = -math.pi/2 + math.pi*4/5 },  -- 右下
    { id = "economy", label = "经济",    color = {1.0, 0.85, 0.2}, angle = -math.pi/2 + math.pi*6/5 },  -- 左下
    { id = "skill",   label = "技能",    color = {0.8, 0.4, 1.0},  angle = -math.pi/2 + math.pi*8/5 },  -- 左上
}

-- 机制树节点在各维度内排好（按 layer 排序）
local _treeNodesByDim = {}  -- dim → {layer1_node, layer2_node, layer3_node}

local function _buildTreeNodesByDim()
    _treeNodesByDim = {}
    for _, dim in ipairs(TREE_DIMS) do
        _treeNodesByDim[dim.id] = {}
    end
    for _, node in ipairs(ProgressionTreeConfig) do
        if _treeNodesByDim[node.dim] then
            _treeNodesByDim[node.dim][node.layer] = node
        end
    end
end
_buildTreeNodesByDim()

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

-- 机制树扩散图区域（Tab 1 右半屏）
local GRAPH_X     = PANEL_X + LIST_W + 30
local GRAPH_Y     = PANEL_Y
local GRAPH_W     = PANEL_W - LIST_W - 30
local GRAPH_H     = PANEL_H
local GRAPH_CX    = GRAPH_X + GRAPH_W / 2   -- 扩散图中心 X
local GRAPH_CY    = GRAPH_Y + GRAPH_H / 2   -- 扩散图中心 Y
local NODE_R1     = 70    -- 第1层节点距中心距离
local NODE_R2     = 130   -- 第2层
local NODE_R3     = 190   -- 第3层
local NODE_SIZE   = 22    -- 节点圆半径

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

    -- Tab 1 焦点：list（左侧属性列表） / graph（右侧机制树）
    self._commonFocus  = FOCUS_LIST
    -- 机制树当前选中节点：{ dimIdx = 1~5, layer = 1~3 }
    self._graphDimIdx  = 1
    self._graphLayer   = 1

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
    -- ← → 切换左右焦点
    if Input.isPressed("moveLeft") then
        self._commonFocus = FOCUS_LIST
    elseif Input.isPressed("moveRight") then
        self._commonFocus = FOCUS_GRAPH
    end

    if self._commonFocus == FOCUS_LIST then
        -- 左侧：上下选择属性，Enter 升级
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
    else
        -- 右侧（机制树图）：上下换维度，左右换层级
        local dimCount = #TREE_DIMS
        if Input.isPressed("moveUp") then
            self._graphDimIdx = self._graphDimIdx - 1
            if self._graphDimIdx < 1 then self._graphDimIdx = dimCount end
        elseif Input.isPressed("moveDown") then
            self._graphDimIdx = self._graphDimIdx % dimCount + 1
        end
        -- 机制树内 Left/Right 调整层（但 Left 切回列表已处理，这里只处理向右往深层）
        -- 实际用 confirm(Enter) 解锁即可，上下在维度间切换已足够
        if Input.isPressed("confirm") then
            -- 尝试按层序解锁当前维度的最浅未解锁节点
            local dim = TREE_DIMS[self._graphDimIdx]
            local nodes = _treeNodesByDim[dim.id] or {}
            local unlocked = false
            for layer = 1, 3 do
                local node = nodes[layer]
                if node and not ProgressionManager.isTreeNodeUnlocked(node.id) then
                    local ok = ProgressionManager.unlockTreeNode(node.id)
                    if ok then
                        self:_showNotice("✓ " .. T(node.nameKey) .. " 已解锁！")
                    else
                        local pts = ProgressionManager.getCommonPoints()
                        if pts < (node.cost or 0) then
                            self:_showNotice(T("progression.insufficient"))
                        else
                            self:_showNotice(T("progression.locked"))
                        end
                    end
                    unlocked = true
                    break
                end
            end
            if not unlocked then
                self:_showNotice("该维度已全部解锁！")
            end
        end
    end
end

--- 技能树面板输入处理
function Progression:_updateTree()
    -- ← → 切换英雄
    local CHAR_LIST = { "engineer", "berserker", "phantom" }
    if Input.isPressed("moveLeft") or Input.isPressed("moveRight") then
        local curIdx = 1
        for i, cid in ipairs(CHAR_LIST) do
            if cid == self._charId then curIdx = i; break end
        end
        local dir = Input.isPressed("moveLeft") and -1 or 1
        local newIdx = ((curIdx - 1 + dir) % #CHAR_LIST) + 1
        self._charId   = CHAR_LIST[newIdx]
        self._flatNodes = self:_buildFlatNodes()
        self._treeIdx   = 1
        return
    end

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

    -- === 左侧：属性升级列表 ===
    local listFocused = (self._commonFocus == FOCUS_LIST)

    -- 列表标题栏
    local headerY = PANEL_Y + 26
    Font.set(13)
    love.graphics.setColor(0.5, 0.5, 0.55)
    love.graphics.print("属性",       PANEL_X + 16,         headerY)
    love.graphics.print("等级",       PANEL_X + 170,        headerY)
    love.graphics.print("当前加成",   PANEL_X + 240,        headerY)
    love.graphics.print("费用",       PANEL_X + 340,        headerY)

    -- 列表焦点框
    if listFocused then
        love.graphics.setColor(0.3, 0.55, 1.0, 0.4)
    else
        love.graphics.setColor(0.3, 0.3, 0.4, 0.25)
    end
    love.graphics.rectangle("line", PANEL_X - 2, PANEL_Y + 20, LIST_W + 4, PANEL_H - 20, 4, 4)

    -- 分隔线
    love.graphics.setColor(0.25, 0.25, 0.3)
    love.graphics.rectangle("fill", PANEL_X, headerY + 18, LIST_W, 1)

    -- 属性列表
    local listStartY = headerY + 26
    for i, attr in ipairs(COMMON_ATTR_ORDER) do
        local ry       = listStartY + (i - 1) * ROW_H
        local selected = listFocused and (i == self._commonIdx)
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
            love.graphics.print(tostring(def.costPerLevel), PANEL_X + 340, ry + 10)
        end
    end

    -- 左右切换提示
    Font.set(12)
    love.graphics.setColor(0.4, 0.4, 0.5)
    love.graphics.print("← / → 切换区域", PANEL_X + 4, PANEL_Y + PANEL_H - 20)

    -- === 右侧：通用机制树星形扩散图 ===
    self:_drawGraphPanel(pts)
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

-- ============================================================
-- 绘制：通用机制树星形扩散图
-- ============================================================
function Progression:_drawGraphPanel(pts)
    local graphFocused = (self._commonFocus == FOCUS_GRAPH)

    -- 区域背景
    if graphFocused then
        love.graphics.setColor(0.08, 0.1, 0.18, 0.92)
    else
        love.graphics.setColor(0.06, 0.07, 0.12, 0.88)
    end
    love.graphics.rectangle("fill", GRAPH_X, GRAPH_Y, GRAPH_W, GRAPH_H, 8, 8)

    -- 区域边框
    if graphFocused then
        love.graphics.setColor(0.4, 0.6, 1.0, 0.6)
    else
        love.graphics.setColor(0.25, 0.25, 0.35, 0.4)
    end
    love.graphics.rectangle("line", GRAPH_X, GRAPH_Y, GRAPH_W, GRAPH_H, 8, 8)

    -- 标题
    Font.set(14)
    love.graphics.setColor(0.7, 0.7, 0.8)
    love.graphics.printf("通用机制树", GRAPH_X, GRAPH_Y + 8, GRAPH_W, "center")

    -- 中心点（黄色六芒星形心脏）
    love.graphics.setColor(0.9, 0.8, 0.3, 0.9)
    love.graphics.circle("fill", GRAPH_CX, GRAPH_CY, 10)
    love.graphics.setColor(1.0, 0.95, 0.5)
    love.graphics.circle("line", GRAPH_CX, GRAPH_CY, 10)

    -- 辅助放射线（从中心到第3层末端，淡色）
    for _, dim in ipairs(TREE_DIMS) do
        local ex = GRAPH_CX + math.cos(dim.angle) * (NODE_R3 + NODE_SIZE + 8)
        local ey = GRAPH_CY + math.sin(dim.angle) * (NODE_R3 + NODE_SIZE + 8)
        love.graphics.setColor(dim.color[1], dim.color[2], dim.color[3], 0.12)
        love.graphics.line(GRAPH_CX, GRAPH_CY, ex, ey)
    end

    -- 各维度圆弧参考圈（同层节点连线，非常淡）
    for _, radius in ipairs({ NODE_R1, NODE_R2, NODE_R3 }) do
        love.graphics.setColor(0.25, 0.25, 0.35, 0.2)
        love.graphics.circle("line", GRAPH_CX, GRAPH_CY, radius)
    end

    -- 绘制各维度节点（从外到内，避免遮挡）
    for dimI, dim in ipairs(TREE_DIMS) do
        local nodes = _treeNodesByDim[dim.id] or {}
        local isSelectedDim = graphFocused and (dimI == self._graphDimIdx)

        for layer = 3, 1, -1 do
            local node = nodes[layer]
            if not node then goto continue end

            local radius = layer == 1 and NODE_R1 or (layer == 2 and NODE_R2 or NODE_R3)
            local nx = GRAPH_CX + math.cos(dim.angle) * radius
            local ny = GRAPH_CY + math.sin(dim.angle) * radius

            local unlocked  = ProgressionManager.isTreeNodeUnlocked(node.id)
            -- 检查前置
            local prevOk = true
            for _, reqId in ipairs(node.requires or {}) do
                if not ProgressionManager.isTreeNodeUnlocked(reqId) then
                    prevOk = false; break
                end
            end
            local affordable = (pts >= (node.cost or 0))
            local canUnlock  = prevOk and not unlocked

            -- 节点连线到前一层
            if layer > 1 then
                local prevRadius = layer == 2 and NODE_R1 or NODE_R2
                local px = GRAPH_CX + math.cos(dim.angle) * prevRadius
                local py = GRAPH_CY + math.sin(dim.angle) * prevRadius
                if unlocked then
                    love.graphics.setColor(dim.color[1], dim.color[2], dim.color[3], 0.7)
                elseif prevOk then
                    love.graphics.setColor(dim.color[1]*0.6, dim.color[2]*0.6, dim.color[3]*0.6, 0.4)
                else
                    love.graphics.setColor(0.25, 0.25, 0.3, 0.3)
                end
                love.graphics.line(nx, ny, px, py)
            end

            -- 节点圆
            local r = isSelectedDim and (NODE_SIZE + 3) or NODE_SIZE
            if unlocked then
                love.graphics.setColor(dim.color[1]*0.5, dim.color[2]*0.5, dim.color[3]*0.5, 1.0)
                love.graphics.circle("fill", nx, ny, r)
                love.graphics.setColor(dim.color)
                love.graphics.circle("line", nx, ny, r)
                love.graphics.setLineWidth(2)
                love.graphics.circle("line", nx, ny, r)
                love.graphics.setLineWidth(1)
            elseif canUnlock and affordable then
                love.graphics.setColor(dim.color[1]*0.2, dim.color[2]*0.2, dim.color[3]*0.2, 0.9)
                love.graphics.circle("fill", nx, ny, r)
                love.graphics.setColor(dim.color)
                love.graphics.circle("line", nx, ny, r)
            elseif canUnlock then
                love.graphics.setColor(0.12, 0.12, 0.16, 0.9)
                love.graphics.circle("fill", nx, ny, r)
                love.graphics.setColor(0.5, 0.5, 0.55)
                love.graphics.circle("line", nx, ny, r)
            else
                love.graphics.setColor(0.08, 0.08, 0.1, 0.85)
                love.graphics.circle("fill", nx, ny, r)
                love.graphics.setColor(0.28, 0.28, 0.32)
                love.graphics.circle("line", nx, ny, r)
            end

            -- 层级数字
            Font.set(11)
            if unlocked then
                love.graphics.setColor(1.0, 1.0, 1.0)
                love.graphics.printf(tostring(layer), nx - r, ny - 7, r * 2, "center")
            elseif canUnlock and affordable then
                love.graphics.setColor(dim.color)
                love.graphics.printf(tostring(layer), nx - r, ny - 7, r * 2, "center")
            else
                love.graphics.setColor(0.4, 0.4, 0.45)
                love.graphics.printf(tostring(layer), nx - r, ny - 7, r * 2, "center")
            end

            -- 选中维度高亮光晕
            if isSelectedDim then
                love.graphics.setColor(dim.color[1], dim.color[2], dim.color[3], 0.25)
                love.graphics.circle("line", nx, ny, r + 5)
                love.graphics.circle("line", nx, ny, r + 8)
            end

            ::continue::
        end

        -- 维度标签（在第3层末端外侧）
        local labelR = NODE_R3 + NODE_SIZE + 20
        local lx = GRAPH_CX + math.cos(dim.angle) * labelR
        local ly = GRAPH_CY + math.sin(dim.angle) * labelR
        Font.set(12)
        if graphFocused and dimI == self._graphDimIdx then
            love.graphics.setColor(dim.color)
        else
            love.graphics.setColor(dim.color[1]*0.7, dim.color[2]*0.7, dim.color[3]*0.7)
        end
        love.graphics.printf(dim.label, lx - 28, ly - 9, 56, "center")
    end

    -- 当前焦点维度说明（底部信息栏）
    if graphFocused then
        local dim    = TREE_DIMS[self._graphDimIdx]
        local nodes  = _treeNodesByDim[dim.id] or {}

        -- 找当前维度最浅未解锁节点
        local targetNode = nil
        for layer = 1, 3 do
            local node = nodes[layer]
            if node and not ProgressionManager.isTreeNodeUnlocked(node.id) then
                targetNode = node; break
            end
        end

        local infoY = GRAPH_Y + GRAPH_H - 88
        love.graphics.setColor(0.1, 0.1, 0.18, 0.9)
        love.graphics.rectangle("fill", GRAPH_X + 8, infoY, GRAPH_W - 16, 80, 6, 6)
        love.graphics.setColor(dim.color[1], dim.color[2], dim.color[3], 0.5)
        love.graphics.rectangle("line", GRAPH_X + 8, infoY, GRAPH_W - 16, 80, 6, 6)

        if targetNode then
            Font.set(13)
            love.graphics.setColor(dim.color)
            love.graphics.printf(T(targetNode.nameKey), GRAPH_X + 12, infoY + 8, GRAPH_W - 24, "left")
            Font.set(11)
            love.graphics.setColor(0.75, 0.78, 0.82)
            love.graphics.printf(T(targetNode.descKey), GRAPH_X + 12, infoY + 28, GRAPH_W - 24, "left")
            -- 费用
            local affordable = pts >= (targetNode.cost or 0)
            if affordable then
                love.graphics.setColor(0.4, 0.85, 0.45)
            else
                love.graphics.setColor(0.85, 0.4, 0.4)
            end
            love.graphics.printf(
                string.format("费用 %d 点  [ Enter 解锁 ]", targetNode.cost or 0),
                GRAPH_X + 12, infoY + 56, GRAPH_W - 24, "left")
        else
            Font.set(13)
            love.graphics.setColor(dim.color)
            love.graphics.printf(dim.label .. " — 已全部解锁 ✓", GRAPH_X + 12, infoY + 28, GRAPH_W - 24, "center")
        end
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

    -- 角色名 + 颜色（中间显示，带 ← → 切换提示）
    local charColor = charCfg.color or {0.7, 0.7, 0.9}
    Font.set(17)
    love.graphics.setColor(charColor)
    love.graphics.printf(T(charCfg.nameKey), PANEL_X, PANEL_Y - 4, PANEL_W, "right")

    -- 切换英雄提示（← → 切换）
    Font.set(13)
    love.graphics.setColor(0.45, 0.45, 0.5)
    love.graphics.printf("← → 切换英雄", PANEL_X, PANEL_Y - 4, PANEL_W, "center")

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

    -- 节点列表可用高度（底部留出详情框）
    local nodeStartY = titleY + 30
    local trunkAIdx  = 0
    local trunkBIdx  = 0
    local selectedItem = nil   -- Bug#55：循环后统一绘制详情框

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

        -- Bug#55：不在此处画详情框，记录后循环结束统一绘制
        if selected then
            selectedItem = { node = node, unlocked = unlocked, canUnlock = canUnlock }
        end
    end

    -- Bug#55 修复：所有节点卡片绘制完毕后再画详情框（避免被 B 列节点压住）
    if selectedItem then
        self:_drawNodeDetail(selectedItem.node, selectedItem.unlocked, selectedItem.canUnlock, mpts)
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

--- 绘制技能树节点详情（面板底部，避免与节点卡片重叠）
function Progression:_drawNodeDetail(node, unlocked, canUnlock, mpts)
    -- 详情框固定在面板底部
    local bh = 110
    local bx = PANEL_X
    local by = PANEL_Y + PANEL_H - bh
    local bw = PANEL_W

    love.graphics.setColor(0.08, 0.09, 0.16, 0.95)
    love.graphics.rectangle("fill", bx, by, bw, bh, 8, 8)
    love.graphics.setColor(0.25, 0.3, 0.55)
    love.graphics.rectangle("line", bx, by, bw, bh, 8, 8)

    -- 节点名
    Font.set(16)
    love.graphics.setColor(1.0, 0.9, 0.6)
    love.graphics.print(T(node.nameKey), bx + 16, by + 10)

    -- 描述
    Font.set(13)
    love.graphics.setColor(0.8, 0.82, 0.85)
    love.graphics.printf(T(node.descKey), bx + 16, by + 34, bw - 32, "left")

    -- 费用与解锁状态
    Font.set(13)
    if unlocked then
        love.graphics.setColor(0.4, 0.85, 0.5)
        love.graphics.print(T("progression.unlocked"), bx + 16, by + 80)
    elseif not canUnlock then
        love.graphics.setColor(0.75, 0.4, 0.4)
        love.graphics.print(T("progression.locked"), bx + 16, by + 80)
    else
        local enough = mpts >= (node.cost or 0)
        if enough then
            love.graphics.setColor(0.4, 0.8, 0.4)
            love.graphics.print(string.format("消耗 %d 点  [ Enter 解锁 ]", node.cost or 0), bx + 16, by + 80)
        else
            love.graphics.setColor(0.85, 0.35, 0.35)
            love.graphics.print(string.format("需要 %d 点（当前 %d 点）", node.cost or 0, mpts), bx + 16, by + 80)
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
