--[[
    config/i18n/zh.lua
    中文文本配置表，包含游戏中所有中文字符串的 key-value 映射
    Phase 5.1：i18n 多语言支持基础
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
}
