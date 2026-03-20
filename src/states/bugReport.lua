--[[
    src/states/bugReport.lua
    Bug 反馈面板，按 F12 呼出，叠加在任意状态上方
    两阶段输入：描述 -> 优先级
    数据写入项目 data/bugs.json，同时快照当前运行日志写入 data/logs/
    Phase 5.1：开发基础设施
    可剔除：注释 main.lua 中的 require/register/F12 三行即可完全移除
]]

local Font = require("src.utils.font")
local Log  = require("src.utils.log")

local BugReport = {}

-- 输入阶段枚举
local PHASE_DESC     = "desc"      -- 输入描述阶段
local PHASE_PRIORITY = "priority"  -- 选择优先级阶段
local PHASE_DONE     = "done"      -- 已保存，显示确认后自动关闭

-- 保存文件名（相对于 data/ 目录）
local BUGS_FILE = "bugs.json"

-- 关闭前的停留时间（秒）
local CLOSE_DELAY = 1.5

-- 面板尺寸（居中显示）
local PANEL_W = 700
local PANEL_H = 300
local PANEL_X = (1280 - PANEL_W) / 2
local PANEL_Y = (720  - PANEL_H) / 2

-- UTF-8 安全退格：删除字符串末尾一个完整的 Unicode 字符
-- @param s: 输入字符串
-- @return 删除末尾字符后的字符串
local function utf8Backspace(s)
    if #s == 0 then return s end
    -- 从末尾向前找 UTF-8 字符起始字节（0xxxxxxx 或 11xxxxxx）
    local i = #s
    while i > 0 do
        local b = s:byte(i)
        if b < 0x80 or b >= 0xC0 then
            -- 找到起始字节，截掉从 i 开始到末尾的内容
            return s:sub(1, i - 1)
        end
        i = i - 1
    end
    return ""
end

-- 进入 Bug 反馈状态
-- @param data: { player, spawner, enemies }
function BugReport:enter(data)
    self._player  = data and data.player  or nil
    self._spawner = data and data.spawner or nil
    self._enemies = data and data.enemies or nil

    self._phase       = PHASE_DESC
    self._descInput   = ""     -- 描述输入缓冲
    self._savedId     = nil    -- 保存后的 Bug ID
    self._closeTimer  = 0

    -- 光标闪烁
    self._cursorTimer   = 0
    self._cursorVisible = true

    -- 读取已有 bugs.json，确定下一个 ID
    self._nextId = self:_loadNextId()

    love.keyboard.setTextInput(true)
end

-- 退出 Bug 反馈状态
function BugReport:exit()
    love.keyboard.setTextInput(false)
    self._player  = nil
    self._spawner = nil
    self._enemies = nil
end

-- 每帧更新
function BugReport:update(dt)
    -- 光标闪烁
    self._cursorTimer = self._cursorTimer + dt
    if self._cursorTimer >= 0.5 then
        self._cursorTimer   = self._cursorTimer - 0.5
        self._cursorVisible = not self._cursorVisible
    end

    -- 保存完成后倒计时关闭
    if self._phase == PHASE_DONE then
        self._closeTimer = self._closeTimer + dt
        if self._closeTimer >= CLOSE_DELAY then
            local StateManager = require("src.states.stateManager")
            StateManager.pop()
        end
    end
end

-- 接收文字输入（由 main.lua textinput 回调转发）
function BugReport:textinput(text)
    if self._phase == PHASE_DESC then
        self._descInput = self._descInput .. text
    end
end

-- 键盘按下事件
function BugReport:keypressed(key)
    if self._phase == PHASE_DESC then
        if key == "escape" then
            local StateManager = require("src.states.stateManager")
            StateManager.pop()
        elseif key == "backspace" then
            self._descInput = utf8Backspace(self._descInput)
        elseif (key == "return" or key == "kpenter") and self._descInput:match("%S") then
            self._phase = PHASE_PRIORITY
        end

    elseif self._phase == PHASE_PRIORITY then
        local numKey = key:match("^kp(.+)$") or key  -- 兼容小键盘
        if numKey == "1" or numKey == "2" or numKey == "3" then
            local priority = tonumber(numKey)
            self:_saveBug(priority)
            self._phase = PHASE_DONE
        elseif key == "escape" then
            self._phase = PHASE_DESC
        end
    end
end

-- 读取 bugs.json，返回下一个可用的 Bug ID
function BugReport:_loadNextId()
    local dataDir = Log.getDataDir()
    if not dataDir then return 1 end

    local path = dataDir .. "/" .. BUGS_FILE
    local f = io.open(path, "r")
    if not f then return 1 end
    local content = f:read("*a")
    f:close()

    local maxId = 0
    for id in content:gmatch('"id"%s*:%s*(%d+)') do
        local n = tonumber(id)
        if n and n > maxId then maxId = n end
    end
    return maxId + 1
end

-- 将 Bug 数据序列化为 JSON 字符串
local function serializeBug(bug)
    local function escStr(s)
        return s:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '')
    end

    local logStr = string.format(
        '"level":%d,"hp":%d,"elapsed":%.1f,"enemies":%d',
        bug.log.level, bug.log.hp, bug.log.elapsed, bug.log.enemies
    )
    if bug.logSnapshot then
        logStr = logStr .. string.format(',"logSnapshot":"%s"', escStr(bug.logSnapshot))
    end

    return string.format(
        '{"id":%d,"desc":"%s","time":"%s","priority":%d,"log":{%s}}',
        bug.id,
        escStr(bug.desc),
        bug.time,
        bug.priority,
        logStr
    )
