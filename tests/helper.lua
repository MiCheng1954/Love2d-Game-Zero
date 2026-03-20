--[[
    tests/helper.lua
    测试辅助：统一设置 package.path，注入 Love2D stub，提供公共工具函数。
    每个测试文件顶部 require("tests.helper") 即可。
]]

-- 将项目根目录加入 Lua 模块搜索路径
local root = (debug.getinfo(1, "S").source:match("^@(.+)tests") or "./")
package.path = root .. "?.lua;" .. root .. "?/init.lua;" .. package.path

-- 注入 Love2D stub（必须在任何游戏模块 require 之前）
require("tests.mock.love")

-- 全局 T()（i18n 函数 stub，直接返回 key）
T = T or function(key, ...) return key end

local Helper = {}

-- 构造一个最小 Bag，rows×cols 并可选择是否跳过 Adjacency/Synergy 重算
-- @param rows, cols: 背包大小（默认 4×4）
function Helper.newBag(rows, cols)
    local Bag = require("src.systems.bag")
    return Bag.new(rows or 4, cols or 4)
end

-- 构造一把武器实例
-- @param configId: 武器 ID 字符串
function Helper.newWeapon(configId)
    local Weapon = require("src.entities.weapon")
    return Weapon.new(configId)
end

return Helper
