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
    ["menu.start"]       = "按 Enter 开始游戏",

    -- 结算
    ["gameover.title"]   = "GAME OVER",
    ["gameover.hint"]    = "按 Enter 返回菜单",

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

    -- Debug 面板
    ["debug.title"]      = "[DEBUG]",

    -- 背包界面
    ["bag.title"]              = "◈  背包  ◈",
    ["bag.empty"]              = "（空）",
    ["bag.hint.browse"]        = "方向键 移动光标  |  Enter 拾起移动  |  ESC 关闭",
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
}
