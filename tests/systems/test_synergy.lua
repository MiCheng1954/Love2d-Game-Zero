--[[
    tests/systems/test_synergy.lua
    Tag 羁绊系统单元测试（Phase 7.2 重写版）
    覆盖：tag 计数、档位激活/降级、playerSynergyBonus 累加、isFused 跳过、多 tag 同时激活
]]

require("tests.helper")
local Bag    = require("src.systems.bag")
local Weapon = require("src.entities.weapon")

describe("Synergy", function()

    local bag

    before_each(function()
        Weapon.resetIdCounter()
        bag = Bag.new(6, 8)
    end)

    -- ============================================================
    -- tag 计数基础
    -- ============================================================
    describe("tag 计数", function()
        it("放入 pistol(速射/精准) — tagCounts 正确", function()
            bag:place(Weapon.new("pistol"), 1, 1)
            assert.equals(1, bag._tagCounts["速射"]  or 0)
            assert.equals(1, bag._tagCounts["精准"]  or 0)
            assert.equals(0, bag._tagCounts["重型"]  or 0)
        end)

        it("放入 pistol + smg — 速射:2，精准:1", function()
            bag:place(Weapon.new("pistol"), 1, 1)
            bag:place(Weapon.new("smg"),    1, 3)
            assert.equals(2, bag._tagCounts["速射"] or 0)
            assert.equals(1, bag._tagCounts["精准"] or 0)
        end)

        it("isFused 武器不计入 tagCounts", function()
            -- dual_pistol 带 isFused=true，放入后速射/精准不应增加
            bag:place(Weapon.new("pistol"),     1, 1)  -- 速射:1, 精准:1
            bag:place(Weapon.new("dual_pistol"), 1, 3)  -- isFused，不计
            assert.equals(1, bag._tagCounts["速射"] or 0)
            assert.equals(1, bag._tagCounts["精准"] or 0)
        end)

        it("移除武器后 tagCounts 减少", function()
            local smg = Weapon.new("smg")
            bag:place(Weapon.new("pistol"), 1, 1)
            bag:place(smg,                  1, 3)
            assert.equals(2, bag._tagCounts["速射"] or 0)
            bag:remove(smg)
            assert.equals(1, bag._tagCounts["速射"] or 0)
        end)
    end)

    -- ============================================================
    -- T1 激活（x2）
    -- ============================================================
    describe("T1 激活（x2）", function()
        it("速射 x2 → 急速光环激活，psb.speed=25", function()
            bag:place(Weapon.new("pistol"), 1, 1)  -- 速射, 精准
            bag:place(Weapon.new("smg"),    1, 3)  -- 速射
            -- 速射 tagCount = 2 → T1 激活
            local ids = {}
            for _, s in ipairs(bag._activeSynergies) do ids[s.id] = true end
            assert.is_true(ids["速射_t2"])
            assert.equals(25, bag._playerSynergyBonus.speed)
        end)

        it("重型 x2 → 重装压制激活，psb.damage=15", function()
            bag:place(Weapon.new("shotgun"), 1, 1)  -- 重型, 游击
            bag:place(Weapon.new("cannon"),  3, 1)  -- 重型, 爆炸
            local ids = {}
            for _, s in ipairs(bag._activeSynergies) do ids[s.id] = true end
            assert.is_true(ids["重型_t2"])
            assert.equals(15, bag._playerSynergyBonus.damage)
        end)

        it("只有 1 把速射武器时不激活", function()
            bag:place(Weapon.new("smg"), 1, 1)  -- 速射:1 → 未达 T1(x2)
            assert.equals(0, #bag._activeSynergies)
            assert.equals(0, bag._playerSynergyBonus.speed)
        end)
    end)

    -- ============================================================
    -- T2 激活（x3）并覆盖 T1
    -- ============================================================
    describe("T2 激活（x3，覆盖 T1）", function()
        it("速射 x3 → 弹雨狂潮（T2），不再列出 T1", function()
            -- pistol(速射/精准) + smg(速射) + burst_pistol(速射/精准) = 速射:3
            bag:place(Weapon.new("pistol"),      1, 1)
            bag:place(Weapon.new("smg"),         1, 3)
            bag:place(Weapon.new("burst_pistol"), 1, 5)
            local ids = {}
            for _, s in ipairs(bag._activeSynergies) do ids[s.id] = true end
            assert.is_true(ids["速射_t3"])
            assert.is_nil(ids["速射_t2"])  -- T2 覆盖 T1，不同时出现
        end)

        it("速射 T2 效果：psb.speed=50，psb.damage=+8（来自速射）", function()
            bag:place(Weapon.new("pistol"),      1, 1)
            bag:place(Weapon.new("smg"),         1, 3)
            bag:place(Weapon.new("burst_pistol"), 1, 5)
            assert.equals(50, bag._playerSynergyBonus.speed)
            -- damage 来自速射T2 effect={speed=50, damage=8}
            -- 如果同时有其他 tag 激活可能叠加，这里只放速射武器（pistol/smg/burst_pistol 都带精准但 burst_pistol 精准=3 也激活 T2）
            -- 精准 T2 = critChance=15, critMult=40（不影响 damage）
            -- 所以 psb.damage 只来自速射 T2 的 damage=8
            assert.equals(8, bag._playerSynergyBonus.damage)
        end)

        it("移除一把后从 T2 降回 T1", function()
            local burst = Weapon.new("burst_pistol")
            bag:place(Weapon.new("pistol"), 1, 1)
            bag:place(Weapon.new("smg"),    1, 3)
            bag:place(burst,                1, 5)

            local ids = {}
            for _, s in ipairs(bag._activeSynergies) do ids[s.id] = true end
            assert.is_true(ids["速射_t3"])

            bag:remove(burst)  -- 速射降回 2

            ids = {}
            for _, s in ipairs(bag._activeSynergies) do ids[s.id] = true end
            assert.is_true(ids["速射_t2"])
            assert.is_nil(ids["速射_t3"])
            assert.equals(25, bag._playerSynergyBonus.speed)
        end)
    end)

    -- ============================================================
    -- playerSynergyBonus 累加
    -- ============================================================
    describe("playerSynergyBonus 累加", function()
        it("无羁绊时 psb 全为零", function()
            bag:place(Weapon.new("pistol"), 1, 1)
            assert.equals(0, bag._playerSynergyBonus.speed)
            assert.equals(0, bag._playerSynergyBonus.damage)
            assert.equals(0, bag._playerSynergyBonus.critChance)
            assert.equals(0, bag._playerSynergyBonus.maxHP)
        end)

        it("速射T1 + 精准T1 同时激活，psb 正确叠加", function()
            -- pistol(速射/精准) + smg(速射) → 速射:2(T1), 精准:1
            -- sniper(精准) → 精准:2(T1)
            bag:place(Weapon.new("pistol"), 1, 1)
            bag:place(Weapon.new("smg"),    1, 3)
            bag:place(Weapon.new("sniper"), 3, 1)
            -- 速射T1: speed=25; 精准T1: critChance=8
            assert.equals(25, bag._playerSynergyBonus.speed)
            assert.equals(8,  bag._playerSynergyBonus.critChance)
            assert.equals(2, #bag._activeSynergies)
        end)

        it("精准 T2：critChance=15, critMult=40", function()
            -- pistol(速射/精准) + sniper(精准,1×3) + rail_rifle(精准/科技,1×3) = 精准:3 → T2
            -- sniper 在 (1,1) 占第1-3列，rail_rifle 在 (2,1) 占第1-3列（第2行，不冲突）
            bag:place(Weapon.new("pistol"),    3, 5)
            bag:place(Weapon.new("sniper"),    1, 1)
            bag:place(Weapon.new("rail_rifle"), 2, 1)
            local ids = {}
            for _, s in ipairs(bag._activeSynergies) do ids[s.id] = true end
            assert.is_true(ids["精准_t3"])
            assert.equals(15, bag._playerSynergyBonus.critChance)
            assert.equals(40, bag._playerSynergyBonus.critMult)
        end)

        it("移除所有武器后 psb 归零，activeSynergies 清空", function()
            local p = Weapon.new("pistol")
            local s = Weapon.new("smg")
            bag:place(p, 1, 1)
            bag:place(s, 1, 3)
            assert.equals(25, bag._playerSynergyBonus.speed)

            bag:remove(p)
            bag:remove(s)
            assert.equals(0, #bag._activeSynergies)
            assert.equals(0, bag._playerSynergyBonus.speed)
        end)
    end)

    -- ============================================================
    -- isFused 武器跳过
    -- ============================================================
    describe("isFused 武器跳过", function()
        it("dual_pistol(isFused) 独占背包 — tagCounts 为空，无羁绊", function()
            bag:place(Weapon.new("dual_pistol"), 1, 1)
            assert.equals(0, bag._tagCounts["速射"] or 0)
            assert.equals(0, #bag._activeSynergies)
        end)

        it("railgun(isFused) + sniper — 精准仍只计 1 把，不激活 T1", function()
            bag:place(Weapon.new("railgun"), 1, 1)  -- isFused, 不计
            bag:place(Weapon.new("sniper"),  1, 5)  -- 精准:1
            assert.equals(1, bag._tagCounts["精准"] or 0)
            local ids = {}
            for _, s in ipairs(bag._activeSynergies) do ids[s.id] = true end
            assert.is_nil(ids["精准_t2"])
        end)
    end)

end)
