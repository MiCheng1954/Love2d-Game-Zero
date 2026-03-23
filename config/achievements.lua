--[[
    config/achievements.lua
    成就配置表 — Phase 13
    预留空壳结构，后续在此添加成就定义即可

    每个成就结构：
    {
        id        = "ach_xxx",
        nameKey   = "ach.xxx.name",
        descKey   = "ach.xxx.desc",
        icon      = "★",          -- 简单 emoji/符号作为图标
        event     = "event_name", -- 监听的游戏事件
        condition = function(data, progress) ... end,  -- 返回 true 时解锁
    }
]]

local AchievementConfig = {
    -- 示例（已注释，后续取消注释或添加新成就）
    --[[
    {
        id        = "ach_first_kill",
        nameKey   = "ach.first_kill.name",
        descKey   = "ach.first_kill.desc",
        icon      = "⚔",
        event     = "enemy_killed",
        condition = function(data, progress) return true end,
    },
    ]]
}

return AchievementConfig
