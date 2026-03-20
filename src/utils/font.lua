--[[
    src/utils/font.lua
    字体管理器，按需缓存不同尺寸的 Love2D 字体对象
    Phase 5.1：支持中文显示（文泉驿微米黑）
]]

local Font = {}

-- 字体文件路径（相对于游戏根目录）
local FONT_PATH = "assets/fonts/wqy-microhei.ttc"

-- 内部缓存，key 为字体大小（整数），value 为 love.Font 对象
local _cache = {}

-- 获取指定大小的字体对象（懒加载缓存）
-- @param size: 字体大小（整数）
-- @return love.Font 对象
function Font.get(size)
    if not _cache[size] then
        _cache[size] = love.graphics.newFont(FONT_PATH, size)
    end
    return _cache[size]
end

-- 快捷设置当前字体（相当于 love.graphics.setFont(Font.get(size))）
-- @param size: 字体大小（整数）
function Font.set(size)
    love.graphics.setFont(Font.get(size))
end

-- 恢复 Love2D 默认字体
function Font.reset()
    love.graphics.setFont(love.graphics.newFont())
end

return Font
