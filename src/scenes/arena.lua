--[[
    src/scenes/arena.lua
    封闭竞技场场景 — Phase 12
    固定边界 2560×1440，边界靠近时受到环境伤害
    敌人从四面墙壁随机点生成，节奏更紧凑
    专属 Boss：冲锋者，灵魂掉落 ×1.3
]]

local BaseScene   = require("src.scenes.baseScene")
local SceneConfig = require("config.scenes")

local Arena = setmetatable({}, { __index = BaseScene })
Arena.__index = Arena

-- 边界区域参数
local BORDER_WARN  = 80    -- 警告区宽度（px），此范围内开始受伤
local DMG_NEAR     = 5     -- 警告区内缘每秒伤害
local DMG_EDGE     = 25    -- 边缘处每秒最大伤害

function Arena.new()
    local self = BaseScene.new(SceneConfig.arena)
    return setmetatable(self, Arena)
end

-- ============================================================
-- 生命周期
-- ============================================================

function Arena:onEnter(player)
    -- 向 Spawner 注册自定义生成点函数（由 game.lua 在 enter 后调用 setSpawnOverride）
    -- 这里存储函数供 game.lua 通过 getSpawnOverride() 取走
    local bounds = self._cfg.bounds  -- {x, y, w, h}
    self._spawnOverrideFn = function(target)
        -- 从四面墙壁随机选一面，沿该面随机取一个点（在边界内侧 20px 处）
        local side = math.random(4)  -- 1=上 2=下 3=左 4=右
        local bx, by, bw, bh = bounds.x, bounds.y, bounds.w, bounds.h
        local margin = 20
        if side == 1 then      -- 上墙
            return bx + math.random() * bw, by + margin
        elseif side == 2 then  -- 下墙
            return bx + math.random() * bw, by + bh - margin
        elseif side == 3 then  -- 左墙
            return bx + margin, by + math.random() * bh
        else                   -- 右墙
            return bx + bw - margin, by + math.random() * bh
        end
    end
end

function Arena:onExit()
    self._spawnOverrideFn = nil
end

-- 覆盖 getSpawnOverride，返回自定义生成函数（供 game.lua 传给 Spawner）
function Arena:getSpawnOverride()
    return self._spawnOverrideFn
end

-- ============================================================
-- 更新：边界环境伤害
-- ============================================================

function Arena:update(dt, player)
    if not player or player:isDead() then return end

    local bounds = self._cfg.bounds
    if not bounds then return end

    -- 计算玩家到最近边界的距离
    local px, py = player.x, player.y
    local bx, by, bw, bh = bounds.x, bounds.y, bounds.w, bounds.h

    local distLeft   = px - bx
    local distRight  = (bx + bw) - px
    local distTop    = py - by
    local distBottom = (by + bh) - py

    local minDist = math.min(distLeft, distRight, distTop, distBottom)

    -- Bug#46：每帧线性掉血（不再用计时器间隔）
    -- Bug#45：使用 math.floor 避免血量出现小数
    if minDist < BORDER_WARN then
        local ratio     = math.max(0, 1 - minDist / BORDER_WARN)
        local dmgPerSec = DMG_NEAR + (DMG_EDGE - DMG_NEAR) * ratio
        local dmg       = dmgPerSec * dt
        player.hp = math.max(0, player.hp - dmg)
        player.hp = math.floor(player.hp)  -- 整数化，防止小数累积
    end
end

-- ============================================================
-- 绘制
-- ============================================================

function Arena:draw(camera)
    local bounds = self._cfg.bounds
    local bx, by, bw, bh = bounds.x, bounds.y, bounds.w, bounds.h

    -- 地面（深灰砖块感）
    love.graphics.setColor(0.10, 0.10, 0.12)
    love.graphics.rectangle("fill", bx, by, bw, bh)

    -- 地面网格线
    love.graphics.setColor(0.14, 0.14, 0.17)
    local gridSize = 80
    for x = bx, bx + bw, gridSize do
        love.graphics.line(x, by, x, by + bh)
    end
    for y = by, by + bh, gridSize do
        love.graphics.line(bx, y, bx + bw, y)
    end

    -- 边界警告区（Bug#52：四条边带全部使用完整宽/高，角落自然重叠，边边相连）
    local layers = 6
    for i = layers, 1, -1 do
        local t     = i / layers
        local depth = BORDER_WARN * t
        local alpha = 0.04 + 0.16 * (1 - t)
        love.graphics.setColor(0.9, 0.15, 0.1, alpha)
        -- 上边带（完整宽度，含两侧角落）
        love.graphics.rectangle("fill", bx, by, bw, depth)
        -- 下边带
        love.graphics.rectangle("fill", bx, by + bh - depth, bw, depth)
        -- 左边带（完整高度，含上下角落）
        love.graphics.rectangle("fill", bx, by, depth, bh)
        -- 右边带
        love.graphics.rectangle("fill", bx + bw - depth, by, depth, bh)
    end

    -- 墙壁（厚实边框）
    love.graphics.setColor(0.25, 0.22, 0.20)
    local wallT = 24  -- 墙壁厚度
    love.graphics.rectangle("fill", bx - wallT, by - wallT, bw + wallT * 2, wallT)  -- 上
    love.graphics.rectangle("fill", bx - wallT, by + bh, bw + wallT * 2, wallT)     -- 下
    love.graphics.rectangle("fill", bx - wallT, by, wallT, bh)                       -- 左
    love.graphics.rectangle("fill", bx + bw, by, wallT, bh)                          -- 右

    -- 墙壁内侧亮边（金属感）
    love.graphics.setColor(0.4, 0.35, 0.30, 0.8)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", bx, by, bw, bh)
    love.graphics.setLineWidth(1)

    love.graphics.setColor(1, 1, 1, 1)
end

return Arena
