--[[
    tests/systems/test_skillManager.lua
    技能管理系统单元测试 — Phase 8
    覆盖：基础操作、主动触发、事件被动（定时/击杀/受伤）、纯被动、角色专属、多技能叠加
]]

require("tests.helper")
local SkillManager = require("src.systems.skillManager")
local BuffManager  = require("src.systems.buffManager")

-- 最小玩家 stub
local function newPlayer(characterId)
    return {
        characterId   = characterId or "default",
        x = 0, y = 0,
        hp = 100, maxHp = 100,
        attack = 10, speed = 300,
        critRate = 0.05, critDamage = 1.5,
        pickupRadius = 80,
        expBonus = 1.0,
        heal = function(self, n)
            self.hp = math.min(self.maxHp, self.hp + n)
        end,
        _bag = nil,
        -- Phase 10.1：BuffManager（技能 effect 通过 _buffManager 管理 Buff 状态）
        _buffManager   = BuffManager.new(),
        -- 护盾相关字段（mana_shield Buff onApply/onRemove 会写入）
        _shieldActive  = false,
        _shieldAbsorbed = false,
    }
end

-- 最小敌人 stub
local function newEnemy(isDead)
    return {
        x = 100, y = 0,
        hp = 100, maxHp = 100,
        _isDead = isDead or false,
        takeDamage = function(self, n)
            self.hp = self.hp - n
            if self.hp <= 0 then self._isDead = true end
        end,
    }
end

