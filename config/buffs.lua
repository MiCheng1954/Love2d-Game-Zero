--[[
    config/buffs.lua
    Buff 定义配置表 — Phase 10.1
    包含所有 timer 型和 stack 型 Buff 的定义：
        onApply(player, params) — Buff 首次激活时调用
        onRemove(player, params, entry) — Buff 到期/主动移除时调用
    color — { r, g, b } 用于 HUD 显示
    nameKey — i18n 键
]]

local BuffDefs = {}

-- ---- Timer 型 Buff ----

-- 无敌帧：受伤免疫
BuffDefs["invincible"] = {
    buffType = "timer",
    nameKey  = "buff.invincible.name",
    color    = { 1.0, 0.85, 0.1 },   -- 金色
    onApply  = nil,
    onRemove = nil,
}

-- 战吼：攻击力 ×2
BuffDefs["battle_cry"] = {
    buffType = "timer",
    nameKey  = "buff.battle_cry.name",
    color    = { 0.9, 0.2, 0.2 },    -- 红色
    onApply  = function(player, params)
        player.attack = player.attack * 2
    end,
    onRemove = function(player, params, entry)
        player.attack = player.attack / 2
    end,
}

-- 狂怒：攻击力 + atkBonus
BuffDefs["rage"] = {
    buffType = "timer",
    nameKey  = "buff.rage.name",
    color    = { 0.95, 0.45, 0.1 },  -- 橙红
    onApply  = function(player, params)
        player.attack = player.attack + (params.atkBonus or 0)
    end,
    onRemove = function(player, params, entry)
        -- 使用 entry.params 确保用实际激活时的参数还原
        local p = entry and entry.params or params
        player.attack = player.attack - (p.atkBonus or 0)
    end,
}

-- 超载：武器射速翻倍（武器×2 在 effect 中执行，onRemove 还原）
BuffDefs["overload"] = {
    buffType = "timer",
    nameKey  = "buff.overload.name",
    color    = { 0.2, 0.9, 0.95 },   -- 青色
    onApply  = nil,   -- 武器翻倍逻辑在 skills.lua effect 中执行（需保证 not has）
    onRemove = function(player, params, entry)
        -- 还原所有 _overloadOrig 保存的武器原始射速
        local bag = (entry and entry.params and entry.params.bag)
                    or (params and params.bag)
                    or player._bag
        if bag then
            for _, w in ipairs(bag:getAllWeapons()) do
                if w._overloadOrig then
                    w.attackSpeed   = w._overloadOrig
                    w._overloadOrig = nil
                end
            end
        end
    end,
}

-- 魔法护盾：吸收下一次伤害
BuffDefs["mana_shield"] = {
    buffType = "timer",
    nameKey  = "buff.mana_shield.name",
    color    = { 0.5, 0.3, 0.95 },   -- 蓝紫
    onApply  = function(player, params)
        player._shieldActive   = true
        player._shieldAbsorbed = false
    end,
    onRemove = function(player, params, entry)
        player._shieldActive   = false
        player._shieldAbsorbed = false
    end,
}

-- 灵魂汲取范围：临时扩大拾取半径
BuffDefs["soul_drain_range"] = {
    buffType = "timer",
    nameKey  = "buff.soul_drain_range.name",
    color    = { 0.3, 0.9, 0.4 },    -- 绿色
    onApply  = function(player, params)
        player.pickupRadius = player.pickupRadius + (params.rangeBonus or 0)
    end,
    onRemove = function(player, params, entry)
        local p = entry and entry.params or params
        player.pickupRadius = player.pickupRadius - (p.rangeBonus or 0)
    end,
}

-- ---- Stack 型 Buff ----

-- 弹药强化：stack 计数，消耗一层后子弹伤害×2
BuffDefs["ammo_supply"] = {
    buffType = "stack",
    nameKey  = "buff.ammo_supply.name",
    color    = { 0.95, 0.85, 0.2 },  -- 黄色
    onApply  = nil,
    onRemove = nil,
}

return BuffDefs
