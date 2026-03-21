--[[
    src/states/gameover.lua
    游戏结算状态，玩家死亡或胜利后显示
    Phase 10：逐条动画显示统计数据，胜利/死亡两套完全不同视觉设计，按任意键才能继续
]]

local Gameover = {}

local Font = require("src.utils.font")

-- 结算数据项定义（显示顺序）
local STAT_ITEMS = {
    { key = "elapsed",      label = "gameover.stat.elapsed",   format = "time"   },
    { key = "level",        label = "gameover.stat.level",     format = "number" },
    { key = "killCount",    label = "gameover.stat.kills",     format = "number" },
    { key = "souls",        label = "gameover.stat.souls",     format = "number" },
    { key = "activeSynergies", label = "gameover.stat.synergies", format = "synergy" },
    { key = "killedBosses", label = "gameover.stat.bosses",    format = "list"   },
}

-- 动画参数
local REVEAL_INTERVAL = 0.4   -- 每条数据出现的间隔（秒）
local COUNTER_SPEED   = 0.6   -- 数字滚动到目标值所需时间（秒）

-- 进入结算状态时调用
-- @param data: 传入的结算数据（含 isVictory、elapsed、level、killCount、souls、activeSynergies、killedBosses）
function Gameover:enter(data)
    self._data      = data or {}
    self._isVictory = self._data.isVictory or false

    -- 动画状态
    self._revealTimer   = 0       -- 每条数据的出现计时
    self._revealIndex   = 0       -- 当前已出现的数据条数
    self._allRevealed   = false   -- 是否全部已显示
    self._canExit       = false   -- 是否可以按键退出

    -- 数字滚动计数器（每项一个）
    self._counters = {}
    for i = 1, #STAT_ITEMS do
        self._counters[i] = {
            current  = 0,
            target   = 0,
            progress = 0,
        }
    end

    -- 预填充目标值
    for i, item in ipairs(STAT_ITEMS) do
        if item.format == "number" then
            self._counters[i].target = self._data[item.key] or 0
        elseif item.format == "time" then
            self._counters[i].target = self._data[item.key] or 0
        else
            -- list/synergy 类型不需要计数器
            self._counters[i].target   = 0
            self._counters[i].current  = 1
            self._counters[i].progress = 1
        end
    end

    -- 背景粒子（简单闪光装饰）
    self._sparkles = {}
    if self._isVictory then
        for _ = 1, 30 do
            table.insert(self._sparkles, {
                x = math.random(100, 1180),
                y = math.random(100, 620),
                r = math.random() * 4 + 1,
                alpha = math.random(),
                speed = math.random() * 0.5 + 0.3,
                drift = (math.random() - 0.5) * 60,
            })
        end
    end
end

-- 退出结算状态时调用
function Gameover:exit()
    self._data        = nil
    self._isVictory   = false
    self._sparkles    = {}
    self._counters    = {}
    self._allRevealed = false
    self._canExit     = false
end

-- 每帧更新结算界面逻辑
function Gameover:update(dt)
    -- 更新粒子
    for _, s in ipairs(self._sparkles) do
        s.alpha = s.alpha - dt * s.speed
        s.y     = s.y - dt * 15
        s.x     = s.x + dt * s.drift
        if s.alpha <= 0 then
            s.alpha = math.random() * 0.8 + 0.2
            s.x     = math.random(100, 1180)
            s.y     = math.random(400, 620)
        end
    end

    -- 逐条出现逻辑
    if not self._allRevealed then
        self._revealTimer = self._revealTimer + dt
        if self._revealTimer >= REVEAL_INTERVAL then
            self._revealTimer = self._revealTimer - REVEAL_INTERVAL
            self._revealIndex = self._revealIndex + 1
            if self._revealIndex >= #STAT_ITEMS then
                self._allRevealed = true
                -- 所有数据出现后 0.5 秒，允许按键退出
                self._exitDelay = 0.5
            end
        end
    else
        if not self._canExit then
            self._exitDelay = (self._exitDelay or 0) - dt
            if self._exitDelay <= 0 then
                self._canExit = true
            end
        end
    end

    -- 数字滚动更新
    for i = 1, self._revealIndex do
        local c = self._counters[i]
        if c.progress < 1 then
            c.progress = math.min(1, c.progress + dt / COUNTER_SPEED)
            -- 使用 ease-out 曲线
            local t = 1 - (1 - c.progress) * (1 - c.progress)
            c.current = math.floor(t * c.target)
        else
            c.current = c.target
        end
    end
