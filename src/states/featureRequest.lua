--[[
    src/states/featureRequest.lua
    需求反馈面板，按 F11 呼出，叠加在任意状态上方
    两阶段输入：描述 -> 优先级
    数据写入项目 data/features.json，同时追加到 data/features.md
    可剔除：注释 main.lua 中的 require/register/F11 三行即可完全移除
]]

local Font = require("src.utils.font")
local Log  = require("src.utils.log")

local FeatureRequest = {}

-- 输入阶段枚举
local PHASE_DESC     = "desc"      -- 输入描述阶段
local PHASE_PRIORITY = "priority"  -- 选择优先级阶段
local PHASE_DONE     = "done"      -- 已保存，显示确认后自动关闭

-- 保存文件名（相对于 data/ 目录）
local FEATURES_FILE = "features.json"
local FEATURES_MD   = "features.md"

-- 关闭前的停留时间（秒）
local CLOSE_DELAY = 1.5

-- 面板尺寸（居中显示）
local PANEL_W = 700
local PANEL_H = 300
local PANEL_X = (1280 - PANEL_W) / 2
local PANEL_Y = (720  - PANEL_H) / 2

-- 优先级标签
local PRIORITY_LABELS = { "1 - 低", "2 - 中", "3 - 高" }
local PRIORITY_NAMES  = { "低", "中", "高" }
local PRIORITY_COLORS = {
    {0.3, 0.9, 0.3},
    {0.9, 0.8, 0.2},
    {1.0, 0.3, 0.3},
}

-- UTF-8 安全退格
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

-- 进入需求反馈状态
-- @param data: { player, spawner, enemies }
function FeatureRequest:enter(data)
    self._player  = data and data.player  or nil
    self._spawner = data and data.spawner or nil
    self._enemies = data and data.enemies or nil

    self._phase      = PHASE_DESC
    self._descInput  = ""
    self._savedId    = nil
    self._closeTimer = 0

    -- 光标闪烁
    self._cursorTimer   = 0
    self._cursorVisible = true

    -- 读取已有 features.json，确定下一个 ID
    self._nextId = self:_loadNextId()

    love.keyboard.setTextInput(true)
end

-- 退出需求反馈状态
function FeatureRequest:exit()
    love.keyboard.setTextInput(false)
    self._player  = nil
    self._spawner = nil
    self._enemies = nil
end

-- 每帧更新
function FeatureRequest:update(dt)
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
function FeatureRequest:textinput(text)
    if self._phase == PHASE_DESC then
        self._descInput = self._descInput .. text
    end
end

-- 键盘按下事件
function FeatureRequest:keypressed(key)
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
            self:_saveFeature(priority)
            self._phase = PHASE_DONE
        elseif key == "escape" then
            self._phase = PHASE_DESC
        end
    end
end

-- 读取 features.json，返回下一个可用 ID
function FeatureRequest:_loadNextId()
    local dataDir = Log.getDataDir()
    if not dataDir then return 1 end

    local path = dataDir .. "/" .. FEATURES_FILE
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

-- 将需求数据序列化为 JSON 字符串
local function serializeFeature(feat)
    local function escStr(s)
        return s:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '')
    end

    local logStr = string.format(
        '"level":%d,"hp":%d,"elapsed":%.1f,"enemies":%d',
        feat.log.level, feat.log.hp, feat.log.elapsed, feat.log.enemies
    )

    return string.format(
        '{"id":%d,"desc":"%s","time":"%s","priority":%d,"status":"pending","log":{%s}}',
        feat.id,
        escStr(feat.desc),
        feat.time,
        feat.priority,
        logStr
    )
end

