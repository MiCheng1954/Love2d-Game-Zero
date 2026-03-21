--[[
    src/states/skillSelectUI.lua
    技能选择界面 — Phase 8

    push/pop 模式，与 bagUI 一致。
    升级时从技能池随机抽 3 个候选（未拥有优先 / 可升级 / 角色匹配）展示，
    玩家选择后调用 onSelect 回调。

    enter(data) 参数：
        data.player    — 玩家实例
        data.candidates — 候选技能 id 列表（外部传入，已筛选好的 3 个）
        data.onSelect   — function(skillId) 选择回调
        data.onCancel   — function() 取消回调（可选）
]]

local Input        = require("src.systems.input")
local Font         = require("src.utils.font")
local SkillConfig  = require("config.skills")

local SkillSelectUI = {}

-- 进入技能选择界面
function SkillSelectUI:enter(data)
    self._player     = data.player
    self._candidates = data.candidates or {}
    self._onSelect   = data.onSelect
    self._onCancel   = data.onCancel
    self._index      = 1

    -- 清除残留输入
    Input.update()
end

-- 退出
function SkillSelectUI:exit()
    self._player     = nil
    self._candidates = {}
    self._onSelect   = nil
    self._onCancel   = nil
end

-- 每帧更新
function SkillSelectUI:update(dt)
    Input.update()

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

-- 绘制界面
function SkillSelectUI:draw()
    Font.set(16)

    -- 半透明遮罩
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, 1280, 720)

    -- 标题
    love.graphics.setColor(0.7, 0.3, 1.0)
    love.graphics.printf(T("skill_select.title"), 0, 80, 1280, "center")

    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.printf(T("skill_select.hint"), 0, 116, 1280, "center")

    -- 技能卡片
    local cardW = 600
    local cardH = 90
    local cardX = (1280 - cardW) / 2
    local baseY = 180
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

    Font.reset()
end

-- keypressed（备用，Input 系统统一处理）
function SkillSelectUI:keypressed(key)
end

return SkillSelectUI
