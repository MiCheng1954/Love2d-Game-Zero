--[[
    src/scenes/dungeon.lua
    地下城场景骨架 — Phase 12（框架实现，不完整游戏流程）
    数据结构：5×5 房间网格，房间连通廊道，基础绘制
    TODO：正式实装（房间触发、专属 Boss、细节美化）
]]

local BaseScene   = require("src.scenes.baseScene")
local SceneConfig = require("config.scenes")

local Dungeon = setmetatable({}, { __index = BaseScene })
Dungeon.__index = Dungeon

-- 房间尺寸参数
local ROOM_W     = 320   -- 每间房宽度（px）
local ROOM_H     = 240   -- 每间房高度（px）
local CORRIDOR_W = 60    -- 廊道宽度（px）
local GRID_COLS  = 5     -- 列数
local GRID_ROWS  = 5     -- 行数

function Dungeon.new()
    local self = BaseScene.new(SceneConfig.dungeon)
    self._rooms = nil    -- 房间数据表
    return setmetatable(self, Dungeon)
end

-- ============================================================
-- 生命周期
-- ============================================================

function Dungeon:onEnter(player)
    self._rooms = self:_generateRooms()
end

function Dungeon:onExit()
    self._rooms = nil
end

-- ============================================================
-- 房间生成（5×5 网格，随机连通）
-- ============================================================

function Dungeon:_generateRooms()
    local rooms = {}
    -- 起始位置（以 0,0 为原点，房间中心坐标）
    for row = 1, GRID_ROWS do
        for col = 1, GRID_COLS do
            local cx = (col - 1) * (ROOM_W + CORRIDOR_W) - (GRID_COLS - 1) * (ROOM_W + CORRIDOR_W) / 2
            local cy = (row - 1) * (ROOM_H + CORRIDOR_W) - (GRID_ROWS - 1) * (ROOM_H + CORRIDOR_W) / 2
            local rType = "normal"
            if row == 3 and col == 3 then rType = "start" end  -- 中央起始房
            table.insert(rooms, {
                row   = row,
                col   = col,
                cx    = cx,
                cy    = cy,
                type  = rType,
                -- 连接标志：right=向右有廊道, down=向下有廊道
                right = (col < GRID_COLS) and (math.random() < 0.65),
                down  = (row < GRID_ROWS) and (math.random() < 0.65),
            })
        end
    end
    return rooms
end

-- ============================================================
-- 更新（无特殊逻辑，目前仅骨架）
-- ============================================================

function Dungeon:update(dt, player)
    -- TODO：房间入场触发、敌人生成等
end

-- ============================================================
-- 绘制
-- ============================================================

function Dungeon:draw(camera)
    -- 全局深色背景
    love.graphics.setColor(0.05, 0.04, 0.07)
    love.graphics.rectangle("fill", -10000, -10000, 20000, 20000)

    if not self._rooms then return end

    local cx = camera and camera.x or 0
    local cy = camera and camera.y or 0
    local visR = 1000

    for _, room in ipairs(self._rooms) do
        local dx = room.cx - cx
        local dy = room.cy - cy
        if dx * dx + dy * dy < visR * visR then
            self:_drawRoom(room)
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- 绘制单间房
function Dungeon:_drawRoom(room)
    local x = room.cx - ROOM_W / 2
    local y = room.cy - ROOM_H / 2

    -- 地板
    if room.type == "start" then
        love.graphics.setColor(0.12, 0.10, 0.18)
    else
        love.graphics.setColor(0.10, 0.09, 0.14)
    end
    love.graphics.rectangle("fill", x, y, ROOM_W, ROOM_H)

    -- 地板网格
    love.graphics.setColor(0.14, 0.12, 0.19)
    local gs = 40
    for gx = x, x + ROOM_W, gs do
        love.graphics.line(gx, y, gx, y + ROOM_H)
    end
    for gy = y, y + ROOM_H, gs do
        love.graphics.line(x, gy, x + ROOM_W, gy)
    end

    -- 墙壁
    love.graphics.setColor(0.22, 0.18, 0.28)
    love.graphics.setLineWidth(4)
    love.graphics.rectangle("line", x, y, ROOM_W, ROOM_H)
    love.graphics.setLineWidth(1)

    -- 廊道（向右）
    if room.right then
        local cx2 = room.cx + ROOM_W / 2
        local cy2 = room.cy - CORRIDOR_W / 2
        love.graphics.setColor(0.10, 0.09, 0.14)
        love.graphics.rectangle("fill", cx2, cy2, CORRIDOR_W, CORRIDOR_W)
    end

    -- 廊道（向下）
    if room.down then
        local cx2 = room.cx - CORRIDOR_W / 2
        local cy2 = room.cy + ROOM_H / 2
        love.graphics.setColor(0.10, 0.09, 0.14)
        love.graphics.rectangle("fill", cx2, cy2, CORRIDOR_W, CORRIDOR_W)
    end

    -- 起始房间特殊标记
    if room.type == "start" then
        love.graphics.setColor(0.55, 0.35, 0.80, 0.4)
        love.graphics.circle("fill", room.cx, room.cy, 28)
        love.graphics.setColor(0.65, 0.45, 0.90, 0.8)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", room.cx, room.cy, 28)
        love.graphics.setLineWidth(1)
    end
end

return Dungeon