-- 保存需求到 data/features.json，并追加到 data/features.md
function FeatureRequest:_saveFeature(priority)
    local dataDir = Log.getDataDir()
    if not dataDir then return end

    -- 记录事件到主日志
    Log.event(string.format("FEATURE #%d 提交 priority=%d desc=%s",
        self._nextId, priority, self._descInput))

    local feat = {
        id       = self._nextId,
        desc     = self._descInput,
        time     = os.date("%Y-%m-%d %H:%M:%S"),
        priority = priority,
        log      = {
            level   = self._player  and self._player._level    or 0,
            hp      = self._player  and self._player.hp        or 0,
            elapsed = self._spawner and self._spawner._elapsed  or 0.0,
            enemies = self._enemies and #self._enemies          or 0,
        },
    }

    -- ── 写入 features.json ──────────────────────────────────────────
    local jsonPath = dataDir .. "/" .. FEATURES_FILE

    local existing = "[]"
    local f = io.open(jsonPath, "r")
    if f then
        existing = f:read("*a") or "[]"
        f:close()
        existing = existing:match("^%s*(.-)%s*$")
    end

    local newEntry = serializeFeature(feat)
    local newContent
    if existing == "[]" or existing == "" then
        newContent = "[\n  " .. newEntry .. "\n]"
    else
        newContent = existing:gsub("%]%s*$", ",\n  " .. newEntry .. "\n]")
    end

    local fw = io.open(jsonPath, "w")
    if fw then
        fw:write(newContent)
        fw:close()
    end

    -- ── 追加到 features.md ──────────────────────────────────────────
    local mdPath  = dataDir .. "/" .. FEATURES_MD
    local prioTag = PRIORITY_NAMES[priority] or tostring(priority)

    -- 读取 md，找到"## 待实现"区块末尾插入新条目
    local md = ""
    local fm = io.open(mdPath, "r")
    if fm then
        md = fm:read("*a") or ""
        fm:close()
    end

    local newLine = string.format("\n- [ ] #%d %s（优先级：%s）（%s）",
        feat.id, feat.desc, prioTag, feat.time)

    -- 在"## 待实现"后面插入（若不存在则追加到末尾）
    if md:find("## 待实现") then
        md = md:gsub("(## 待实现[^\n]*\n)", "%1" .. newLine)
    else
        md = md .. "\n## 待实现\n" .. newLine .. "\n"
    end

    local fmd = io.open(mdPath, "w")
    if fmd then
        fmd:write(md)
        fmd:close()
    end

    self._savedId = feat.id
end

-- 每帧绘制需求反馈面板
function FeatureRequest:draw()
    Font.set(15)

    -- 半透明背景遮罩
    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", 0, 0, 1280, 720)

    -- 面板背景
    love.graphics.setColor(0.05, 0.08, 0.12, 0.96)
    love.graphics.rectangle("fill", PANEL_X, PANEL_Y, PANEL_W, PANEL_H, 8, 8)

    -- 面板边框（蓝绿色，与 bug 红色区分）
    love.graphics.setColor(0.2, 0.7, 1.0, 0.9)
    love.graphics.rectangle("line", PANEL_X, PANEL_Y, PANEL_W, PANEL_H, 8, 8)

    -- 标题
    love.graphics.setColor(0.3, 0.85, 1.0)
    love.graphics.printf("💡  需求反馈", PANEL_X, PANEL_Y + 18, PANEL_W, "center")

    if self._phase == PHASE_DESC then
        love.graphics.setColor(0.85, 0.85, 0.85)
        love.graphics.print("描述你的需求或想法：", PANEL_X + 20, PANEL_Y + 70)

        -- 输入框背景
        love.graphics.setColor(0.04, 0.06, 0.10)
        love.graphics.rectangle("fill", PANEL_X + 20, PANEL_Y + 100, PANEL_W - 40, 60, 4, 4)
        love.graphics.setColor(0.25, 0.55, 0.8)
        love.graphics.rectangle("line", PANEL_X + 20, PANEL_Y + 100, PANEL_W - 40, 60, 4, 4)

        -- 输入文字 + 光标
        local cursor = self._cursorVisible and "|" or " "
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(self._descInput .. cursor,
            PANEL_X + 28, PANEL_Y + 116, PANEL_W - 56, "left")

        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.printf("Enter 确认  |  ESC 取消", PANEL_X, PANEL_Y + PANEL_H - 44, PANEL_W, "center")

    elseif self._phase == PHASE_PRIORITY then
        love.graphics.setColor(0.85, 0.85, 0.85)
        love.graphics.printf("选择优先级：", PANEL_X, PANEL_Y + 120, PANEL_W, "center")

        local btnW   = 160
        local gap    = 20
        local totalW = btnW * 3 + gap * 2
        local startX = PANEL_X + (PANEL_W - totalW) / 2
        for i = 1, 3 do
            local bx  = startX + (i - 1) * (btnW + gap)
            local by  = PANEL_Y + 160
            local col = PRIORITY_COLORS[i]
            love.graphics.setColor(col[1]*0.2, col[2]*0.2, col[3]*0.2, 0.9)
            love.graphics.rectangle("fill", bx, by, btnW, 50, 6, 6)
            love.graphics.setColor(col)
            love.graphics.rectangle("line", bx, by, btnW, 50, 6, 6)
            love.graphics.printf(PRIORITY_LABELS[i], bx, by + 16, btnW, "center")
        end

        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.printf("按 1/2/3 选择  |  ESC 返回修改", PANEL_X, PANEL_Y + PANEL_H - 44, PANEL_W, "center")

    elseif self._phase == PHASE_DONE then
        love.graphics.setColor(0.3, 1, 0.6)
        love.graphics.printf(
            string.format("需求 #%d 已记录，感谢反馈！", self._savedId or 0),
            PANEL_X, PANEL_Y + 130, PANEL_W, "center")

        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.printf("正在关闭...", PANEL_X, PANEL_Y + 180, PANEL_W, "center")
    end

    Font.reset()
end

return FeatureRequest
