--[[
    tests/mock/love.lua
    Love2D API 的最小 stub，让测试代码无需图形环境即可 require 游戏模块。

    用法：在每个测试文件顶部 require 此 stub 之前，busted 的 _G 就已经有 love 了。
    tests/helper.lua 会统一注入，无需每个测试文件单独 require。
]]

-- 全局 love 命名空间
love = love or {}

-- love.graphics（所有绘图调用变为 no-op）
love.graphics = setmetatable({}, {
    __index = function(_, key)
        return function() end  -- 任何未定义的方法返回空函数
    end
})

-- love.timer
love.timer = {
    getFPS  = function() return 60 end,
    getTime = function() return 0 end,
    getDelta= function() return 0.016 end,
}

-- love.keyboard
love.keyboard = {
    isDown = function() return false end,
}

-- love.window（conf.lua 可能用到）
love.window = {
    setTitle = function() end,
    setMode  = function() end,
}

-- love.filesystem
love.filesystem = {
    getInfo  = function() return nil end,
    read     = function() return nil end,
    write    = function() return true end,
    getSaveDirectory = function() return "/tmp" end,
}

-- love.math
love.math = {
    random      = math.random,
    randomseed  = math.randomseed,
    newRandomGenerator = function() return { random = math.random } end,
}

-- love.audio（静音 stub）
love.audio = setmetatable({}, {
    __index = function() return function() end end
})
