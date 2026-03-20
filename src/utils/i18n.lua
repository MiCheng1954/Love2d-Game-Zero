--[[
    src/utils/i18n.lua
    多语言访问器，提供全局简写函数 T(key, ...)
    Phase 5.1：i18n 多语言支持基础
]]

local I18n = {}

-- 当前语言标识
local _lang  = "zh"

-- 已加载的语言文本表
local _table = {}

-- 加载指定语言文本表
-- @param lang: 语言代码（如 "zh"）
function I18n.load(lang)
    _lang  = lang or "zh"
    _table = require("config.i18n." .. _lang)
end

-- 获取文本，支持 string.format 参数
-- @param key: 文本 key
-- @param ...: 可选的 string.format 参数
-- @return 格式化后的字符串；找不到 key 时返回 "[key]"
function I18n.get(key, ...)
    local text = _table[key]
    if not text then
        return "[" .. key .. "]"
    end
    local args = {...}
    if #args > 0 then
        return string.format(text, ...)
    end
    return text
end

return I18n
