--[[
    config/i18n/zh.lua
    中文文本配置表，包含游戏中所有中文字符串的 key-value 映射
    Phase 5.1：i18n 多语言支持基础
    Phase 7.2：新增 6 把武器文本 + Tag 羁绊系统文本
]]

return {
    -- HUD
    ["hud.hp"]           = "HP",
    ["hud.level"]        = "Lv.",
    ["hud.souls"]        = "灵魂",
    ["hud.enemies"]      = "敌人",
    ["hud.hint"]         = "WASD 移动  |  TAB 背包  |  P 暂停  |  ESC 返回菜单",
    ["hud.paused"]       = "⏸  已暂停",
    ["hud.pause_hint"]   = "按 P 继续游戏",
    ["hud.skills"]       = "[技能]",   -- Phase 8
    ["hud.passives"]     = "被动:",    -- Phase 8 需求5

    -- 升级界面
    ["upgrade.title"]    = "★  LEVEL UP  ★",
    ["upgrade.reached"]  = "达到 Lv.%d",
    ["upgrade.cat.hint"] = "↑↓ 移动   Enter 确认",
    ["upgrade.opt.hint"] = "↑↓ 移动   Enter 确认   ESC 返回大类",
    ["upgrade.refresh"]  = "← 消耗 %d 灵魂刷新选项  (当前: %d)",
    ["upgrade.cat.label"]= "选择奖励大类",

    -- 控制台
    ["console.title"]    = "[DEV CONSOLE]",
    ["console.hint"]     = "输入指令后按 Enter 执行，ESC 关闭",
    ["console.unknown"]  = "未知指令: %s",

    -- Bug 反馈
    ["bug.title"]        = "[BUG 反馈]",
    ["bug.desc.hint"]    = "描述问题（Enter 确认，ESC 取消）：",
    ["bug.priority"]     = "优先级 [1=低 2=中 3=高]：",
    ["bug.saved"]        = "Bug #%d 已记录",
    ["bug.hint"]         = "输入描述后按 Enter，再选择优先级",

    -- 菜单
    ["menu.title"]       = "ZERO",
    ["menu.start"]       = "开始游戏",

    -- 结算
    ["gameover.title"]         = "GAME OVER",
    ["gameover.hint"]          = "按 Enter 返回菜单",
    ["gameover.victory_title"] = "★  VICTORY  ★",
    ["gameover.victory_sub"]   = "你击败了虚空领主，世界得救了！",

    -- 升级大类（与 config/upgrades.lua 对应）
    ["cat.weapon"]       = "武器强化",
    ["cat.stat"]         = "属性提升",
    ["cat.skill"]        = "技能获取",

    -- 升级子选项 label
    ["opt.weapon_new_basic.label"]   = "获得新武器",
    ["opt.weapon_upgrade.label"]     = "强化现有武器",
    ["opt.weapon_bag_expand.label"]  = "扩展背包",
    ["opt.stat_hp.label"]            = "强化生命",
    ["opt.stat_speed.label"]         = "强化速度",
    ["opt.stat_attack.label"]        = "强化攻击",
    ["opt.stat_pickup.label"]        = "强化吸附",
    ["opt.stat_crit.label"]          = "强化暴击",
    ["opt.stat_exp.label"]           = "强化经验",
    ["opt.skill_placeholder_1.label"]= "技能（待实装）",
    ["opt.skill_placeholder_2.label"]= "被动技能（待实装）",

    -- Phase 8：技能大类升级选项
    ["opt.skill_get.label"]  = "获得/升级技能",

    -- 升级子选项 desc
    ["opt.weapon_new_basic.desc"]    = "获得一把随机武器加入背包",
    ["opt.weapon_upgrade.desc"]      = "随机强化一把已装备武器的攻击力",
    ["opt.weapon_bag_expand.desc"]   = "背包行列各 +1（最大 6×8）",
    ["opt.stat_hp.desc"]             = "最大生命值 +30，并回复 30 点生命",
    ["opt.stat_speed.desc"]          = "移动速度 +20",
    ["opt.stat_attack.desc"]         = "攻击力 +10",
    ["opt.stat_pickup.desc"]         = "拾取吸附半径 +30",
    ["opt.stat_crit.desc"]           = "暴击率 +5%，暴击伤害 +20%",
    ["opt.stat_exp.desc"]            = "经验获取倍率 +20%",
    ["opt.skill_placeholder_1.desc"] = "Phase 8 接入技能系统后实装",
    ["opt.skill_placeholder_2.desc"] = "Phase 8 接入技能系统后实装",

    -- Phase 8：技能大类升级选项描述
    ["opt.skill_get.desc"]   = "从技能池随机抽取3个技能供选择",

    -- Debug 面板
    ["debug.title"]      = "[DEBUG]",

    -- 背包界面
    ["bag.title"]              = "◈  背包  ◈",
    ["bag.empty"]              = "（空）",
    ["bag.hint.browse"]        = "方向键 移动光标  |  Enter 拾起移动  |  Q 武器面板  |  E 技能面板  |  ESC 关闭",
    ["bag.hint.place"]         = "方向键 移动位置  |  R 旋转  |  Enter 放置  |  ESC 丢弃",
    ["bag.hint.select"]        = "方向键 移动光标  |  Enter 选择  |  ESC 取消",
    ["bag.hint.select_upgrade"]= "选择一把武器进行强化  |  Enter 确认  |  ESC 取消",
    ["bag.adj_bonus"]          = "◆ 相邻加成",
    ["bag.synergy_bonus"]      = "◆ 羁绊加成",
    ["bag.hint.fusion"]        = "Enter 确认融合  |  ESC 取消",
    ["bag.fusion.title"]       = "=== 武器融合 ===",
    ["bag.fusion.warning"]     = "※ 融合将消耗【%s】和【%s】，此操作不可撤销",
    ["bag.fusion.no_space"]    = "⚠  背包空间不足，无法放置融合结果  |  ESC 取消",

    -- 武器名称
    ["weapon.pistol.name"]  = "手枪",
    ["weapon.shotgun.name"] = "散弹枪",
    ["weapon.smg.name"]     = "冲锋枪",
    ["weapon.sniper.name"]  = "狙击枪",
    ["weapon.cannon.name"]  = "炮",
    ["weapon.laser.name"]   = "激光枪",

    -- 武器描述
    ["weapon.pistol.desc"]  = "基础平衡型武器，适合各种场合。",
    ["weapon.shotgun.desc"] = "高伤害近距离武器，射速较慢。",
    ["weapon.smg.desc"]     = "极快射速，适合持续输出。",
    ["weapon.sniper.desc"]  = "超远射程，极高单发伤害，射速极慢。",
    ["weapon.cannon.desc"]  = "强力炮击，伤害高但射速慢。",
    ["weapon.laser.desc"]   = "高射速中等伤害，持续压制。",

    -- 武器被动效果描述（需求3）
    ["weapon.pistol.passive"]      = "精准训练：使相邻武器射速 +0.15/s",
    ["weapon.shotgun.passive"]     = "制止力：使相邻武器伤害 +8",
    ["weapon.smg.passive"]         = "速射光环：使相邻武器射速 +0.4/s",
    ["weapon.sniper.passive"]      = "远程感知：使相邻武器射程 +60px",
    ["weapon.cannon.passive"]      = "重型弹药：使相邻武器伤害 +12",
    ["weapon.laser.passive"]       = "精准能量：使相邻武器射速 +0.2/s、射程 +20px",
    ["weapon.dual_pistol.passive"] = "双枪节奏：使相邻武器射速 +0.5/s",
    ["weapon.siege_cannon.passive"]= "重甲威压：使相邻武器伤害 +20",
    ["weapon.railgun.passive"]     = "能量场：使相邻武器射程 +80px、射速 +0.1/s",

    -- Phase 7.2：新增 6 把武器被动效果描述
    ["weapon.burst_pistol.passive"]      = "速射干扰：使相邻武器射速 +0.3/s",
    ["weapon.grenade_launcher.passive"]  = "爆炸波及：使相邻武器伤害 +10",
    ["weapon.double_barrel.passive"]     = "双管压制：使相邻武器伤害 +9",
    ["weapon.gatling.passive"]           = "弹幕掩护：使相邻武器射速 +0.5/s",
    ["weapon.plasma_pistol.passive"]     = "等离子场：使相邻武器射速 +0.2/s、射程 +25px",
    ["weapon.rail_rifle.passive"]        = "磁轨穿透：使相邻武器射程 +50px",

    -- Phase 7.1：融合结果武器名称与描述
    ["weapon.dual_pistol.name"]   = "双持手枪",
    ["weapon.dual_pistol.desc"]   = "手枪与冲锋枪融合而成，射速极快且弹如雨下。",
    ["weapon.siege_cannon.name"]  = "攻城炮",
    ["weapon.siege_cannon.desc"]  = "散弹枪与炮融合而成，每发炮弹伤害惊人。",
    ["weapon.railgun.name"]       = "轨道炮",
    ["weapon.railgun.desc"]       = "狙击枪与激光枪融合而成，超远射程高频打击。",

    -- Phase 7.2：新增 6 把基础武器名称与描述
    ["weapon.burst_pistol.name"]      = "爆发手枪",
    ["weapon.burst_pistol.desc"]      = "改良型手枪，射速更快，兼具精准与速度。",
    ["weapon.grenade_launcher.name"]  = "榴弹发射器",
    ["weapon.grenade_launcher.desc"]  = "发射爆炸榴弹，单发伤害高，射速较慢。",
    ["weapon.double_barrel.name"]     = "双管猎枪",
    ["weapon.double_barrel.desc"]     = "双管设计提供更高伤害，极近距离效果惊人。",
    ["weapon.gatling.name"]           = "加特林",
    ["weapon.gatling.desc"]           = "多管旋转机枪，射速恐怖，占用 2×2 空间。",
    ["weapon.plasma_pistol.name"]     = "等离子手枪",
    ["weapon.plasma_pistol.desc"]     = "发射等离子弹，融合科技与爆炸能量。",
    ["weapon.rail_rifle.name"]        = "磁轨步枪",
    ["weapon.rail_rifle.desc"]        = "磁力加速步枪，射程极远，弹速极高。",

    -- Phase 7.2：Tag 显示名（用于背包羁绊进度条）
    ["tag.速射"] = "速射",
    ["tag.精准"] = "精准",
    ["tag.重型"] = "重型",
    ["tag.爆炸"] = "爆炸",
    ["tag.科技"] = "科技",
    ["tag.游击"] = "游击",

    -- Phase 7.2：Tag 羁绊 — 速射
    ["syn.速射.t2.name"] = "急速光环",
    ["syn.速射.t2.desc"] = "速射武器 x2：移动速度 +25",
    ["syn.速射.t3.name"] = "弹雨狂潮",
    ["syn.速射.t3.desc"] = "速射武器 x3：移动速度 +50，攻击力 +8",

    -- Phase 7.2：Tag 羁绊 — 精准
    ["syn.精准.t2.name"] = "精准感知",
    ["syn.精准.t2.desc"] = "精准武器 x2：暴击率 +8%",
    ["syn.精准.t3.name"] = "致命精度",
    ["syn.精准.t3.desc"] = "精准武器 x3：暴击率 +15%，暴击伤害 +40%",

    -- Phase 7.2：Tag 羁绊 — 重型
    ["syn.重型.t2.name"] = "重装压制",
    ["syn.重型.t2.desc"] = "重型武器 x2：攻击力 +15",
    ["syn.重型.t3.name"] = "铁甲破阵",
    ["syn.重型.t3.desc"] = "重型武器 x3：攻击力 +30，最大生命 +30",

    -- Phase 7.2：Tag 羁绊 — 爆炸
    ["syn.爆炸.t2.name"] = "弹道强化",
    ["syn.爆炸.t2.desc"] = "爆炸武器 x2：所有子弹飞行速度 +80",
    ["syn.爆炸.t3.name"] = "爆破先锋",
    ["syn.爆炸.t3.desc"] = "爆炸武器 x3：子弹速度 +160，攻击力 +10",

    -- Phase 7.2：Tag 羁绊 — 科技
    ["syn.科技.t2.name"] = "能量感应",
    ["syn.科技.t2.desc"] = "科技武器 x2：拾取范围 +60",
    ["syn.科技.t3.name"] = "科技领域",
    ["syn.科技.t3.desc"] = "科技武器 x3：拾取范围 +120，经验获取 +25%",

    -- Phase 7.2：Tag 羁绊 — 游击
    ["syn.游击.t2.name"] = "战场直觉",
    ["syn.游击.t2.desc"] = "游击武器 x2：最大生命 +25",
    ["syn.游击.t3.name"] = "游击突袭",
    ["syn.游击.t3.desc"] = "游击武器 x3：最大生命 +50，移动速度 +20",

    -- ============================================================
    -- Phase 8：技能系统
    -- ============================================================

    -- 技能选择界面
    ["skill_select.title"]        = "★  获得技能  ★",
    ["skill_select.hint"]         = "↑↓ 移动   Enter 确认   ESC 取消",
    ["skill_select.hint_refresh"] = "↑↓ 移动   Enter 确认   R 刷新(%d灵魂)   ESC 取消",
    ["skill_select.empty"]        = "（暂无可选技能）",
    ["skill_select.no_souls"]     = "灵魂不足（需要 %d 个）",

    -- Phase 8：技能 Tag 显示名
    ["tag.skill.防御"] = "防御",
    ["tag.skill.爆发"] = "爆发",
    ["tag.skill.辅助"] = "辅助",
    ["tag.skill.精准"] = "精准",

    -- Phase 8：技能名称
    ["skill.dash.name"]         = "冲刺",
    ["skill.time_slow.name"]    = "时间减缓",
    ["skill.bomb_throw.name"]   = "投掷炸弹",
    ["skill.blink.name"]        = "幻影闪现",
    ["skill.battle_cry.name"]   = "战吼",
    ["skill.mana_shield.name"]  = "魔法护罩",
    ["skill.emp_burst.name"]    = "电磁脉冲",
    ["skill.heal_pulse.name"]   = "脉冲治疗",
    ["skill.ammo_supply.name"]  = "弹药补给",
    ["skill.explosion.name"]    = "爆炸波",
    ["skill.soul_drain.name"]   = "灵魂汲取",
    ["skill.counter_shot.name"] = "反击弹",
    ["skill.rage.name"]         = "狂怒",
    ["skill.thorns.name"]       = "荆棘反弹",
    ["skill.iron_body.name"]    = "铁甲之躯",
    ["skill.swift_feet.name"]   = "疾步",
    ["skill.sharpshooter.name"] = "神射手",
    ["skill.energy_field.name"] = "能量领域",
    ["skill.iron_will.name"]    = "钢铁意志",
    ["skill.overload.name"]     = "超载",

    -- Phase 8：技能描述
    ["skill.dash.desc"]         = "向移动方向冲刺 200px，按空格触发，CD 8s",
    ["skill.time_slow.desc"]    = "全屏敌人减速 80% 持续 3s，按 Q 触发，CD 20s",
    ["skill.bomb_throw.desc"]   = "前方 200px 爆炸，150px 内 80 伤害，按 E 触发，CD 12s",
    ["skill.blink.desc"]        = "瞬移到最近敌人背后造成 40 伤害，按 Q 触发，CD 15s",
    ["skill.battle_cry.desc"]   = "攻击力×2 持续 10s，附近敌人停滞 0.5s，按 F 触发，CD 25s",
    ["skill.mana_shield.desc"]  = "护盾吸收下一次伤害（持续 8s），按 F 触发，CD 18s",
    ["skill.emp_burst.desc"]    = "每 12s 自动触发，全屏敌人减速 50% 持续 3s",
    ["skill.heal_pulse.desc"]   = "每 15s 自动治疗，恢复 max(8, maxHP×5%)",
    ["skill.ammo_supply.desc"]  = "每 10s 标记弹药强化，下次攻击伤害×2",
    ["skill.explosion.desc"]    = "每 5 击杀触发，玩家周围 150px 内造成 60 伤害",
    ["skill.soul_drain.desc"]   = "每 3 击杀触发，恢复 5HP，临时扩大吸附范围",
    ["skill.counter_shot.desc"] = "受伤后向最近敌人发射 3 颗 30 伤害弹，CD 10s",
    ["skill.rage.desc"]         = "受伤后攻击力+50% 持续 5s，CD 20s",
    ["skill.thorns.desc"]       = "受伤后将 50% 伤害反弹给攻击者，CD 8s",
    ["skill.iron_body.desc"]    = "最大生命值 +50",
    ["skill.swift_feet.desc"]   = "移动速度 +40",
    ["skill.sharpshooter.desc"] = "暴击率 +10%，暴击伤害 +30%",
    ["skill.energy_field.desc"] = "拾取范围 +80，经验获取 +20%",
    ["skill.iron_will.desc"]    = "受到伤害减少 10%",
    ["skill.overload.desc"]     = "【角色专属】背包所有武器射速×2 持续 4s，CD 30s",

    -- Phase 8：技能羁绊名称与描述
    ["syn.skill.防御.t2.name"] = "铜墙铁壁",
    ["syn.skill.防御.t2.desc"] = "防御技能 x2：受到伤害减少 10%",
    ["syn.skill.防御.t3.name"] = "坚不可摧",
    ["syn.skill.防御.t3.desc"] = "防御技能 x3：受到伤害减少 20%，最大生命 +30",
    ["syn.skill.爆发.t2.name"] = "战斗狂热",
    ["syn.skill.爆发.t2.desc"] = "爆发技能 x2：主动技能冷却缩短 20%",
    ["syn.skill.爆发.t3.name"] = "无尽爆发",
    ["syn.skill.爆发.t3.desc"] = "爆发技能 x3：主动技能冷却缩短 35%，攻击力 +10",
    ["syn.skill.辅助.t2.name"] = "知识汲取",
    ["syn.skill.辅助.t2.desc"] = "辅助技能 x2：经验获取 +30%",
    ["syn.skill.辅助.t3.name"] = "智慧领域",
    ["syn.skill.辅助.t3.desc"] = "辅助技能 x3：经验获取 +50%，拾取范围 +60",
    ["syn.skill.精准.t2.name"] = "猎杀直觉",
    ["syn.skill.精准.t2.desc"] = "精准技能 x2：暴击率 +8%",
    ["syn.skill.精准.t3.name"] = "致命精准",
    ["syn.skill.精准.t3.desc"] = "精准技能 x3：暴击率 +15%，暴击伤害 +40%",

    -- Phase 9：Boss 名称
    ["boss.crusher.name"]   = "碎骨者",
    ["boss.phantom.name"]   = "幽灵法师",
    ["boss.colossus.name"]  = "钢铁巨兽",
    ["boss.void_lord.name"] = "虚空领主",

    -- Phase 9：胜利文本
    ["hud.victory"]         = "★  胜利！  ★",
    ["hud.victory_hint"]    = "你击败了虚空领主，世界得救了！",

    -- ============================================================
    -- Phase 10：结算、传承与复活
    -- ============================================================

    -- 结算界面（胜利）
    ["gameover.victory_title"]      = "★  VICTORY  ★",
    ["gameover.victory_sub"]        = "你击败了虚空领主，世界得救了！",
    ["gameover.hint"]               = "按任意键返回菜单",

    -- 结算界面（死亡）
    ["gameover.title"]              = "GAME OVER",
    ["gameover.death_sub"]          = "你在战斗中倒下了……",

    -- 结算统计项标签
    ["gameover.stat.elapsed"]       = "存活时长",
    ["gameover.stat.level"]         = "最终等级",
    ["gameover.stat.kills"]         = "总击杀数",
    ["gameover.stat.souls"]         = "收集灵魂",
    ["gameover.stat.synergies"]     = "激活羁绊",
    ["gameover.stat.bosses"]        = "击杀Boss",
    ["gameover.stat.none"]          = "（无）",

    -- 复活/传承二选一界面
    ["revive.title"]                = "⚠  你已倒下",
    ["revive.subtitle"]             = "还有机会……",
    ["revive.revive"]               = "复活",
    ["revive.legacy"]               = "传承",
    ["revive.revive_desc"]          = "消耗 1 次复活机会\n恢复满血，清除周围敌人\n获得 3 秒无敌时间",
    ["revive.legacy_desc"]          = "放弃本局，选择一项传承\n效果延续到下一局",
    ["revive.remaining"]            = "剩余复活次数：%d",
    ["revive.hint"]                 = "← → 切换选项   Enter 确认",

    -- 传承三选一界面
    ["legacy_select.title"]         = "◈  选择传承  ◈",
    ["legacy_select.subtitle"]      = "你的牺牲将延续下去……",
    ["legacy_select.hint"]          = "← → 切换卡片   Enter 确认",
    ["legacy_select.category"]      = "类别：%s",

    -- 传承类别名
    ["legacy.cat.伤害"]             = "伤害",
    ["legacy.cat.科技"]             = "科技",
    ["legacy.cat.生存"]             = "生存",
    ["legacy.cat.爆发"]             = "爆发",
    ["legacy.cat.经济"]             = "经济",

    -- 传承技能名称与描述
    ["legacy.attack.name"]          = "战意传承",
    ["legacy.attack.desc"]          = "攻击力永久 +8",
    ["legacy.crit_rate.name"]       = "暴击传承",
    ["legacy.crit_rate.desc"]       = "暴击率永久 +5%",
    ["legacy.crit_dmg.name"]        = "致命传承",
    ["legacy.crit_dmg.desc"]        = "暴击伤害永久 +20%",
    ["legacy.bullet_speed.name"]    = "弹道传承",
    ["legacy.bullet_speed.desc"]    = "弹速永久 +40",
    ["legacy.cooldown.name"]        = "冷却传承",
    ["legacy.cooldown.desc"]        = "所有技能 CD 缩短 10%",
    ["legacy.attack_speed.name"]    = "射速传承",
    ["legacy.attack_speed.desc"]    = "武器射速永久 +10%",
    ["legacy.hp.name"]              = "生命传承",
    ["legacy.hp.desc"]              = "最大 HP 永久 +30",
    ["legacy.defense.name"]         = "护甲传承",
    ["legacy.defense.desc"]         = "防御力永久 +3%",
    ["legacy.speed.name"]           = "疾步传承",
    ["legacy.speed.desc"]           = "移速永久 +15",
    ["legacy.exp.name"]             = "智慧传承",
    ["legacy.exp.desc"]             = "经验获取永久 +20%",
    ["legacy.pickup.name"]          = "引力传承",
    ["legacy.pickup.desc"]          = "拾取范围永久 +40",
    ["legacy.souls.name"]           = "灵魂传承",
    ["legacy.souls.desc"]           = "灵魂获取永久 +20%",

    -- HUD：传承图标悬停文字
    ["hud.legacy_icon"]             = "传承",
    ["hud.legacy_none"]             = "（无传承）",

    -- ============================================================
    -- Phase 10.1：Buff 系统
    -- ============================================================

    -- Buff 名称（用于 Buff HUD 显示）
    ["buff.invincible.name"]        = "无敌",
    ["buff.battle_cry.name"]        = "战吼",
    ["buff.rage.name"]              = "狂怒",
    ["buff.overload.name"]          = "超载",
    ["buff.mana_shield.name"]       = "护盾",
    ["buff.soul_drain_range.name"]  = "灵魂汲取",
    ["buff.global_slow.name"]       = "时间减缓",
    ["buff.ammo_supply.name"]       = "弹药强化",

    -- ============================================================
    -- Phase 11：主菜单完善
    -- ============================================================
    ["menu.continue"]               = "继续游戏",
    ["menu.settings"]               = "设置",
    ["menu.exit"]                   = "退出游戏",
    ["menu.char_select_hint"]       = "角色选择（敬请期待）",
    ["menu.progression"]            = "成长",
    ["menu.achievements"]           = "成就",
    ["menu.version"]                = "版本 0.11",

    -- ============================================================
    -- Phase 12：场景系统
    -- ============================================================

    -- 场景选择界面
    ["scene_select.title"]          = "◈  选择战场  ◈",
    ["scene_select.hint"]           = "← → 切换   Enter 进入战场   ESC 返回",

    -- 平原场景
    ["scene.plains.name"]           = "苍茫平原",
    ["scene.plains.desc"]           = "无垠的荒野，敌人从四面八方涌来。标准难度，适合初次挑战。",
    ["scene.plains.difficulty"]     = "★☆☆  普通",

    -- 竞技场场景
    ["scene.arena.name"]            = "封闭竞技场",
    ["scene.arena.desc"]            = "四面高墙封锁的擂台，靠近边界会持续受伤。敌人更密集，灵魂掉落×1.3。",
    ["scene.arena.difficulty"]      = "★★☆  中等",

    -- 地下城场景
    ["scene.dungeon.name"]          = "暗影地下城",
    ["scene.dungeon.desc"]          = "蜿蜒的石室通道，迷宫般的房间结构。（即将开放）",
    ["scene.dungeon.difficulty"]    = "★★★  挑战",

    -- Boss 名称（Phase 12）
    ["boss.charger.name"]           = "冲锋者",

    -- ============================================================
    -- Phase 11：触发器 UI
    -- ============================================================
    ["trigger.title"]               = "✦  获得奖励  ✦",
    ["trigger.auto_close"]          = "%.1f 秒后自动关闭",
    ["trigger.confirm"]             = "按任意键确认",
    ["trigger.type.stat"]           = "属性强化",
    ["trigger.type.weapon"]         = "武器获得",
    ["trigger.type.skill"]          = "技能获得",
    ["trigger.type.bag"]            = "背包扩展",
    ["trigger.type.soul"]           = "灵魂转换",

    -- ============================================================
    -- Phase 13：局外系统
    -- ============================================================

    -- 角色选择界面
    ["char_select.title"]           = "◈  选择英雄  ◈",
    ["char_select.hint"]            = "← → 切换   Enter 确认   ESC 返回",
    ["char_select.stats"]           = "基础属性",
    ["char_select.exclusive"]       = "专属技能",
    ["char_select.affinity"]        = "擅长方向",

    -- 工程师
    ["char.engineer.name"]          = "工程师",
    ["char.engineer.desc"]          = "精通武器改造的科技专家。超载技能让所有武器进入超频状态，射速翻倍。擅长堆叠武器数量，发挥科技羁绊潜力。",
    -- 工程师技能树节点
    ["char.engineer.node.overload_duration.name"]  = "超载延时",
    ["char.engineer.node.overload_duration.desc"]  = "超载持续时间 +1 秒",
    ["char.engineer.node.overload_shield.name"]    = "超载护盾",
    ["char.engineer.node.overload_shield.desc"]    = "超载激活时自动触发魔法护盾",
    ["char.engineer.node.overload_cooldown.name"]  = "高效制冷",
    ["char.engineer.node.overload_cooldown.desc"]  = "超载冷却时间缩短 30%",
    ["char.engineer.node.weapon_slots.name"]       = "扩容背包",
    ["char.engineer.node.weapon_slots.desc"]       = "初始背包额外增加 1 行格子",
    ["char.engineer.node.weapon_adj.name"]         = "精密布线",
    ["char.engineer.node.weapon_adj.desc"]         = "武器相邻增益效果 +25%",
    -- 工程师里程碑
    ["char.engineer.ms.overload_10.name"]          = "超频达人",
    ["char.engineer.ms.overload_10.desc"]          = "单局触发超载 10 次",
    ["char.engineer.ms.weapons_6.name"]            = "武器收藏家",
    ["char.engineer.ms.weapons_6.desc"]            = "同时拥有 6 把不同武器",
    ["char.engineer.ms.survive_20min.name"]        = "持久战争",
    ["char.engineer.ms.survive_20min.desc"]        = "单局存活 20 分钟",

    -- 狂战士
    ["char.berserker.name"]         = "狂战士",
    ["char.berserker.desc"]         = "以血换伤的近身爆发者。生命值越低，攻击力越强。战吼让自身进入狂暴状态，高风险高回报的战斗风格。",
    -- 狂战士技能树节点
    ["char.berserker.node.bloodrage_1.name"]       = "血怒 I",
    ["char.berserker.node.bloodrage_1.desc"]       = "HP 低于 50% 时攻击力 +15%",
    ["char.berserker.node.bloodrage_2.name"]       = "血怒 II",
    ["char.berserker.node.bloodrage_2.desc"]       = "HP 低于 30% 时攻击力额外 +30%",
    ["char.berserker.node.last_stand.name"]        = "最后的意志",
    ["char.berserker.node.last_stand.desc"]        = "致命伤害时触发 1 秒无敌（每局 1 次）",
    ["char.berserker.node.dash_dmg.name"]          = "冲刺穿刺",
    ["char.berserker.node.dash_dmg.desc"]          = "冲刺经过的敌人受到 30 点伤害",
    ["char.berserker.node.dash_cd.name"]           = "疾冲",
    ["char.berserker.node.dash_cd.desc"]           = "冲刺冷却时间缩短 30%",
    -- 狂战士里程碑
    ["char.berserker.ms.kill_500.name"]            = "杀戮机器",
    ["char.berserker.ms.kill_500.desc"]            = "单局击杀 500 个敌人",
    ["char.berserker.ms.low_hp_survive.name"]      = "濒死求生",
    ["char.berserker.ms.low_hp_survive.desc"]      = "在 HP 低于 30% 的状态下累计存活 5 分钟",
    ["char.berserker.ms.kill_boss.name"]           = "以弱胜强",
    ["char.berserker.ms.kill_boss.desc"]           = "击败任意一个 Boss",

    -- 幽灵
    ["char.phantom.name"]           = "幽灵",
    ["char.phantom.desc"]           = "来无影去无踪的速度刺客。超高移速配合闪现，几乎无法被敌人捕捉。擅长利用减速领域控制战场节奏。",
    -- 幽灵技能树节点
    ["char.phantom.node.blink_range.name"]         = "瞬移强化",
    ["char.phantom.node.blink_range.desc"]         = "闪现距离 +30%",
    ["char.phantom.node.blink_atk.name"]           = "残影突袭",
    ["char.phantom.node.blink_atk.desc"]           = "闪现后 2 秒内攻击速度 +50%",
    ["char.phantom.node.blink_cd.name"]            = "虚空步",
    ["char.phantom.node.blink_cd.desc"]            = "闪现冷却时间缩短 40%",
    ["char.phantom.node.slow_range.name"]          = "时空裂缝",
    ["char.phantom.node.slow_range.desc"]          = "时间减缓范围 +40%",
    ["char.phantom.node.slow_rate.name"]           = "深度冻结",
    ["char.phantom.node.slow_rate.desc"]           = "时间减缓效果加深（减速倍率提升）",
    -- 幽灵里程碑
    ["char.phantom.ms.blink_20.name"]              = "幻影连闪",
    ["char.phantom.ms.blink_20.desc"]              = "单局使用闪现 20 次",
    ["char.phantom.ms.arena_survive.name"]         = "竞技场幽灵",
    ["char.phantom.ms.arena_survive.desc"]         = "在封闭竞技场存活 15 分钟",
    ["char.phantom.ms.no_damage_1min.name"]        = "无懈可击",
    ["char.phantom.ms.no_damage_1min.desc"]        = "连续 60 秒不受到任何伤害",

    -- 局外成长界面
    ["progression.title"]               = "◈  局外成长  ◈",
    ["progression.tab.common"]          = "通用加成",
    ["progression.tab.tree"]            = "英雄技能树",
    ["progression.hint"]                = "Q/E 切换面板   ↑↓ 选择   Enter 解锁   ESC 返回",
    ["progression.points"]              = "成长点数：%d",
    ["progression.unlock"]              = "解锁（消耗 %d 点）",
    ["progression.unlocked"]            = "✓ 已解锁",
    ["progression.locked"]              = "🔒 需先解锁前置",
    ["progression.insufficient"]        = "点数不足",
    ["progression.common.attack"]       = "攻击力 +%d%%",
    ["progression.common.speed"]        = "移速 +%d%%",
    ["progression.common.maxhp"]        = "最大HP +%d",
    ["progression.common.critrate"]     = "暴击率 +%d%%",
    ["progression.common.pickup"]       = "拾取范围 +%d%%",
    ["progression.common.expmult"]      = "经验获取 +%d%%",

    -- 里程碑
    ["milestone.title"]                 = "里程碑",
    ["milestone.progress"]              = "%d / %d",
    ["milestone.completed"]             = "✓ 已完成  +%d 点",
    ["milestone.points_earned"]         = "获得里程碑点数：+%d",

    -- 成就界面
    ["achievements.title"]              = "◈  成就  ◈",
    ["achievements.hint"]               = "↑↓ 移动   ESC 返回",
    ["achievements.unlocked"]           = "已解锁",
    ["achievements.locked"]             = "未解锁",
    ["achievements.empty"]              = "暂无成就数据",

    -- 结算：成长点数
    ["gameover.points_earned"]          = "获得成长点数",
    ["gameover.points_kill"]            = "击杀奖励",
    ["gameover.points_survive"]         = "存活奖励",
    ["gameover.points_boss"]            = "Boss 击败奖励",

    -- 通用机制树（progressionTree）
    ["tree.atk_1.name"]   = "暴击强化",
    ["tree.atk_1.desc"]   = "暴击率提升 +3%",
    ["tree.atk_2.name"]   = "致命打击",
    ["tree.atk_2.desc"]   = "暴击伤害提升 +20%",
    ["tree.atk_3.name"]   = "嗜血",
    ["tree.atk_3.desc"]   = "每次击杀恢复 1 点HP",
    ["tree.sur_1.name"]   = "厚甲",
    ["tree.sur_1.desc"]   = "最大生命值 +20",
    ["tree.sur_2.name"]   = "受创冲刺",
    ["tree.sur_2.desc"]   = "受伤后 2 秒内移速 +15%",
    ["tree.sur_3.name"]   = "最后抵抗",
    ["tree.sur_3.desc"]   = "死亡时触发一次 2 秒无敌（每局限1次）",
    ["tree.eco_1.name"]   = "学识",
    ["tree.eco_1.desc"]   = "经验获取 +15%",
    ["tree.eco_2.name"]   = "拾魂",
    ["tree.eco_2.desc"]   = "灵魂获取 +25%",
    ["tree.eco_3.name"]   = "贪婪",
    ["tree.eco_3.desc"]   = "结算时通用点数产出 +20%",
    ["tree.wpn_1.name"]   = "快枪手",
    ["tree.wpn_1.desc"]   = "所有武器射速 +10%",
    ["tree.wpn_2.name"]   = "高速弹道",
    ["tree.wpn_2.desc"]   = "所有子弹速度 +15%",
    ["tree.wpn_3.name"]   = "融合精通",
    ["tree.wpn_3.desc"]   = "融合武器伤害额外 +20%",
    ["tree.ski_1.name"]   = "技能加速",
    ["tree.ski_1.desc"]   = "所有技能冷却 -10%",
    ["tree.ski_2.name"]   = "延时",
    ["tree.ski_2.desc"]   = "技能持续时间 +20%",
    ["tree.ski_3.name"]   = "双槽强化",
    ["tree.ski_3.desc"]   = "Q/E 技能槽各额外获得一个备用槽位",
}
