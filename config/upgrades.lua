--[[
    config/upgrades.lua
    升级奖励配置表，定义所有可选的升级奖励内容
    结构：大类 -> 子选项列表
    新增奖励只需在此添加配置，无需修改逻辑代码
]]

local UpgradeConfig = {

    -- 大类定义（显示顺序和标签）
    categories = {
        { id = "weapon",  labelKey = "cat.weapon", color = {1.0, 0.6, 0.2} },
        { id = "stat",    labelKey = "cat.stat",   color = {0.2, 0.8, 1.0} },
        { id = "skill",   labelKey = "cat.skill",  color = {0.7, 0.3, 1.0} },
    },

    -- 武器相关子选项
    weapon = {
        {
            id       = "weapon_new_basic",
            labelKey = "opt.weapon_new_basic.label",
            descKey  = "opt.weapon_new_basic.desc",
            -- apply 由 upgrade.lua 根据 onWeaponDrop 回调调用
            -- 此处 apply 随机选一把武器并触发回调
            apply    = function(player, ctx)
                local WeaponConfig = require("config.weapons")
                local Weapon       = require("src.entities.weapon")
                local Log          = require("src.utils.log")

                local bag   = player:getBag()

                -- 收集玩家背包中已有的武器 configId
                local owned = {}
                for _, w in ipairs(bag:getAllWeapons()) do
                    owned[w.configId] = true
                end

                -- 候选池：优先未拥有；全有时所有武器都候选
                -- Bug#2：过滤掉融合结果武器（isFused=true）
                local pool = {}
                for id, cfg in pairs(WeaponConfig) do
                    if not cfg.isFused and not owned[id] then table.insert(pool, id) end
                end
                if #pool == 0 then
                    for id, cfg in pairs(WeaponConfig) do
                        if not cfg.isFused then table.insert(pool, id) end
                    end
                end

                -- 从候选池中筛选当前背包放得下的武器
                local fittable = {}
                for _, id in ipairs(pool) do
                    local w = Weapon.new(id)
                    if bag:hasSpace(w) then
                        table.insert(fittable, id)
                    end
                end

                -- 若背包全放不下，先扩展一次再筛
                if #fittable == 0 then
                    bag:expand(1, 1)
                    Log.info("背包已满，自动扩展至 " .. bag.cols .. "x" .. bag.rows)
                    for _, id in ipairs(pool) do
                        local w = Weapon.new(id)
                        if bag:hasSpace(w) then
                            table.insert(fittable, id)
                        end
                    end
                end

                -- 仍放不下（背包已达上限）则直接结束
                if #fittable == 0 then
                    Log.info("背包已达上限，无法获得新武器")
                    return
                end

                local pick   = fittable[math.random(#fittable)]
                local weapon = Weapon.new(pick)
                Log.info("获得新武器: " .. pick)

                if ctx and ctx.onWeaponDrop then
                    ctx.onWeaponDrop(weapon, ctx.onDone)
                    return true
                end
            end,
        },
        {
            id       = "weapon_upgrade",
            labelKey = "opt.weapon_upgrade.label",
            descKey  = "opt.weapon_upgrade.desc",
            -- 弹出背包 SELECT 模式，让玩家选一把未满级武器升级
            apply    = function(player, ctx)
                local Log = require("src.utils.log")
                local bag = player:getBag()
                local weapons = bag:getAllWeapons()

                -- 检查是否有可升级武器
                local hasUpgradeable = false
                for _, w in ipairs(weapons) do
                    if w.level < w.maxLevel then
                        hasUpgradeable = true
                        break
                    end
                end

                if not hasUpgradeable then
                    Log.info("没有可升级的武器（全部已满级）")
                    return  -- 直接结束，upgrade.lua 调用 onDone
                end

                if ctx and ctx.onWeaponDrop then
                    -- 复用 onWeaponDrop 通道推入 bagUI SELECT 模式
                    -- 传入特殊标记让 game.lua 的 onWeaponDrop 知道这是 select 场景
                    ctx.onWeaponDrop("__select__", ctx.onDone, {
                        filter = function(w) return w.level < w.maxLevel end,
                        hint   = T("bag.hint.select_upgrade"),
                        onSelect = function(w)
                            if w then
                                w:levelUp()
                                Log.info("武器升级: " .. w.configId .. " -> Lv" .. w.level)
                            end
                        end,
                    })
                    return true
                end
            end,
        },
        {
            id       = "weapon_bag_expand",
            labelKey = "opt.weapon_bag_expand.label",
            descKey  = "opt.weapon_bag_expand.desc",
            -- 背包已达上限时不显示此选项
            canShow  = function(player)
                local Bag = require("src.systems.bag")
                local maxR, maxC = Bag.getMaxSize()
                local bag = player:getBag()
                return bag.rows < maxR or bag.cols < maxC
            end,
            apply    = function(player, ctx)
                local Log = require("src.utils.log")
                local bag = player:getBag()
                local r, c = bag:expand(1, 1)
                Log.info("背包扩展至 " .. c .. "x" .. r)
            end,
        },
    },

    -- 属性相关子选项
    stat = {
        {
            id       = "stat_hp",
            labelKey = "opt.stat_hp.label",
            descKey  = "opt.stat_hp.desc",
            apply    = function(player)
                player.maxHp = player.maxHp + 30
                player.hp    = math.min(player.hp + 30, player.maxHp)
            end,
        },
        {
            id       = "stat_speed",
            labelKey = "opt.stat_speed.label",
            descKey  = "opt.stat_speed.desc",
            apply    = function(player)
                player.speed = player.speed + 20
            end,
        },
        {
            id       = "stat_attack",
            labelKey = "opt.stat_attack.label",
            descKey  = "opt.stat_attack.desc",
            apply    = function(player)
                player.attack = player.attack + 10
            end,
        },
        {
            id       = "stat_pickup",
            labelKey = "opt.stat_pickup.label",
            descKey  = "opt.stat_pickup.desc",
            apply    = function(player)
                player.pickupRadius = player.pickupRadius + 30
            end,
        },
        {
            id       = "stat_crit",
            labelKey = "opt.stat_crit.label",
            descKey  = "opt.stat_crit.desc",
            apply    = function(player)
                player.critRate   = math.min(player.critRate + 0.05, 0.95)
                player.critDamage = player.critDamage + 0.2
            end,
        },
        {
            id       = "stat_exp",
            labelKey = "opt.stat_exp.label",
            descKey  = "opt.stat_exp.desc",
            apply    = function(player)
                player.expBonus = player.expBonus + 0.2
            end,
        },
    },

    -- 技能相关子选项
    skill = {
        {
            id       = "skill_get",
            labelKey = "opt.skill_get.label",
            descKey  = "opt.skill_get.desc",
            -- canShow：技能池中有可获得/可升级的技能时才显示
            canShow  = function(player)
                local SkillConfig = require("config.skills")
                local sm = player:getSkillManager()
                for id, cfg in pairs(SkillConfig) do
                    -- 角色匹配检查
                    if not cfg.characterId or player.characterId == cfg.characterId then
                        local lv = sm:getLevel(id)
                        if lv < (cfg.maxLevel or 1) then
                            return true
                        end
                    end
                end
                return false
            end,
            apply = function(player, ctx)
                local SkillConfig  = require("config.skills")
                local sm           = player:getSkillManager()
                local Log          = require("src.utils.log")

                -- 构建候选池：优先未拥有，其次可升级，满足角色限制
                local notOwned = {}
                local upgradeable = {}
                for id, cfg in pairs(SkillConfig) do
                    if not cfg.characterId or player.characterId == cfg.characterId then
                        local lv = sm:getLevel(id)
                        if lv == 0 then
                            table.insert(notOwned, id)
                        elseif lv < (cfg.maxLevel or 1) then
                            table.insert(upgradeable, id)
                        end
                    end
                end

                -- 随机打乱
                local function shuffle(t)
                    for i = #t, 2, -1 do
                        local j = math.random(i)
                        t[i], t[j] = t[j], t[i]
                    end
                end
                shuffle(notOwned)
                shuffle(upgradeable)

                -- 合并候选：最多取 3 个
                local candidates = {}
                for _, id in ipairs(notOwned) do
                    if #candidates >= 3 then break end
                    table.insert(candidates, id)
                end
                for _, id in ipairs(upgradeable) do
                    if #candidates >= 3 then break end
                    table.insert(candidates, id)
                end

                if #candidates == 0 then
                    Log.info("技能池已空，无可选技能")
                    return  -- 直接返回，upgrade.lua 会调用 onDone
                end

                -- 推入技能选择 UI
                if ctx and ctx.onWeaponDrop then
                    -- 复用 deferred 机制：告知 upgrade.lua 流程由 skillSelectUI 接管
                    local StateManager = require("src.states.stateManager")
                    StateManager.push("skillSelectUI", {
                        player     = player,
                        candidates = candidates,
                        onSelect   = function(skillId)
                            local ok = sm:add(skillId, player)
                            if ok then
                                Log.info("获得/升级技能: " .. skillId .. " Lv" .. sm:getLevel(skillId))
                            end
                            StateManager.pop()           -- pop skillSelectUI
                            if ctx.onDone then ctx.onDone() end  -- pop upgrade
                        end,
                        onCancel = function()
                            StateManager.pop()           -- pop skillSelectUI
                            if ctx.onDone then ctx.onDone() end
                        end,
                    })
                    return true   -- deferred
                end
            end,
        },
    },
}

return UpgradeConfig
