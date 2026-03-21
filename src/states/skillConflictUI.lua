--[[
    src/states/skillConflictUI.lua
    技能槽冲突选择界面 — Phase 8（需求3+6）

    push/pop 模式。当主动技能槽冲突时弹出，
    展示旧技能与新技能，玩家选择：保留旧技能 / 替换为新技能。

    enter(data) 参数：
        data.player     — 玩家实例
        data.slot       — 冲突槽位（"skill1"~"skill4"）
        data.existing   — 当前槽中的技能 id
        data.incoming   — 要放入的技能 id
        data.onKeep     — function() 选择保留旧技能
        data.onReplace  — function(slot, incomingId) 选择替换
]]

local Input       = require("src.systems.input")
local Font        = require("src.utils.font")
local SkillConfig = require("config.skills")

local SkillConflictUI = {}

local SLOT_LABELS = {
    skill1 = "[空格]",
    skill2 = "[Q]",
    skill3 = "[E]",
    skill4 = "[F]",
}

function SkillConflictUI:enter(data)
    self._player   = data.player
    self._slot     = data.slot
    self._existing = data.existing
    self._incoming = data.incoming
    self._onKeep   = data.onKeep
    self._onReplace = data.onReplace
    self._choice   = 1   -- 1=保留旧, 2=替换新
    Input.update()
end

function SkillConflictUI:exit()
    self._player   = nil
    self._slot     = nil
    self._existing = nil
    self._incoming = nil
    self._onKeep   = nil
    self._onReplace = nil
end

function SkillConflictUI:update(dt)
    Input.update()

    if Input.isPressed("moveLeft") then
        self._choice = 1
    elseif Input.isPressed("moveRight") then
        self._choice = 2
    end

    if Input.isPressed("confirm") then
        if self._choice == 1 then
            -- 保留旧技能
            if self._onKeep then self._onKeep() end
        else
            -- 替换为新技能
            if self._onReplace then self._onReplace(self._slot, self._incoming) end
        end
    end

    if Input.isPressed("cancel") then
        -- ESC = 保留旧技能
        if self._onKeep then self._onKeep() end
    end
end

function SkillConflictUI:draw()
    Font.set(16)

    -- 半透明遮罩
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", 0, 0, 1280, 720)

    -- 标题
    local slotLabel = SLOT_LABELS[self._slot] or self._slot
    love.graphics.setColor(1.0, 0.7, 0.2)
    love.graphics.printf("技能槽冲突 — " .. slotLabel, 0, 60, 1280, "center")

    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.printf("← → 选择  |  Enter 确认  |  ESC 保留旧技能", 0, 96, 1280, "center")

    -- 两个技能卡片
    local cardW = 480
    local cardH = 220
    local gap   = 60
    local totalW = cardW * 2 + gap
    local startX = (1280 - totalW) / 2
    local cardY  = 160

    local sm = self._player and self._player._skillManager

    local function drawCard(x, y, w, h, skillId, isSelected, isOld)
        local cfg = SkillConfig[skillId]
        if not cfg then return end

        -- 背景
        if isSelected then
            love.graphics.setColor(0.15, 0.10, 0.25, 0.95)
        else
            love.graphics.setColor(0.10, 0.10, 0.14, 0.9)
        end
        love.graphics.rectangle("fill", x, y, w, h, 10, 10)

        -- 边框
        if isSelected then
            love.graphics.setColor(1.0, 0.7, 0.2)
        else
            love.graphics.setColor(0.35, 0.35, 0.40)
        end
        love.graphics.rectangle("line", x, y, w, h, 10, 10)

        -- 标签（旧/新）
        if isOld then
            love.graphics.setColor(0.6, 0.6, 0.6)
            love.graphics.print("【当前技能】", x + 16, y + 14)
        else
            love.graphics.setColor(0.3, 1.0, 0.5)
            love.graphics.print("【新技能】", x + 16, y + 14)
        end

        -- 技能名
        local curLv = sm and sm:getLevel(skillId) or 0
        local lvStr = curLv > 0 and (" Lv" .. curLv) or " [NEW]"
        if isSelected then
            love.graphics.setColor(1.0, 0.85, 0.3)
        else
            love.graphics.setColor(0.85, 0.85, 0.85)
        end
        Font.set(20)
        love.graphics.print(T(cfg.nameKey) .. lvStr, x + 16, y + 44)
        Font.set(16)

        -- Tag
        if cfg.tag then
            love.graphics.setColor(0.4, 1.0, 0.7)
            love.graphics.print("[" .. cfg.tag .. "]", x + 16, y + 82)
        end

        -- 描述
        love.graphics.setColor(0.65, 0.65, 0.65)
        love.graphics.printf(T(cfg.descKey), x + 16, y + 110, w - 32, "left")

        -- 选中箭头/高亮底部
        if isSelected then
            love.graphics.setColor(1.0, 0.7, 0.2)
            local btnY = y + h - 40
            love.graphics.rectangle("fill", x + 16, btnY, w - 32, 28, 6, 6)
            love.graphics.setColor(0.1, 0.1, 0.1)
            Font.set(14)
            if isOld then
                love.graphics.printf("✔ 保留此技能", x + 16, btnY + 6, w - 32, "center")
            else
                love.graphics.printf("✔ 替换为此技能", x + 16, btnY + 6, w - 32, "center")
            end
            Font.set(16)
        else
            love.graphics.setColor(0.3, 0.3, 0.3)
            Font.set(14)
            local btnY = y + h - 40
            if isOld then
                love.graphics.printf("保留此技能", x + 16, btnY + 6, w - 32, "center")
            else
                love.graphics.printf("替换为此技能", x + 16, btnY + 6, w - 32, "center")
            end
            Font.set(16)
        end
    end

    -- 左卡（旧技能）
    drawCard(startX, cardY, cardW, cardH, self._existing, self._choice == 1, true)

    -- VS 分隔
    love.graphics.setColor(0.8, 0.4, 0.1)
    Font.set(24)
    love.graphics.printf("VS", startX + cardW, cardY + (cardH - 30) / 2, gap, "center")
    Font.set(16)

    -- 右卡（新技能）
    drawCard(startX + cardW + gap, cardY, cardW, cardH, self._incoming, self._choice == 2, false)

    Font.reset()
end

function SkillConflictUI:keypressed(key)
end

return SkillConflictUI
