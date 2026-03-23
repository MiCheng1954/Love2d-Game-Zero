--[[
    src/states/skillSelectUI.lua
    技能选择界面 — Phase 8

    push/pop 模式，与 bagUI 一致。
    升级时从技能池随机抽 3 个候选（未拥有优先 / 可升级 / 角色匹配）展示，
    玩家选择后调用 onSelect 回调。

    enter(data) 参数：
        data.player      — 玩家实例
        data.candidates  — 候选技能 id 列表（外部传入，已筛选好的 3 个）
        data.onSelect    — function(skillId) 选择回调
        data.onCancel    — function() 取消回调（可选）
        data.onRefresh   — function() → candidates 刷新回调（可选），返回新候选列表
        data.refreshCost — number 刷新灵魂消耗（可选，默认 5）
]]

local Input        = require("src.systems.input")
local Font         = require("src.utils.font")
local SkillConfig  = require("config.skills")

local SkillSelectUI = {}

-- 刷新消耗提示显示时长（秒）
local NOTICE_DURATION = 1.5

-- 进入技能选择界面
function SkillSelectUI:enter(data)
    self._player      = data.player
    self._candidates  = data.candidates or {}
    self._onSelect    = data.onSelect
    self._onCancel    = data.onCancel
    self._onRefresh   = data.onRefresh      -- function() → new candidates or nil
    self._refreshCost = data.refreshCost or 5
    self._index       = 1

    -- 灵魂不足提示
    self._noticeTimer = 0
    self._noticeText  = ""

    -- 清除残留输入
    Input.update()
end

-- 退出
function SkillSelectUI:exit()
    self._player      = nil
    self._candidates  = {}
    self._onSelect    = nil
    self._onCancel    = nil
    self._onRefresh   = nil
end

-- 每帧更新
function SkillSelectUI:update(dt)
    Input.update()

    -- 提示倒计时
    if self._noticeTimer > 0 then
        self._noticeTimer = self._noticeTimer - dt
    end

    if Input.isPressed("moveUp") then
        self._index = math.max(1, self._index - 1)
    elseif Input.isPressed("moveDown") then
        self._index = math.min(#self._candidates, self._index + 1)
    end

    if Input.isPressed("confirm") then
        local id = self._candidates[self._index]
        if id and self._onSelect then
            self._onSelect(id)
        end
    end

    if Input.isPressed("cancel") then
        if self._onCancel then
            self._onCancel()
        else
            local StateManager = require("src.states.stateManager")
            StateManager.pop()
        end
    end
end

function SkillSelectUI:keypressed(key)
    if key == "r" or key == "R" then
        self:_tryRefresh()
    end
end

-- 尝试花费灵魂刷新候选列表
-- Bug#53：只刷新光标选中的那一个选项，其余保持不变
-- onRefresh(currentId) → 返回一个新的技能 id（排除已在列表中的）
function SkillSelectUI:_tryRefresh()
    if not self._onRefresh then return end

    local player = self._player
    if not player then return end

    local cost = self._refreshCost
    if player:getSouls() < cost then
        self._noticeText  = string.format(T("skill_select.no_souls"), cost)
        self._noticeTimer = NOTICE_DURATION
        return
    end

    -- 花费灵魂，获取替换当前选中的一个新候选
    player:spendSouls(cost)
    local currentId = self._candidates[self._index]
    local newId = self._onRefresh(currentId, self._candidates)
    if newId then
        self._candidates[self._index] = newId
        -- 光标保持不动
    end
end

-- 绘制界面
function SkillSelectUI:draw()
    Font.set(16)

    -- 半透明遮罩
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, 1280, 720)

    -- 标题
    love.graphics.setColor(0.7, 0.3, 1.0)
    love.graphics.printf(T("skill_select.title"), 0, 80, 1280, "center")

    -- 操作提示行
    Font.set(13)
    if self._onRefresh then
        -- 显示灵魂余量和刷新费用
        local souls   = self._player and self._player:getSouls() or 0
        local hintStr = string.format(T("skill_select.hint_refresh"), self._refreshCost)
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.printf(hintStr, 0, 116, 1280, "center")
        -- 灵魂余量（右侧小字）
        love.graphics.setColor(0.9, 0.8, 0.2)
        love.graphics.printf("灵魂：" .. souls, 0, 135, 1260, "right")
    else
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.printf(T("skill_select.hint"), 0, 116, 1280, "center")
    end
    Font.set(16)

    -- 技能卡片
    local cardW = 600
    local cardH = 90
    local cardX = (1280 - cardW) / 2
    local baseY = 168
    local gap   = 16

    local sm = self._player and self._player._skillManager
    local color = {0.7, 0.3, 1.0}

    for i, id in ipairs(self._candidates) do
        local cfg      = SkillConfig[id]
        if not cfg then goto continue end

        local cy       = baseY + (i - 1) * (cardH + gap)
        local selected = (i == self._index)

        -- 卡片背景
        if selected then
            love.graphics.setColor(0.18, 0.08, 0.28, 0.95)
        else
            love.graphics.setColor(0.12, 0.12, 0.16, 0.9)
        end
        love.graphics.rectangle("fill", cardX, cy, cardW, cardH, 8, 8)

        -- 卡片边框
        if selected then
            love.graphics.setColor(color)
        else
            love.graphics.setColor(0.3, 0.3, 0.35)
        end
        love.graphics.rectangle("line", cardX, cy, cardW, cardH, 8, 8)

        -- 技能名称
        local curLv = sm and sm:getLevel(id) or 0
        local lvStr = curLv > 0 and (" Lv" .. curLv .. "→" .. (curLv+1)) or " [NEW]"

        if selected then
            love.graphics.setColor(color)
        else
            love.graphics.setColor(0.85, 0.85, 0.85)
        end
        love.graphics.print(T(cfg.nameKey) .. lvStr, cardX + 20, cy + 14)

        -- Tag 标签
        if cfg.tag then
            love.graphics.setColor(0.4, 1.0, 0.7)
            love.graphics.print("[" .. cfg.tag .. "]", cardX + 20, cy + 38)
        end

        -- 描述
        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.print(T(cfg.descKey), cardX + 80, cy + 38)

        -- 选中箭头
        if selected then
            love.graphics.setColor(color)
            love.graphics.print("▶", cardX - 20, cy + 28)
        end

        ::continue::
    end

    -- 若没有候选提示
    if #self._candidates == 0 then
        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.printf(T("skill_select.empty"), 0, 360, 1280, "center")
    end

    -- 灵魂不足提示（居中淡出）
    if self._noticeTimer > 0 then
        local alpha = math.min(1.0, self._noticeTimer / 0.4)
        Font.set(15)
        love.graphics.setColor(1.0, 0.35, 0.35, alpha)
        love.graphics.printf(self._noticeText, 0, 530, 1280, "center")
        Font.set(16)
    end

    Font.reset()
end

return SkillSelectUI
