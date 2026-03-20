--[[
    src/states/devReport.lua
    开发反馈面板，F12 呼出，叠加在任意状态上方
    三阶段输入：描述 -> 优先级 -> 类型（Bug / 需求）
    Bug  → 写入 data/bugs.json
    需求 → 写入 data/features.json + data/features.md
    可剔除：注释 main.lua 中的 require/register/F12 三行即可完全移除
]]

local Font = require("src.utils.font")
local Log  = require("src.utils.log")

local DevReport = {}

-- 输入阶段枚举
local PHASE_DESC     = "desc"      -- 输入描述阶段
local PHASE_PRIORITY = "priority"  -- 选择优先级阶段
local PHASE_TYPE     = "type"      -- 选择类型（Bug / 需求）
local PHASE_DONE     = "done"      -- 已保存，显示确认后自动关闭

-- 保存文件名
local BUGS_FILE     = "bugs.json"
local FEATURES_FILE = "features.json"
local FEATURES_MD   = "features.md"

-- 关闭前的停留时间（秒）
local CLOSE_DELAY = 1.5

-- 面板尺寸（居中显示）
local PANEL_W = 700
local PANEL_H = 320
local PANEL_X = (1280 - PANEL_W) / 2
local PANEL_Y = (720  - PANEL_H) / 2

-- 优先级
local PRIORITY_LABELS = { "1 - 低", "2 - 中", "3 - 高" }
local PRIORITY_NAMES  = { "低", "中", "高" }
local PRIORITY_COLORS = {
    { 0.3, 0.9, 0.3 },
    { 0.9, 0.8, 0.2 },
    { 1.0, 0.3, 0.3 },
}

-- UTF-8 安全退格：删除字符串末尾一个完整的 Unicode 字符
local function utf8Backspace(s)
    if #s == 0 then return s end
    local i = #s
    while i > 0 do
        local b = s:byte(i)
        if b < 0x80 or b >= 0xC0 then
            return s:sub(1, i - 1)
        end
        i = i - 1
    end
    return ""
end

-- 读取 JSON 文件，返回下一个可用 ID
local function loadNextId(filename)
    local dataDir = Log.getDataDir()
    if not dataDir then return 1 end
    local path = dataDir .. "/" .. filename
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

-- 追加条目到 JSON 文件
local function appendToJson(filename, entry)
    local dataDir = Log.getDataDir()
    if not dataDir then return end
    local path = dataDir .. "/" .. filename

    local existing = "[]"
    local f = io.open(path, "r")
    if f then
        existing = f:read("*a") or "[]"
        f:close()
        existing = existing:match("^%s*(.-)%s*$")
    end

    local newContent
    if existing == "[]" or existing == "" then
        newContent = "[\n  " .. entry .. "\n]"
    else
        newContent = existing:gsub("%]%s*$", ",\n  " .. entry .. "\n]")
    end

    local fw = io.open(path, "w")
    if fw then fw:write(newContent); fw:close() end
end

-- 字符串转义（JSON 用）
local function escStr(s)
    return s:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '')
end

-- ============================================================
-- 生命周期
-- ============================================================

function DevReport:enter(data)
    self._player  = data and data.player  or nil
    self._spawner = data and data.spawner or nil
    self._enemies = data and data.enemies or nil

    self._phase       = PHASE_DESC
    self._descInput   = ""
    self._priority    = nil   -- 选好的优先级（1/2/3）
    self._savedId     = nil
    self._savedType   = nil   -- "bug" / "feature"
    self._closeTimer  = 0

    -- 光标闪烁
    self._cursorTimer   = 0
    self._cursorVisible = true

    love.keyboard.setTextInput(true)
end

function DevReport:exit()
    love.keyboard.setTextInput(false)
    self._player  = nil
    self._spawner = nil
    self._enemies = nil
end

-- ============================================================
-- 更新
-- ============================================================

function DevReport:update(dt)
    -- 光标闪烁
    self._cursorTimer = self._cursorTimer + dt
    if self._cursorTimer >= 0.5 then
        self._cursorTimer   = self._cursorTimer - 0.5
        self._cursorVisible = not self._cursorVisible
    end

    if self._phase == PHASE_DONE then
        self._closeTimer = self._closeTimer + dt
        if self._closeTimer >= CLOSE_DELAY then
            local StateManager = require("src.states.stateManager")
            StateManager.pop()
        end
    end
end

function DevReport:textinput(text)
    if self._phase == PHASE_DESC then
        self._descInput = self._descInput .. text
    end
end

function DevReport:keypressed(key)
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
        local numKey = key:match("^kp(.+)$") or key
        if numKey == "1" or numKey == "2" or numKey == "3" then
            self._priority = tonumber(numKey)
            self._phase    = PHASE_TYPE
        elseif key == "escape" then
            self._phase = PHASE_DESC
        end

    elseif self._phase == PHASE_TYPE then
        if key == "1" or key == "kp1" then
            self:_save("bug")
            self._phase = PHASE_DONE
        elseif key == "2" or key == "kp2" then
            self:_save("feature")
            self._phase = PHASE_DONE
        elseif key == "escape" then
            self._phase = PHASE_PRIORITY
        end
    end
