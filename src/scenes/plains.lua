--[[
    src/scenes/plains.lua
    基础平原场景 — Phase 12
    无限延伸地图，随机视觉障碍物（不影响碰撞），默认难度曲线
]]

local BaseScene   = require("src.scenes.baseScene")
local SceneConfig = require("config.scenes")
local Font        = require("src.utils.font")

local Plains = setmetatable({}, { __index = BaseScene })
Plains.__index = Plains

-- 障碍物数量范围
local OBSTACLE_COUNT_MIN = 30
local OBSTACLE_COUNT_MAX = 50
-- 障碍物生成范围（以世界原点为中心的半径）
local OBSTACLE_RANGE = 2000
-- 障碍物不在玩家出生点附近生成的安全半径
local SAFE_RADIUS = 200

-- 障碍物颜色配置
local ROCK_COLOR  = { 0.45, 0.42, 0.38 }
local TREE_COLOR  = { 0.22, 0.52, 0.22 }
local ROCK_DARK   = { 0.30, 0.28, 0.25 }

function Plains.new()
    local self = BaseScene.new(SceneConfig.plains)
    return setmetatable(self, Plains)
end

-- ============================================================
-- 生命周期
-- ============================================================

function Plains:onEnter(player)
    self._obstacles = {}
    local count = math.random(OBSTACLE_COUNT_MIN, OBSTACLE_COUNT_MAX)
    for i = 1, count do
        local angle = math.random() * math.pi * 2
        local dist  = SAFE_RADIUS + math.random() * (OBSTACLE_RANGE - SAFE_RADIUS)
        local ox    = math.cos(angle) * dist
        local oy    = math.sin(angle) * dist
        local oType = math.random() < 0.55 and "rock" or "tree"
        local oR    = oType == "rock" and math.random(14, 28) or math.random(10, 20)
        table.insert(self._obstacles, {
            x    = ox,
            y    = oy,
            type = oType,
            r    = oR,
            rot  = math.random() * math.pi * 2,  -- 随机初始旋转（岩石用）
        })
    end
end

function Plains:onExit()
    self._obstacles = nil
end

-- ============================================================
-- 绘制
-- ============================================================

function Plains:draw(camera)
    -- 深色地面底色
    love.graphics.setColor(0.08, 0.10, 0.08)
    love.graphics.rectangle("fill", -10000, -10000, 20000, 20000)

    -- 参考网格线
    love.graphics.setColor(0.13, 0.16, 0.13)
    local gridSize = 64
    local cx = camera and camera.x or 0
    local cy = camera and camera.y or 0
    local hw, hh = 700, 400
    local startX = math.floor((cx - hw) / gridSize) * gridSize
    local startY = math.floor((cy - hh) / gridSize) * gridSize
    for x = startX, startX + hw * 2 + gridSize, gridSize do
        love.graphics.line(x, startY - hh, x, startY + hh * 2 + gridSize)
    end
    for y = startY, startY + hh * 2 + gridSize, gridSize do
        love.graphics.line(startX - hw, y, startX + hw * 2 + gridSize, y)
    end

    -- 绘制障碍物（只绘制摄像机可见范围内的）
    if not self._obstacles then return end
    local visR = 800  -- 可见范围半径（保守估计）
    for _, o in ipairs(self._obstacles) do
        local dx = o.x - cx
        local dy = o.y - cy
        if dx * dx + dy * dy < visR * visR then
            if o.type == "rock" then
                self:_drawRock(o)
            else
                self:_drawTree(o)
            end
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- 绘制岩石（粗糙多边形感觉）
function Plains:_drawRock(o)
    local r = o.r
    -- 阴影
    love.graphics.setColor(0.08, 0.08, 0.08, 0.5)
    love.graphics.ellipse("fill", o.x + 4, o.y + 5, r * 1.1, r * 0.7)
    -- 主体（多边形近似，6边）
    love.graphics.setColor(ROCK_COLOR)
    local verts = {}
    local sides = 6
    for i = 0, sides - 1 do
        local a = o.rot + i * (math.pi * 2 / sides)
        local rr = r * (0.85 + 0.15 * math.sin(i * 1.7))  -- 凹凸感
        table.insert(verts, o.x + math.cos(a) * rr)
        table.insert(verts, o.y + math.sin(a) * rr * 0.75)
    end
    love.graphics.polygon("fill", verts)
    -- 高光边缘
    love.graphics.setColor(ROCK_DARK)
    love.graphics.polygon("line", verts)
end

-- 绘制树木（圆形树冠 + 小树干）
function Plains:_drawTree(o)
    local r = o.r
    -- 阴影
    love.graphics.setColor(0.05, 0.10, 0.05, 0.45)
    love.graphics.ellipse("fill", o.x + 3, o.y + 6, r * 1.15, r * 0.65)
    -- 树干
    love.graphics.setColor(0.30, 0.20, 0.10)
    love.graphics.rectangle("fill", o.x - 3, o.y, 6, r * 0.5)
    -- 树冠外层（深绿）
    love.graphics.setColor(TREE_COLOR[1] * 0.8, TREE_COLOR[2] * 0.8, TREE_COLOR[3] * 0.8)
    love.graphics.circle("fill", o.x, o.y - r * 0.1, r)
    -- 树冠内层（亮绿高光）
    love.graphics.setColor(TREE_COLOR)
    love.graphics.circle("fill", o.x - r * 0.2, o.y - r * 0.35, r * 0.65)
end

return Plains
