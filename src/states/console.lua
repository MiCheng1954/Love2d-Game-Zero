--[[
    src/states/console.lua
    开发者控制台，按 ` 键呼出，叠加在任意状态上方
    Phase 5.1：开发基础设施
]]

local Font = require("src.utils.font")

local Console = {}

-- 支持的指令说明（用于 help 输出）
local HELP_LINES = {
    "level <n>  - 设置玩家等级为 n",
    "levelup    - 触发一次升级界面",
    "hp <n>     - 设置当前 HP",
    "maxhp <n>  - 设置最大 HP",
    "souls <n>  - 设置灵魂数量",
    "speed <n>  - 设置移动速度",
    "attack <n> - 设置攻击力",
    "exp <n>    - 增加 n 点经验",
    "kill       - 秒杀所有敌人",
    "clear      - 清空控制台历史",
    "help       - 显示此帮助",
}

-- 最多保留的历史行数
local MAX_HISTORY = 20

-- 面板尺寸和位置（右下角）
local PANEL_W = 620
local PANEL_H = 320
local PANEL_X = 1280 - PANEL_W - 16
local PANEL_Y = 720  - PANEL_H - 16

-- 进入控制台覆盖层
-- @param data: { player, enemies, spawner, onLevelUp }
function Console:enter(data)
    self._input   = ""        -- 当前输入缓冲
    self._history = {}        -- 历史输出行
    self._player  = data and data.player  or nil
    self._enemies = data and data.enemies or nil
    self._spawner = data and data.spawner or nil
    self._onLevelUp = data and data.onLevelUp or nil

    -- 光标闪烁计时
    self._cursorTimer  = 0
    self._cursorVisible = true

    -- 开启文字输入（接收 textinput 事件）
    love.keyboard.setTextInput(true)

    self:_addLine(T("console.title"))
    self:_addLine(T("console.hint"))
    self:_addLine("---")
end

-- 退出控制台
function Console:exit()
    love.keyboard.setTextInput(false)
    self._player  = nil
    self._enemies = nil
    self._spawner = nil
    self._input   = ""
end

-- 每帧更新（仅处理光标闪烁，不更新游戏逻辑）
function Console:update(dt)
    self._cursorTimer = self._cursorTimer + dt
    if self._cursorTimer >= 0.5 then
        self._cursorTimer   = self._cursorTimer - 0.5
        self._cursorVisible = not self._cursorVisible
    end
end

-- 接收文字输入事件（由 main.lua textinput 回调转发）
function Console:textinput(text)
    self._input = self._input .. text
end

-- 键盘按下事件
function Console:keypressed(key)
    if key == "escape" or key == "`" then
        local StateManager = require("src.states.stateManager")
        StateManager.pop()
    elseif key == "backspace" then
        -- 删除最后一个字符（需处理 UTF-8 多字节）
        self._input = self._input:sub(1, -2)
        -- 若末尾是 UTF-8 续字节，继续删除直到合法边界
        while #self._input > 0 do
            local b = self._input:byte(-1)
            if b < 0x80 or b >= 0xC0 then break end
            self._input = self._input:sub(1, -2)
        end
    elseif key == "return" or key == "kpenter" then
        local cmd = self._input:match("^%s*(.-)%s*$")  -- trim
        self._input = ""
        if cmd ~= "" then
            self:_addLine("> " .. cmd)
            self:_execute(cmd)
        end
    end
end

-- 向历史记录追加一行
function Console:_addLine(text)
    table.insert(self._history, text)
    -- 超出上限则移除最旧的行
    while #self._history > MAX_HISTORY do
        table.remove(self._history, 1)
    end
end

-- 解析并执行指令
function Console:_execute(cmd)
    local parts = {}
    for token in cmd:gmatch("%S+") do
        table.insert(parts, token)
    end
    local verb = parts[1] and parts[1]:lower() or ""
    local arg1 = parts[2]

    if verb == "help" then
        for _, line in ipairs(HELP_LINES) do
            self:_addLine("  " .. line)
        end

    elseif verb == "clear" then
        self._history = {}

    elseif verb == "level" then
        local n = tonumber(arg1)
        if n and self._player then
            self._player._level = math.max(1, math.floor(n))
            self:_addLine("level -> " .. self._player._level)
        else
            self:_addLine("用法: level <n>")
        end

    elseif verb == "levelup" then
        if self._onLevelUp then
            self._onLevelUp()
            self:_addLine("触发升级界面")
        else
            self:_addLine("无法触发升级（未绑定回调）")
        end

    elseif verb == "hp" then
        local n = tonumber(arg1)
        if n and self._player then
            self._player.hp = math.min(math.max(1, math.floor(n)), self._player.maxHp)
            self:_addLine("hp -> " .. self._player.hp)
        else
            self:_addLine("用法: hp <n>")
        end

    elseif verb == "maxhp" then
        local n = tonumber(arg1)
        if n and self._player then
            self._player.maxHp = math.max(1, math.floor(n))
            self._player.hp    = math.min(self._player.hp, self._player.maxHp)
            self:_addLine("maxhp -> " .. self._player.maxHp)
        else
            self:_addLine("用法: maxhp <n>")
        end

    elseif verb == "souls" then
        local n = tonumber(arg1)
        if n and self._player then
            self._player._souls = math.max(0, math.floor(n))
            self:_addLine("souls -> " .. self._player._souls)
        else
            self:_addLine("用法: souls <n>")
        end

    elseif verb == "speed" then
        local n = tonumber(arg1)
        if n and self._player then
            self._player.speed = math.max(1, n)
            self:_addLine("speed -> " .. self._player.speed)
        else
            self:_addLine("用法: speed <n>")
        end

    elseif verb == "attack" then
        local n = tonumber(arg1)
        if n and self._player then
            self._player.attack = math.max(0, n)
            self:_addLine("attack -> " .. self._player.attack)
        else
            self:_addLine("用法: attack <n>")
        end

    elseif verb == "exp" then
        local n = tonumber(arg1)
        if n and self._player then
            self._player:addExp(math.floor(n))
            self:_addLine("已添加 " .. math.floor(n) .. " 点经验")
        else
            self:_addLine("用法: exp <n>")
        end

    elseif verb == "kill" then
        if self._enemies then
            local count = 0
            for _, enemy in ipairs(self._enemies) do
                if not enemy._isDead then
                    enemy._isDead = true
                    count = count + 1
                end
            end
            self:_addLine("已秒杀 " .. count .. " 个敌人")
        else
            self:_addLine("无敌人列表引用")
        end

    else
        self:_addLine(T("console.unknown", cmd))
    end
end

-- 每帧绘制控制台面板
function Console:draw()
    Font.set(14)

    local lineH = 18
    local padX  = 10
    local padY  = 8

    -- 半透明背景
    love.graphics.setColor(0, 0, 0, 0.88)
    love.graphics.rectangle("fill", PANEL_X, PANEL_Y, PANEL_W, PANEL_H, 6, 6)

    -- 边框
    love.graphics.setColor(0.2, 0.8, 0.3, 0.9)
    love.graphics.rectangle("line", PANEL_X, PANEL_Y, PANEL_W, PANEL_H, 6, 6)

    -- 历史输出行（绿色）
    love.graphics.setColor(0.2, 0.9, 0.3)
    local maxLines = math.floor((PANEL_H - padY * 2 - lineH - 4) / lineH)
    local startIdx = math.max(1, #self._history - maxLines + 1)
    for i = startIdx, #self._history do
        local row = i - startIdx
        love.graphics.print(self._history[i],
            PANEL_X + padX,
            PANEL_Y + padY + row * lineH)
    end

    -- 输入行分隔线
    local inputY = PANEL_Y + PANEL_H - padY - lineH
    love.graphics.setColor(0.2, 0.5, 0.2, 0.6)
    love.graphics.line(PANEL_X + padX, inputY - 4, PANEL_X + PANEL_W - padX, inputY - 4)

    -- 输入提示
    love.graphics.setColor(0.5, 1.0, 0.5)
    local cursor = self._cursorVisible and "_" or " "
    love.graphics.print("> " .. self._input .. cursor,
        PANEL_X + padX, inputY)

    -- 恢复默认字体
    Font.reset()
end

return Console
