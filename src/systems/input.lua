--[[
    src/systems/input.lua
    输入系统抽象层，统一封装所有输入来源
    目前支持键盘（WASD），预留手柄和鼠标接口
    所有游戏逻辑只与此模块交互，不直接调用 love.keyboard
]]

local Input = {}

-- 当前帧的输入状态表
-- key: 动作名称，value: 是否激活
local _actions = {
    moveUp       = false,  -- 向上移动
    moveDown     = false,  -- 向下移动
    moveLeft     = false,  -- 向左移动
    moveRight    = false,  -- 向右移动
    openBag      = false,  -- 呼出背包（TAB）
    confirm      = false,  -- 确认（Enter）
    cancel       = false,  -- 取消（ESC）
    rotateWeapon = false,  -- 旋转武器（背包放置模式 R 键）
    pause        = false,  -- 暂停/继续（P 键）
}

-- 上一帧的输入状态（用于检测单次按下）
local _prevActions = {}

-- 键盘按键到动作的映射表
local _keyboardMap = {
    w          = "moveUp",
    s          = "moveDown",
    a          = "moveLeft",
    d          = "moveRight",
    up         = "moveUp",
    down       = "moveDown",
    left       = "moveLeft",
    right      = "moveRight",
    tab        = "openBag",
    ["return"] = "confirm",
    escape     = "cancel",
    r          = "rotateWeapon",
    p          = "pause",
}

-- 每帧更新输入状态，需在 love.update() 中调用
function Input.update()
    -- 保存上一帧状态
    for action, _ in pairs(_actions) do
        _prevActions[action] = _actions[action]
    end

    -- 重置所有动作状态
    for action, _ in pairs(_actions) do
        _actions[action] = false
    end

    -- 读取键盘输入
    Input._updateKeyboard()

    -- 预留：读取手柄输入
    -- Input._updateGamepad()

    -- 预留：读取鼠标输入
    -- Input._updateMouse()
end

-- 读取键盘输入，映射到动作
function Input._updateKeyboard()
    for key, action in pairs(_keyboardMap) do
        if love.keyboard.isDown(key) then
            _actions[action] = true
        end
    end
end

-- 查询某个动作是否正在持续按下
-- @param action: 动作名称（字符串）
-- @return 是否持续按下（boolean）
function Input.isDown(action)
    return _actions[action] == true
end

-- 查询某个动作是否在本帧刚刚按下（单次触发）
-- @param action: 动作名称（字符串）
-- @return 是否刚刚按下（boolean）
function Input.isPressed(action)
    return _actions[action] == true and _prevActions[action] ~= true
end

-- 查询某个动作是否在本帧刚刚释放（单次触发）
-- @param action: 动作名称（字符串）
-- @return 是否刚刚释放（boolean）
function Input.isReleased(action)
    return _actions[action] ~= true and _prevActions[action] == true
end

-- 获取归一化的移动方向向量
-- @return dx, dy：范围 -1 到 1 的方向分量
function Input.getMoveDirection()
    local dx = 0  -- 水平方向分量
    local dy = 0  -- 垂直方向分量

    if Input.isDown("moveLeft")  then dx = dx - 1 end
    if Input.isDown("moveRight") then dx = dx + 1 end
    if Input.isDown("moveUp")    then dy = dy - 1 end
    if Input.isDown("moveDown")  then dy = dy + 1 end

    -- 斜向移动归一化，避免速度叠加
    if dx ~= 0 and dy ~= 0 then
        local len = math.sqrt(dx * dx + dy * dy)
        dx = dx / len
        dy = dy / len
    end

    return dx, dy
end

return Input