end

-- 保存 Bug 到 data/bugs.json，并快照日志
function BugReport:_saveBug(priority)
    local dataDir = Log.getDataDir()
    if not dataDir then return end

    -- 先快照当前日志
    local snapName = Log.snapshotForBug(self._nextId)

    -- 记录 bug 事件到主日志
    Log.event(string.format("BUG #%d 提交 priority=%d desc=%s",
        self._nextId, priority, self._descInput))

    local bug = {
        id       = self._nextId,
        desc     = self._descInput,
        time     = os.date("%Y-%m-%d %H:%M:%S"),
        priority = priority,
        logSnapshot = snapName,
        log      = {
            level    = self._player and self._player._level   or 0,
            hp       = self._player and self._player.hp       or 0,
            elapsed  = self._spawner and self._spawner._elapsed or 0.0,
            enemies  = self._enemies and #self._enemies        or 0,
        },
    }

    local path = dataDir .. "/" .. BUGS_FILE

    -- 读取已有内容
    local existing = "[]"
    local f = io.open(path, "r")
    if f then
        existing = f:read("*a") or "[]"
        f:close()
        existing = existing:match("^%s*(.-)%s*$")
    end

    -- 追加新条目
    local newEntry = serializeBug(bug)
    local newContent
    if existing == "[]" or existing == "" then
        newContent = "[\n  " .. newEntry .. "\n]"
    else
        newContent = existing:gsub("%]%s*$", ",\n  " .. newEntry .. "\n]")
    end

    local fw = io.open(path, "w")
    if fw then
        fw:write(newContent)
        fw:close()
    end

    self._savedId = bug.id
end

-- 每帧绘制 Bug 反馈面板
function BugReport:draw()
    Font.set(15)

    -- 半透明背景遮罩
    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", 0, 0, 1280, 720)

    -- 面板背景
    love.graphics.setColor(0.08, 0.08, 0.12, 0.96)
    love.graphics.rectangle("fill", PANEL_X, PANEL_Y, PANEL_W, PANEL_H, 8, 8)

    -- 面板边框
    love.graphics.setColor(0.9, 0.3, 0.3, 0.9)
    love.graphics.rectangle("line", PANEL_X, PANEL_Y, PANEL_W, PANEL_H, 8, 8)

    -- 标题
    love.graphics.setColor(1, 0.4, 0.4)
    love.graphics.printf(T("bug.title"), PANEL_X, PANEL_Y + 18, PANEL_W, "center")

    if self._phase == PHASE_DESC then
        love.graphics.setColor(0.85, 0.85, 0.85)
        love.graphics.print(T("bug.desc.hint"), PANEL_X + 20, PANEL_Y + 70)

        -- 输入框背景
        love.graphics.setColor(0.05, 0.05, 0.08)
        love.graphics.rectangle("fill", PANEL_X + 20, PANEL_Y + 100, PANEL_W - 40, 60, 4, 4)
        love.graphics.setColor(0.4, 0.4, 0.5)
        love.graphics.rectangle("line", PANEL_X + 20, PANEL_Y + 100, PANEL_W - 40, 60, 4, 4)

        -- 输入文字 + 光标（对空串也安全）
        local cursor = self._cursorVisible and "|" or " "
        love.graphics.setColor(1, 1, 1)
        local display = self._descInput .. cursor
        love.graphics.printf(display, PANEL_X + 28, PANEL_Y + 116, PANEL_W - 56, "left")

        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.printf(T("bug.hint"), PANEL_X, PANEL_Y + PANEL_H - 44, PANEL_W, "center")

    elseif self._phase == PHASE_PRIORITY then
        love.graphics.setColor(0.85, 0.85, 0.85)
        love.graphics.printf(T("bug.priority"), PANEL_X, PANEL_Y + 120, PANEL_W, "center")

        local labels = {T("cat.stat") ~= "[cat.stat]" and "1 - 低" or "1 - Low",
                        "2 - 中", "3 - 高"}
        -- 简化写法
        local btnLabels = {"1 - 低", "2 - 中", "3 - 高"}
        local colors = {
            {0.3, 0.9, 0.3},
            {0.9, 0.8, 0.2},
            {1.0, 0.3, 0.3},
        }
        local btnW   = 160
        local gap    = 20
        local totalW = btnW * 3 + gap * 2
        local startX = PANEL_X + (PANEL_W - totalW) / 2
        for i = 1, 3 do
            local bx = startX + (i - 1) * (btnW + gap)
            local by = PANEL_Y + 180
            love.graphics.setColor(colors[i][1]*0.2, colors[i][2]*0.2, colors[i][3]*0.2, 0.9)
            love.graphics.rectangle("fill", bx, by, btnW, 50, 6, 6)
            love.graphics.setColor(colors[i])
            love.graphics.rectangle("line", bx, by, btnW, 50, 6, 6)
            love.graphics.printf(btnLabels[i], bx, by + 16, btnW, "center")
        end

        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.printf("ESC 返回修改描述", PANEL_X, PANEL_Y + PANEL_H - 44, PANEL_W, "center")

    elseif self._phase == PHASE_DONE then
        love.graphics.setColor(0.3, 1, 0.3)
        love.graphics.printf(T("bug.saved", self._savedId or 0),
            PANEL_X, PANEL_Y + 130, PANEL_W, "center")

        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.printf("正在关闭...", PANEL_X, PANEL_Y + 180, PANEL_W, "center")
    end

    Font.reset()
end

return BugReport
