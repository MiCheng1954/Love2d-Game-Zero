--[[
    src/systems/sceneManager.lua
    场景管理器 — Phase 12
    负责场景的注册、切换与当前场景的持有
    game.lua 通过 SceneManager.get() 获取当前场景实例
]]

local SceneManager = {}

local _scenes  = {}         -- 注册表：id → scene 实例
local _current = nil        -- 当前场景实例
local _currentId = nil      -- 当前场景 id 字符串

-- 注册场景
-- @param id:    场景 id 字符串（对应 config/scenes.lua 的 key）
-- @param scene: BaseScene 子类实例
function SceneManager.register(id, scene)
    _scenes[id] = scene
end

-- 切换当前场景（只切换引用，不自动调 onEnter/onExit，由 game.lua 控制时机）
-- @param id: 场景 id 字符串
function SceneManager.set(id)
    local scene = _scenes[id]
    if not scene then
        error("SceneManager: 未注册的场景 id = " .. tostring(id))
    end
    _current   = scene
    _currentId = id
end

-- 返回当前场景实例（未设置时返回 nil）
function SceneManager.get()
    return _current
end

-- 返回当前场景 id 字符串（未设置时返回 nil）
function SceneManager.current()
    return _currentId
end

-- 调用当前场景的 onEnter（由 game.lua enter() 末尾调用）
-- @param player: 玩家实例
function SceneManager.enter(player)
    if _current then
        _current:onEnter(player)
    end
end

-- 调用当前场景的 onExit（由 game.lua exit() 前调用）
function SceneManager.exit()
    if _current then
        _current:onExit()
    end
end

return SceneManager
