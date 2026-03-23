--[[
    config/progressionTree.lua
    通用机制树节点配置 — Phase 13
    5维度 × 3层 = 15节点，所有角色共用，消耗通用成长点数解锁
]]

local ProgressionTreeConfig = {

    -- ══════════════════════════════════════
    -- 攻击维度（attack）
    -- ══════════════════════════════════════
    {
        id       = "tree_atk_1",
        nameKey  = "tree.atk_1.name",
        descKey  = "tree.atk_1.desc",
        cost     = 8,
        requires = {},
        dim      = "attack",
        layer    = 1,
        effect   = function(player)
            player.critRate = (player.critRate or 0) + 0.03
        end,
    },
    {
        id       = "tree_atk_2",
        nameKey  = "tree.atk_2.name",
        descKey  = "tree.atk_2.desc",
        cost     = 12,
        requires = { "tree_atk_1" },
        dim      = "attack",
        layer    = 2,
        effect   = function(player)
            player.critDamage = (player.critDamage or 0) + 0.2
        end,
    },
    {
        id       = "tree_atk_3",
        nameKey  = "tree.atk_3.name",
        descKey  = "tree.atk_3.desc",
        cost     = 18,
        requires = { "tree_atk_2" },
        dim      = "attack",
        layer    = 3,
        effect   = function(player)
            player._tree_killHeal = (player._tree_killHeal or 0) + 1
        end,
    },

    -- ══════════════════════════════════════
    -- 生存维度（survive）
    -- ══════════════════════════════════════
    {
        id       = "tree_sur_1",
        nameKey  = "tree.sur_1.name",
        descKey  = "tree.sur_1.desc",
        cost     = 8,
        requires = {},
        dim      = "survive",
        layer    = 1,
        effect   = function(player)
            player.maxHp = (player.maxHp or 0) + 20
            player.hp    = (player.hp    or 0) + 20
        end,
    },
    {
        id       = "tree_sur_2",
        nameKey  = "tree.sur_2.name",
        descKey  = "tree.sur_2.desc",
        cost     = 12,
        requires = { "tree_sur_1" },
        dim      = "survive",
        layer    = 2,
        effect   = function(player)
            player._tree_injuredSpeed = true
        end,
    },
    {
        id       = "tree_sur_3",
        nameKey  = "tree.sur_3.name",
        descKey  = "tree.sur_3.desc",
        cost     = 20,
        requires = { "tree_sur_2" },
        dim      = "survive",
        layer    = 3,
        effect   = function(player)
            player._tree_deathShield = true
        end,
    },

    -- ══════════════════════════════════════
    -- 经济维度（economy）
    -- ══════════════════════════════════════
    {
        id       = "tree_eco_1",
        nameKey  = "tree.eco_1.name",
        descKey  = "tree.eco_1.desc",
        cost     = 6,
        requires = {},
        dim      = "economy",
        layer    = 1,
        effect   = function(player)
            player._progressionExpBonus = (player._progressionExpBonus or 0) + 15
        end,
    },
    {
        id       = "tree_eco_2",
        nameKey  = "tree.eco_2.name",
        descKey  = "tree.eco_2.desc",
        cost     = 10,
        requires = { "tree_eco_1" },
        dim      = "economy",
        layer    = 2,
        effect   = function(player)
            player._tree_soulBonus = (player._tree_soulBonus or 0) + 0.25
        end,
    },
    {
        id       = "tree_eco_3",
        nameKey  = "tree.eco_3.name",
        descKey  = "tree.eco_3.desc",
        cost     = 15,
        requires = { "tree_eco_2" },
        dim      = "economy",
        layer    = 3,
        effect   = function(player)
            player._tree_pointBonus = (player._tree_pointBonus or 0) + 0.2
        end,
    },

    -- ══════════════════════════════════════
    -- 武器装备维度（weapon）
    -- ══════════════════════════════════════
    {
        id       = "tree_wpn_1",
        nameKey  = "tree.wpn_1.name",
        descKey  = "tree.wpn_1.desc",
        cost     = 8,
        requires = {},
        dim      = "weapon",
        layer    = 1,
        effect   = function(player)
            player._tree_weaponFireRate = (player._tree_weaponFireRate or 0) + 0.1
        end,
    },
    {
        id       = "tree_wpn_2",
        nameKey  = "tree.wpn_2.name",
        descKey  = "tree.wpn_2.desc",
        cost     = 12,
        requires = { "tree_wpn_1" },
        dim      = "weapon",
        layer    = 2,
        effect   = function(player)
            player._tree_bulletSpeed = (player._tree_bulletSpeed or 0) + 0.15
        end,
    },
    {
        id       = "tree_wpn_3",
        nameKey  = "tree.wpn_3.name",
        descKey  = "tree.wpn_3.desc",
        cost     = 18,
        requires = { "tree_wpn_2" },
        dim      = "weapon",
        layer    = 3,
        effect   = function(player)
            player._tree_fusedDmg = (player._tree_fusedDmg or 0) + 0.2
        end,
    },

    -- ══════════════════════════════════════
    -- 技能维度（skill）
    -- ══════════════════════════════════════
    {
        id       = "tree_ski_1",
        nameKey  = "tree.ski_1.name",
        descKey  = "tree.ski_1.desc",
        cost     = 8,
        requires = {},
        dim      = "skill",
        layer    = 1,
        effect   = function(player)
            player._tree_skillCdReduce = (player._tree_skillCdReduce or 0) + 0.1
        end,
    },
    {
        id       = "tree_ski_2",
        nameKey  = "tree.ski_2.name",
        descKey  = "tree.ski_2.desc",
        cost     = 12,
        requires = { "tree_ski_1" },
        dim      = "skill",
        layer    = 2,
        effect   = function(player)
            player._tree_skillDuration = (player._tree_skillDuration or 0) + 0.2
        end,
    },
    {
        id       = "tree_ski_3",
        nameKey  = "tree.ski_3.name",
        descKey  = "tree.ski_3.desc",
        cost     = 20,
        requires = { "tree_ski_2" },
        dim      = "skill",
        layer    = 3,
        effect   = function(player)
            player._tree_skillSlotBonus = true
        end,
    },
}

return ProgressionTreeConfig