end

-- ============================================================
-- 保存逻辑
-- ============================================================

function DevReport:_save(recordType)
    local dataDir = Log.getDataDir()
    if not dataDir then return end

    local priority = self._priority
    local desc     = self._descInput
    local timeStr  = os.date("%Y-%m-%d %H:%M:%S")
    local log      = {
        level   = self._player  and self._player._level    or 0,
        hp      = self._player  and self._player.hp        or 0,
        elapsed = self._spawner and self._spawner._elapsed  or 0.0,
        enemies = self._enemies and #self._enemies          or 0,
    }

    if recordType == "bug" then
        -- ── 保存 Bug ──────────────────────────────────────────────
        local nextId = loadNextId(BUGS_FILE)

        -- 快照日志
        local snapName = Log.snapshotForBug(nextId)
        Log.event(string.format("BUG #%d 提交 priority=%d desc=%s", nextId, priority, desc))

        local logStr = string.format(
            '"level":%d,"hp":%d,"elapsed":%.1f,"enemies":%d',
            log.level, log.hp, log.elapsed, log.enemies)
        if snapName then
            logStr = logStr .. string.format(',"logSnapshot":"%s"', escStr(snapName))
        end

        local entry = string.format(
            '{"id":%d,"desc":"%s","time":"%s","priority":%d,"log":{%s}}',
            nextId, escStr(desc), timeStr, priority, logStr)

        appendToJson(BUGS_FILE, entry)
        self._savedId   = nextId
        self._savedType = "bug"

    else
        -- ── 保存需求 ──────────────────────────────────────────────
        local nextId = loadNextId(FEATURES_FILE)
        Log.event(string.format("FEATURE #%d 提交 priority=%d desc=%s", nextId, priority, desc))

        local logStr = string.format(
            '"level":%d,"hp":%d,"elapsed":%.1f,"enemies":%d',
            log.level, log.hp, log.elapsed, log.enemies)

        local entry = string.format(
            '{"id":%d,"desc":"%s","time":"%s","priority":%d,"status":"pending","log":{%s}}',
            nextId, escStr(desc), timeStr, priority, logStr)

        appendToJson(FEATURES_FILE, entry)

        -- 追加到 features.md
        local prioTag  = PRIORITY_NAMES[priority] or tostring(priority)
        local mdPath   = dataDir .. "/" .. FEATURES_MD
        local md       = ""
        local fm = io.open(mdPath, "r")
        if fm then md = fm:read("*a") or ""; fm:close() end

        local newLine = string.format("\n- [ ] #%d %s（优先级：%s）（%s）",
            nextId, desc, prioTag, timeStr)

        if md:find("## 待实现") then
            md = md:gsub("(## 待实现[^\n]*\n)", "%1" .. newLine)
        else
            md = md .. "\n## 待实现\n" .. newLine .. "\n"
        end

        local fmd = io.open(mdPath, "w")
        if fmd then fmd:write(md); fmd:close() end

        self._savedId   = nextId
        self._savedType = "feature"
    end
end

-- ============================================================
-- 绘制
-- ============================================================