describe("SkillManager", function()

    local sm, player, ctx

    before_each(function()
        sm     = SkillManager.new()
        player = newPlayer("default")
        ctx    = { dx = 1, dy = 0, enemies = {}, projectiles = {} }
    end)

    -- ============================================================
    -- 基础操作
    -- ============================================================
    describe("基础操作", function()

        it("add() 新增技能 Lv1", function()
            local ok = sm:add("dash", player)
            assert.is_true(ok)
            assert.equals(1, sm:getLevel("dash"))
            assert.is_true(sm:hasSkill("dash"))
        end)

        it("add() 已有技能升级到 Lv2", function()
            sm:add("dash", player)
            local ok = sm:add("dash", player)
            assert.is_true(ok)
            assert.equals(2, sm:getLevel("dash"))
        end)

        it("add() 满级技能不再升级", function()
            local SkillConfig = require("config.skills")
            local maxLv = SkillConfig["dash"].maxLevel
            for _ = 1, maxLv do sm:add("dash", player) end
            local ok = sm:add("dash", player)
            assert.is_false(ok)
            assert.equals(maxLv, sm:getLevel("dash"))
        end)

        it("hasSkill() 未拥有返回 false", function()
            assert.is_false(sm:hasSkill("dash"))
        end)

        it("getLevel() 未拥有返回 0", function()
            assert.equals(0, sm:getLevel("dash"))
        end)

    end)

    -- ============================================================
    -- 主动技能（按键触发）
    -- ============================================================
    describe("主动技能 tryActivate()", function()

        before_each(function()
            sm:add("dash", player)
        end)

        it("CD 未满不触发（初始 cdTimer 等于 cd 所以就绪，先消耗后再测）", function()
            -- 触发一次，消耗 CD
            sm:tryActivate("skill1", player, ctx, 0)
            -- 立刻再次触发，CD 还未恢复，应返回 false
            local triggered = sm:tryActivate("skill1", player, ctx, 0)
            assert.is_false(triggered)
        end)

        it("初始状态 CD 满，tryActivate 应触发", function()
            local triggered = sm:tryActivate("skill1", player, ctx, 0)
            assert.is_true(triggered)
        end)

        it("触发后 cdTimer 重置为 0（冷却中）", function()
            sm:tryActivate("skill1", player, ctx, 0)
            local ratio = sm:getCooldownRatio("dash", 0)
            -- ratio 应接近 0
            assert.is_true(ratio < 0.1)
        end)

        it("update 推进后 CD 部分恢复", function()
            sm:tryActivate("skill1", player, ctx, 0)
            sm:update(4.0, player, ctx, 0)  -- 等待 4 秒
            local ratio = sm:getCooldownRatio("dash", 0)
            -- dash CD=8s，4 秒后 ratio 应约 0.5
            assert.is_true(ratio > 0.3 and ratio < 0.7)
        end)

        it("CD 缩减（cdReduce=0.5）应使冷却更快", function()
            sm:tryActivate("skill1", player, ctx, 0)
            sm:update(4.0, player, ctx, 0.5)  -- 带 50% 缩减
            local ratio = sm:getCooldownRatio("dash", 0.5)
            -- 有缩减时就绪更快，4 秒应超过 0.5
            assert.is_true(ratio > 0.5)
        end)

    end)

    -- ============================================================
    -- 事件被动：passive_timed
    -- ============================================================
    describe("passive_timed — heal_pulse", function()

        before_each(function()
            sm:add("heal_pulse", player)
            player.hp = 50  -- 设置血量以测试治疗
        end)

        it("时间不足不触发", function()
            sm:update(5.0, player, ctx, 0)
            -- 5 秒 < 15 秒间隔，hp 不变
            assert.equals(50, player.hp)
        end)

        it("时间满后触发治疗，hp 提升", function()
            sm:update(15.0, player, ctx, 0)
            assert.is_true(player.hp > 50)
        end)

        it("触发后计时重置（不连续触发）", function()
            sm:update(15.0, player, ctx, 0)
            local hpAfterFirst = player.hp
            -- 再过 5 秒（不够第二次触发）
            sm:update(5.0, player, ctx, 0)
            assert.equals(hpAfterFirst, player.hp)
        end)

    end)

    -- ============================================================
    -- 事件被动：passive_onkill
    -- ============================================================
    describe("passive_onkill — explosion", function()

        before_each(function()
            sm:add("explosion", player)
            -- 添加3个敌人
            ctx.enemies = { newEnemy(), newEnemy(), newEnemy() }
        end)

        it("击杀不足 5 次不触发爆炸", function()
            for _ = 1, 4 do
                sm:onKill(player, nil, ctx)
            end
            -- 敌人未受到伤害
            for _, e in ipairs(ctx.enemies) do
                assert.equals(100, e.hp)
            end
        end)

        it("第 5 次击杀触发爆炸，敌人受伤", function()
            for _ = 1, 5 do
                sm:onKill(player, nil, ctx)
            end
            -- 至少有一个敌人受伤（在 150px 范围内，newEnemy x=100）
            local anyHurt = false
            for _, e in ipairs(ctx.enemies) do
                if e.hp < 100 then anyHurt = true end
            end
            assert.is_true(anyHurt)
        end)

        it("触发后计数重置，下一次需再积累 5 击", function()
            for _ = 1, 5 do sm:onKill(player, nil, ctx) end
            -- 重置计数后再给 4 次，不触发
            local hpAfter = {}
            for _, e in ipairs(ctx.enemies) do hpAfter[e] = e.hp end
            for _ = 1, 4 do sm:onKill(player, nil, ctx) end
            for _, e in ipairs(ctx.enemies) do
                assert.equals(hpAfter[e], e.hp)
            end
        end)

    end)

    -- ============================================================
    -- 事件被动：passive_onhit
    -- ============================================================
    describe("passive_onhit — rage", function()

        before_each(function()
            sm:add("rage", player)
        end)

        it("首次受伤触发狂怒，攻击力提升", function()
            local atkBefore = player.attack
            sm:onHit(player, 10, ctx)
            assert.is_true(player.attack > atkBefore)
        end)

        it("冷却中（CD=20s）再次受伤不再叠加", function()
            sm:onHit(player, 10, ctx)
            local atkAfterFirst = player.attack
            sm:onHit(player, 10, ctx)  -- CD 中，不触发
            assert.equals(atkAfterFirst, player.attack)
        end)

        it("冷却结束后再次受伤可以触发", function()
            sm:onHit(player, 10, ctx)
            -- 恢复攻击力：先更新 BuffManager 让 rage Buff 到期（5s）
            player._buffManager:update(6.0, player)
            -- 再更新 SM 的 onhit CD（20s）
            sm:update(25.0, player, ctx, 0)
            local atkBetween = player.attack
            sm:onHit(player, 10, ctx)
            assert.is_true(player.attack > atkBetween)
        end)

    end)

    -- ============================================================
    -- 纯被动
    -- ============================================================
    describe("recalcPassive()", function()

        it("iron_body 正确累加 psb.maxHP +50", function()
            sm:add("iron_body", player)
            local psb = {}
            sm:recalcPassive(psb)
            assert.equals(50, psb.maxHP)
        end)

        it("swift_feet 正确累加 psb.speed +40", function()
            sm:add("swift_feet", player)
            local psb = {}
            sm:recalcPassive(psb)
            assert.equals(40, psb.speed)
        end)

        it("sharpshooter 正确累加 psb.critChance +10 / psb.critMult +30", function()
            sm:add("sharpshooter", player)
            local psb = {}
            sm:recalcPassive(psb)
            assert.equals(10, psb.critChance)
            assert.equals(30, psb.critMult)
        end)

        it("升级后加成增加（iron_body Lv2 = +75）", function()
            sm:add("iron_body", player)
            sm:add("iron_body", player)  -- Lv2
            local psb = {}
            sm:recalcPassive(psb)
            assert.equals(75, psb.maxHP)
        end)

        it("energy_field 正确累加 pickupRange 和 expMult", function()
            sm:add("energy_field", player)
            local psb = {}
            sm:recalcPassive(psb)
            assert.equals(80, psb.pickupRange)
            assert.equals(20, psb.expMult)
        end)

        it("iron_will 正确累加 psb.defense", function()
            sm:add("iron_will", player)
            local psb = {}
            sm:recalcPassive(psb)
            assert.equals(10, psb.defense)
        end)

    end)

    -- ============================================================
    -- 角色专属
    -- ============================================================
    describe("角色专属技能 overload", function()

        it("default 角色可以添加 overload", function()
            player.characterId = "default"
            local ok = sm:add("overload", player)
            assert.is_true(ok)
        end)

        it("非 default 角色无法添加 overload", function()
            player.characterId = "warrior"
            local ok = sm:add("overload", player)
            assert.is_false(ok)
        end)

        it("没有 characterId 限制的技能对任意角色可用", function()
            player.characterId = "warrior"
            local ok = sm:add("dash", player)
            assert.is_true(ok)
        end)

    end)

    -- ============================================================
    -- 多技能叠加
    -- ============================================================
    describe("多技能叠加互不干扰", function()

        it("同时持有主动+被动+事件被动，各自独立运作", function()
            sm:add("dash",       player)   -- 主动
            sm:add("iron_body",  player)   -- 纯被动
            sm:add("heal_pulse", player)   -- 事件被动
            sm:add("rage",       player)   -- passive_onhit

            -- 主动触发正常
            assert.is_true(sm:tryActivate("skill1", player, ctx, 0))

            -- 纯被动正常累加
            local psb = {}
            sm:recalcPassive(psb)
            assert.equals(50, psb.maxHP)

            -- 定时被动计时正常
            player.hp = 50
            sm:update(15.0, player, ctx, 0)
            assert.is_true(player.hp > 50)

            -- onHit 正常触发
            local atkBefore = player.attack
            sm:onHit(player, 10, ctx)
            assert.is_true(player.attack > atkBefore)
        end)

    end)

end)
