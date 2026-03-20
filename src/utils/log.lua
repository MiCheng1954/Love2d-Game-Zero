--[[
    src/utils/log.lua
    游戏运行日志系统，将关键事件写入 data/game.log
    Phase 5.1：开发基础设施
    使用 io.open() 写入项目源目录，不依赖 love.filesystem 沙箱
]]

local Log = {}

-- 日志文件句柄
local _file    = nil
-- 项目源目录（由 Log.init() 传入）
local _dataDir = nil
-- 当前日志文件完整路径
local _logPath = nil

-- 初始化日志系统
-- @param sourceDir: 项目源目录路径（来自 love.filesystem.getSource()）
function Log.init(sourceDir)
    _dataDir = sourceDir .. "/data"

    -- 创建 data/ 和 data/logs/ 目录（跨平台）
    os.execute('mkdir "' .. _dataDir:gsub("/", "\\") .. '" 2>nul')
    os.execute('mkdir "' .. _dataDir:gsub("/", "\\") .. '\\logs" 2>nul')

    _logPath = _dataDir .. "/game.log"
    _file = io.open(_logPath, "a")

    if _file then
        _file:write(string.format(
            "\n============================\n[SESSION START] %s\n============================\n",
            os.date("%Y-%m-%d %H:%M:%S")
        ))
        _file:flush()
    end
end

-- 写入一行日志
-- @param level: 日志级别字符串（INFO/WARN/ERROR/EVENT）
-- @param msg:   日志内容
function Log.write(level, msg)
    if not _file then return end
    local line = string.format("[%s][%s] %s\n", os.date("%H:%M:%S"), level, msg)
    _file:write(line)
    _file:flush()
end

-- 快捷方法
function Log.info(msg)  Log.write("INFO",  msg) end
function Log.warn(msg)  Log.write("WARN",  msg) end
function Log.error(msg) Log.write("ERROR", msg) end
function Log.event(msg) Log.write("EVENT", msg) end

-- 返回 data/ 目录路径
function Log.getDataDir() return _dataDir end

-- 返回当前 game.log 完整路径
function Log.getLogPath() return _logPath end

-- 将当前 game.log 快照复制到 data/logs/bug_<id>_<timestamp>.log
-- 返回相对于 data/ 的快照路径（用于 bugs.json 索引）
-- @param bugId: Bug ID
function Log.snapshotForBug(bugId)
    if not _logPath or not _dataDir then return nil end

    local snapName = string.format("logs/bug_%d_%s.log",
        bugId, os.date("%Y%m%d_%H%M%S"))
    local snapPath = _dataDir .. "/" .. snapName

    -- 读取当前日志内容并写入快照
    local src = io.open(_logPath, "r")
    if not src then return nil end
    local content = src:read("*a")
    src:close()

    local dst = io.open(snapPath, "w")
    if not dst then return nil end
    dst:write(content)
    dst:write(string.format(
        "\n--- [BUG #%d 快照时间 %s] ---\n",
        bugId, os.date("%Y-%m-%d %H:%M:%S")
    ))
    dst:close()

    return snapName
end

-- 关闭日志（游戏退出时调用）
function Log.close()
    if _file then
        _file:write(string.format(
            "[SESSION END] %s\n============================\n",
            os.date("%Y-%m-%d %H:%M:%S")
        ))
        _file:close()
        _file = nil
    end
end

return Log
