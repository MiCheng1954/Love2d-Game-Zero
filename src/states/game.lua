--[[
    src/states/game.lua
    游戏主状态，局内核心玩法的入口
    Phase 2：接入输入系统、玩家、摄像机
]]

local Timer  = require("src.utils.timer")
local Input  = require("src.systems.input")
local Camera = require("src.systems.camera")
local Player = require("src.entities.player")

local Game = {}

-- 玩家实例
local _player = nil

-- 摄像机实例
local _camera = nil

-- 进入游戏状态时调用，负责初始化所有局内数据
function Game:enter()
    Timer.clear()

    -- 初始化玩家，出生在世界中心
    _player = Player.new(0, 0)

    -- 初始化摄像机，跟随玩家
    _camera = Camera.new(1280, 720)
    _camera:setTarget(_player)
end

-- 退出游戏状态时调用
function Game:exit()
    Timer.clear()
    _player = nil
    _camera = nil
end

-- 每帧更新游戏逻辑
-- @param dt: 距上一帧的时间间隔（秒）
function Game:update(dt)
    Input.update()
    Timer.update(dt)

    _player:update(dt)
    _camera:update(dt)

    -- 呼出背包（TAB），Phase 6 接入
    if Input.isPressed("openBag") then
        -- TODO: Phase 6 接入背包系统
    end

    -- 返回菜单（ESC）
    if Input.isPressed("cancel") then
        local StateManager = require("src.states.stateManager")
        StateManager.switch("menu")
    end
end

-- 每帧绘制游戏画面
function Game:draw()
    love.graphics.setBackgroundColor(0.05, 0.05, 0.08)

    -- == 世界层（摄像机坐标系）==
    _camera:attach()

    -- 绘制背景参考网格（占位，Phase 12 替换为真实地图）
    Game._drawGrid()

    -- 绘制玩家
    _player:draw()

    _camera:detach()

    -- == UI 层（屏幕坐标系）==
    Game._drawHUD()
end

-- 绘制背景参考网格
function Game._drawGrid()
    local gridSize  = 64   -- 格子大小（像素）
    local gridRange = 20   -- 绘制范围（格子数）

    love.graphics.setColor(0.15, 0.15, 0.2)
    for i = -gridRange, gridRange do
        -- 竖线
        love.graphics.line(
            i * gridSize, -gridRange * gridSize,
            i * gridSize,  gridRange * gridSize)
        -- 横线
        love.graphics.line(
            -gridRange * gridSize, i * gridSize,
             gridRange * gridSize, i * gridSize)
    end

    -- 原点标记
    love.graphics.setColor(0.3, 0.3, 0.4)
    love.graphics.circle("fill", 0, 0, 4)
end

-- 绘制局内 HUD（屏幕坐标系，不受摄像机影响）
function Game._drawHUD()
    -- HP 条背景
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", 20, 20, 200, 16)

    -- HP 条前景
    local hpRatio = _player.hp / _player.maxHp
    love.graphics.setColor(0.8, 0.2, 0.2)
    love.graphics.rectangle("fill", 20, 20, 200 * hpRatio, 16)

    -- HP 条边框
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.rectangle("line", 20, 20, 200, 16)

    -- HP 文字
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("HP " .. _player.hp .. " / " .. _player.maxHp, 24, 22)

    -- 经验条背景
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", 20, 42, 200, 10)

    -- 经验条前景
    love.graphics.setColor(0.2, 0.8, 0.4)
    love.graphics.rectangle("fill", 20, 42, 200 * _player:getExpProgress(), 10)

    -- 等级与灵魂数量
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Lv." .. _player:getLevel(), 20, 58)
    love.graphics.print("灵魂: " .. _player:getSouls(), 20, 76)

    -- 操作提示
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.print("WASD 移动  |  ESC 返回菜单", 20, 695)
end

-- 键盘按下事件（单次触发类操作）
-- @param key: 按下的键名
function Game:keypressed(key)
end

return Game