function DevReport:draw()
    Font.set(15)

    -- 半透明背景遮罩
    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", 0, 0, 1280, 720)

    -- 面板背景
    love.graphics.setColor(0.07, 0.07, 0.12, 0.96)
    love.graphics.rectangle("fill", PANEL_X, PANEL_Y, PANEL_W, PANEL_H, 8, 8)

    -- 阶段决定边框颜色：desc/priority 白色，type 时根据悬停变色，done 时根据类型变色
    local borderR, borderG, borderB = 0.6, 0.6, 0.8
    if self._phase == PHASE_DONE then
        if self._savedType == "bug" then
            borderR, borderG, borderB = 1.0, 0.4, 0.4
        else
            borderR, borderG, borderB = 0.2, 0.7, 1.0
        end
    end
    love.graphics.setColor(borderR, borderG, borderB, 0.9)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", PANEL_X, PANEL_Y, PANEL_W, PANEL_H, 8, 8)
    love.graphics.setLineWidth(1)

    -- 标题
    love.graphics.setColor(0.85, 0.85, 1.0)
    love.graphics.printf("[DEV] 开发反馈", PANEL_X, PANEL_Y + 16, PANEL_W, "center")

    -- 阶段步骤指示（小字）
    Font.set(12)
    local steps = { "1.描述", "2.优先级", "3.类型" }
    local stepColors = {
        { 1.0, 1.0, 1.0 },   -- 当前阶段
        { 0.5, 0.5, 0.5 },   -- 未到达
    }
    local phaseOrder = { [PHASE_DESC]=1, [PHASE_PRIORITY]=2, [PHASE_TYPE]=3, [PHASE_DONE]=3 }
    local curStep    = phaseOrder[self._phase] or 1
    local stepsStr   = ""
    local stepX      = PANEL_X + PANEL_W * 0.5 - 100
    for i, s in ipairs(steps) do
        if i == curStep then
            love.graphics.setColor(1.0, 0.85, 0.2)
        elseif i < curStep then
            love.graphics.setColor(0.4, 0.8, 0.4)
        else
            love.graphics.setColor(0.4, 0.4, 0.4)
        end
        love.graphics.print(s, stepX + (i-1) * 68, PANEL_Y + 42)
    end
    Font.set(15)

    -- ── 阶段内容 ──────────────────────────────────────────────────

    if self._phase == PHASE_DESC then
        love.graphics.setColor(0.85, 0.85, 0.85)
        love.graphics.print("描述 Bug 或需求：", PANEL_X + 20, PANEL_Y + 72)

        -- 输入框背景
        love.graphics.setColor(0.05, 0.05, 0.08)
        love.graphics.rectangle("fill", PANEL_X + 20, PANEL_Y + 100, PANEL_W - 40, 60, 4, 4)
        love.graphics.setColor(0.35, 0.35, 0.55)
        love.graphics.rectangle("line", PANEL_X + 20, PANEL_Y + 100, PANEL_W - 40, 60, 4, 4)

        local cursor = self._cursorVisible and "|" or " "
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(self._descInput .. cursor, PANEL_X + 28, PANEL_Y + 116, PANEL_W - 56, "left")

        love.graphics.setColor(0.45, 0.45, 0.45)
        love.graphics.printf("Enter 下一步  |  ESC 取消", PANEL_X, PANEL_Y + PANEL_H - 36, PANEL_W, "center")

    elseif self._phase == PHASE_PRIORITY then
        love.graphics.setColor(0.85, 0.85, 0.85)
        love.graphics.printf("选择优先级：", PANEL_X, PANEL_Y + 108, PANEL_W, "center")

        local btnW   = 160
        local gap    = 20
        local totalW = btnW * 3 + gap * 2
        local startX = PANEL_X + (PANEL_W - totalW) / 2
        for i = 1, 3 do
            local bx  = startX + (i - 1) * (btnW + gap)
            local by  = PANEL_Y + 148
            local col = PRIORITY_COLORS[i]
            love.graphics.setColor(col[1]*0.2, col[2]*0.2, col[3]*0.2, 0.9)
            love.graphics.rectangle("fill", bx, by, btnW, 50, 6, 6)
            love.graphics.setColor(col)
            love.graphics.rectangle("line", bx, by, btnW, 50, 6, 6)
            love.graphics.printf(PRIORITY_LABELS[i], bx, by + 16, btnW, "center")
        end

        love.graphics.setColor(0.45, 0.45, 0.45)
        love.graphics.printf("按 1/2/3 选择  |  ESC 返回修改描述", PANEL_X, PANEL_Y + PANEL_H - 36, PANEL_W, "center")

    elseif self._phase == PHASE_TYPE then
        love.graphics.setColor(0.85, 0.85, 0.85)
        love.graphics.printf("这是 Bug 还是需求？", PANEL_X, PANEL_Y + 108, PANEL_W, "center")

        local halfW  = 220
        local gap    = 30
        local totalW = halfW * 2 + gap
        local startX = PANEL_X + (PANEL_W - totalW) / 2
        local by     = PANEL_Y + 152

        -- Bug 按钮（红色）
        love.graphics.setColor(0.25, 0.06, 0.06, 0.9)
        love.graphics.rectangle("fill", startX, by, halfW, 60, 6, 6)
        love.graphics.setColor(1.0, 0.35, 0.35)
        love.graphics.rectangle("line", startX, by, halfW, 60, 6, 6)
        love.graphics.setColor(1.0, 0.5, 0.5)
        love.graphics.printf("1  -  Bug", startX, by + 20, halfW, "center")

        -- 需求按钮（蓝色）
        local bx2 = startX + halfW + gap
        love.graphics.setColor(0.04, 0.10, 0.20, 0.9)
        love.graphics.rectangle("fill", bx2, by, halfW, 60, 6, 6)
        love.graphics.setColor(0.2, 0.65, 1.0)
        love.graphics.rectangle("line", bx2, by, halfW, 60, 6, 6)
        love.graphics.setColor(0.4, 0.8, 1.0)
        love.graphics.printf("2  -  需求", bx2, by + 20, halfW, "center")

        love.graphics.setColor(0.45, 0.45, 0.45)
        love.graphics.printf("按 1 或 2 选择  |  ESC 返回修改优先级", PANEL_X, PANEL_Y + PANEL_H - 36, PANEL_W, "center")

    elseif self._phase == PHASE_DONE then
        local typeLabel = self._savedType == "bug" and "Bug" or "需求"
        local typeColor = self._savedType == "bug" and {1.0, 0.5, 0.5} or {0.4, 0.85, 1.0}
        love.graphics.setColor(typeColor)
        love.graphics.printf(
            string.format("%s #%d 已记录，感谢反馈！", typeLabel, self._savedId or 0),
            PANEL_X, PANEL_Y + 130, PANEL_W, "center")

        love.graphics.setColor(0.45, 0.45, 0.45)
        love.graphics.printf("正在关闭...", PANEL_X, PANEL_Y + 180, PANEL_W, "center")
    end

    Font.reset()
end

return DevReport
