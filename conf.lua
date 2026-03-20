--[[
    conf.lua
    Love2D 启动配置文件，在 love.load() 之前执行
    用于设置窗口尺寸、标题、版本等基础参数
]]

-- Love2D 配置回调
-- @param t: 配置表，修改其字段来覆盖默认设置
function love.conf(t)
    t.title        = "Zero"          -- 窗口标题
    t.version      = "11.4"          -- 目标 Love2D 版本
    t.window.width  = 1280           -- 窗口宽度（像素）
    t.window.height = 720            -- 窗口高度（像素）
    t.window.resizable = false       -- 是否允许调整窗口大小
    t.window.vsync     = 1           -- 垂直同步（1=开启）
    t.console          = true        -- Windows 下显示控制台（调试用）
end