end

-- 每帧绘制结算界面
function Gameover:draw()
    if self._isVictory then
        self:_drawVictory()
    else
        self:_drawDeath()
    end

    Font.reset()
    love.graphics.setColor(1, 1, 1, 1)
end

-- 绘制胜利结算界面
function Gameover:_drawVictory()
    -- 深绿色背景
    love.graphics.setBackgroundColor(0.02, 0.08, 0.04)

    -- 金色粒子装饰
    for _, s in ipairs(self._sparkles) do
        love.graphics.setColor(1.0, 0.9, 0.3, s.alpha)
        love.graphics.circle("fill", s.x, s.y, s.r)
    end

    -- 顶部金色横线
    love.graphics.setColor(1.0, 0.85, 0.15, 0.6)
    love.graphics.rectangle("fill", 80, 135, 1120, 2)

    -- 胜利大标题
    Font.set(58)
    love.graphics.setColor(1.0, 0.85, 0.15)
    love.graphics.printf(T("gameover.victory_title"), 0, 50, 1280, "center")

    -- 副标题
    Font.set(18)
    love.graphics.setColor(0.6, 1.0, 0.75)
    love.graphics.printf(T("gameover.victory_sub"), 0, 110, 1280, "center")

    -- 底部横线
    love.graphics.setColor(1.0, 0.85, 0.15, 0.6)
    love.graphics.rectangle("fill", 80, 145, 1120, 1)

    -- 统计数据
    self:_drawStats(160, { 1.0, 0.95, 0.6 }, { 0.3, 1.0, 0.6 })

    -- 按键提示
    self:_drawHint()
end

-- 绘制死亡结算界面
function Gameover:_drawDeath()
    -- 深暗色背景
    love.graphics.setBackgroundColor(0.04, 0.02, 0.05)

    -- 暗红色上横线
    love.graphics.setColor(0.9, 0.2, 0.2, 0.5)
    love.graphics.rectangle("fill", 80, 135, 1120, 2)

    -- 失败大标题
    Font.set(58)
    love.graphics.setColor(0.95, 0.25, 0.25)
    love.graphics.printf(T("gameover.title"), 0, 50, 1280, "center")

    -- 副标题
    Font.set(18)
    love.graphics.setColor(0.7, 0.55, 0.55)
    love.graphics.printf(T("gameover.death_sub"), 0, 110, 1280, "center")

    -- 底部横线
    love.graphics.setColor(0.9, 0.2, 0.2, 0.5)
    love.graphics.rectangle("fill", 80, 145, 1120, 1)

    -- 统计数据
    self:_drawStats(160, { 1.0, 0.8, 0.8 }, { 1.0, 0.45, 0.45 })

    -- 按键提示
    self:_drawHint()
end

