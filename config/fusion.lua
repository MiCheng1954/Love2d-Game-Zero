--[[
    config/fusion.lua
    武器融合配方表
    Phase 7.1：武器融合

    结构说明：
        ingredients — 两把原材料武器的 configId（无序匹配，A+B 等同于 B+A）
        result      — 融合结果武器的 configId（需在 config/weapons.lua 中定义）
]]

return {
    {
        ingredients = { "pistol", "smg" },
        result      = "dual_pistol",
    },
    {
        ingredients = { "shotgun", "cannon" },
        result      = "siege_cannon",
    },
    {
        ingredients = { "sniper", "laser" },
        result      = "railgun",
    },
}