-- 绘制统计数据列表
-- @param startY: 起始 Y 坐标
-- @param labelColor: 标签颜色 {r,g,b}
-- @param valueColor: 数值颜色 {r,g,b}
function Gameover:_drawStats(startY, labelColor, valueColor)
    local centerX  = 640
    local colWidth = 400
    local rowH     = 62
    local panelW   = 680
    local panelX   = centerX - panelW / 2

    -- 数据面板背景
    local visibleCount = math.min(self._revealIndex, #STAT_ITEMS)
    if visibleCount > 0 then
        local panelH = visibleCount * rowH + 16
        love.graphics.setColor(0, 0, 0, 0.35)
        love.graphics.rectangle("fill", panelX - 10, startY - 8, panelW + 20, panelH, 6, 6)
        love.graphics.setColor(labelColor[1], labelColor[2], labelColor[3], 0.15)
        love.graphics.rectangle("line", panelX - 10, startY - 8, panelW + 20, panelH, 6, 6)
    end

    for i = 1, visibleCount do
        local item = STAT_ITEMS[i]
        local y    = startY + (i - 1) * rowH
        local c    = self._counters[i]

        -- 入场动画：从右侧滑入
        local slideProgress = math.min(1, c.progress * 3)
        local slideOffset   = (1 - slideProgress) * 40
        -- ease-out
        slideOffset = slideOffset * (1 - slideProgress)

        -- 行背景（交替）
        if i % 2 == 0 then
            love.graphics.setColor(1, 1, 1, 0.04)
            love.graphics.rectangle("fill", panelX - 10, y - 2, panelW + 20, rowH - 2)
        end

        -- 左侧小竖条装饰
        love.graphics.setColor(labelColor[1], labelColor[2], labelColor[3], 0.7)
        love.graphics.rectangle("fill", panelX - 10, y + 4, 3, rowH - 14)

        -- 标签文字
        Font.set(15)
        love.graphics.setColor(labelColor[1], labelColor[2], labelColor[3], 0.85)
        love.graphics.print(T(item.label), panelX + 10 + slideOffset, y + 8)

        -- 数值文字
        Font.set(26)
        local valueStr = self:_formatValue(item, c.current, i)
        love.graphics.setColor(valueColor[1], valueColor[2], valueColor[3])
        love.graphics.printf(valueStr, panelX - 10 + slideOffset, y + 4, panelW, "right")

        -- 分隔线
        if i < visibleCount then
            love.graphics.setColor(labelColor[1], labelColor[2], labelColor[3], 0.1)
            love.graphics.rectangle("fill", panelX, y + rowH - 3, panelW, 1)
        end
    end
end

-- 格式化统计数值
function Gameover:_formatValue(item, current, index)
    local data = self._data
    if item.format == "time" then
        local minutes = math.floor(current / 60)
        local seconds = math.floor(current % 60)
        return string.format("%02d:%02d", minutes, seconds)
    elseif item.format == "number" then
        return tostring(current)
    elseif item.format == "synergy" then
        local synergies = data.activeSynergies or {}
        if #synergies == 0 then
            return T("gameover.stat.none")
        end
        local names = {}
        for _, syn in ipairs(synergies) do
            table.insert(names, T(syn.nameKey))
        end
        return table.concat(names, " / ")
    elseif item.format == "list" then
        local bosses = data.killedBosses or {}
        if #bosses == 0 then
            return T("gameover.stat.none")
        end
        -- Boss 名称本地化
        local names = {}
        for _, bossId in ipairs(bosses) do
            local key = "boss." .. bossId .. ".name"
            local name = T(key)
            -- 若 T() 找不到 key，会返回 key 本身，做一下容错
            table.insert(names, name ~= key and name or bossId)
        end
        return table.concat(names, " / ")
    end
    return "—"
end

-- 绘制按键提示
function Gameover:_drawHint()
    if self._canExit then
        -- 闪烁效果
        local alpha = 0.5 + 0.5 * math.sin(love.timer.getTime() * 3)
        Font.set(16)
        love.graphics.setColor(0.6, 0.6, 0.6, alpha)
        love.graphics.printf(T("gameover.hint"), 0, 670, 1280, "center")
    end
end

-- 键盘按下事件（任意键继续）
function Gameover:keypressed(key)
    if self._canExit then
        local StateManager = require("src.states.stateManager")
        StateManager.switch("menu")
    end
end

return Gameover
