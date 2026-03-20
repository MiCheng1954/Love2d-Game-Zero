# Phase 7 开发计划 — 相邻增益 & 武器羁绊

> **状态：✅ 已完成 (2026-03-20)**
> 武器融合推迟到 Phase 7.5。

## 已实现内容

### 一、相邻增益系统
- **触发规则**：两把武器任意格子水平/垂直相邻（共享边）即互相提供加成
- **双向互相**：A 给 B 提供 A 的 `adjacencyBonus`，B 给 A 提供 B 的 `adjacencyBonus`
- **重算时机**：每次 `bag:place()` / `bag:remove()` 末尾自动重算
- **缓存字段**：`weapon._adjBonus = { damage, attackSpeed, range, bulletSpeed }`

#### 各武器 adjacencyBonus
| 武器 | 提供给邻居的加成 | 主题 |
|------|----------------|------|
| pistol | `attackSpeed=0.15` | 精准训练 |
| shotgun | `damage=8` | 制止力 |
| smg | `attackSpeed=0.4` | 速射光环 |
| sniper | `range=60` | 远程感知 |
| cannon | `damage=12` | 重型弹药 |
| laser | `attackSpeed=0.2, range=20` | 精准能量 |

### 二、武器羁绊系统
- **触发规则**：背包中同时持有 `requires` 列出的所有武器，不限位置
- **效果字段**：`weapon._synergyBonus = { damage, attackSpeed, range }`
- **激活记录**：`bag._activeSynergies` 列表

#### 3 个初版羁绊
| ID | 需要武器 | 效果 |
|----|---------|------|
| rapid_duo | pistol + smg | pistol+0.5射速；smg+1.0射速+3伤害 |
| heavy_strike | shotgun + cannon | shotgun+20伤害；cannon+25伤害 |
| precision_pair | sniper + laser | sniper+100射程；laser+8伤害+0.5射速 |

### 三、新建/修改文件
| 文件 | 操作 |
|------|------|
| `config/weapons.lua` | 修改：新增 `adjacencyBonus` 字段 |
| `config/synergies.lua` | **新建**：3 个羁绊配置 |
| `src/entities/weapon.lua` | 修改：新增 bonus 字段和 effective 方法 |
| `src/systems/bag.lua` | 修改：接入 Adjacency/Synergy 计算 |
| `src/systems/adjacency.lua` | **新建**：相邻增益计算系统 |
| `src/systems/synergy.lua` | **新建**：羁绊计算系统 |
| `src/states/game.lua` | 修改：使用 effective 方法，调试面板显示羁绊 |
| `src/states/bagUI.lua` | 修改：详情面板显示加成，新增羁绊面板 |
| `config/i18n/zh.lua` | 修改：新增羁绊文本 key |

### 四、weapon 新增方法
- `weapon:getEffectiveDamage(playerAttack)` — 含 adjBonus + synergyBonus
- `weapon:getEffectiveAttackSpeed()` — 含 adjBonus + synergyBonus
- `weapon:getEffectiveRange()` — 含 adjBonus + synergyBonus
- `weapon:getEffectiveBulletSpeed()` — 含 adjBonus
- `weapon:tickAttack(dt)` — 使用 `getEffectiveAttackSpeed()` 计算间隔
- 融合后原材料武器销毁，新武器放入背包（需有空位或自动替换原位）
- 融合武器需扩充 `config/weapons.lua`，新增融合产物的配置

### 1.3 武器羁绊系统（Weapon Synergy）
- 背包中同时拥有特定武器组合时，激活羁绊效果
- 新建 `config/synergies.lua`：羁绊配置表
- 羁绊效果为全局 buff（不局限于相邻格）
- HUD/背包界面显示当前激活的羁绊

### 1.4 索敌逻辑升级
- 替换 `game.lua` 中的 `_findNearestEnemyInRange()` 占位实现
- 支持锁定策略：最近/最低血量/最高威胁
- 为 Phase 8 技能系统的索敌需求预留接口

---

## 二、文件汇总（预估）

| 文件 | 操作 | 内容 |
|------|------|------|
| `config/fusion.lua` | 新建 | 武器融合配方表 |
| `config/synergies.lua` | 新建 | 武器羁绊配置表 |
| `src/systems/adjacency.lua` | 新建 | 相邻增益计算系统 |
| `src/systems/fusion.lua` | 新建 | 融合检测与执行逻辑 |
| `src/systems/synergy.lua` | 新建 | 羁绊激活与效果应用 |
| `src/states/bagUI.lua` | 修改 | 显示相邻增益高亮、融合提示、羁绊信息 |
| `src/states/game.lua` | 修改 | 升级索敌逻辑，接入相邻增益/羁绊系统 |
| `config/weapons.lua` | 修改 | 新增融合产物武器配置 |

---

## 三、待确认事项
- 融合武器的种类和配方设计（需冰冰拍板）
- 相邻增益的具体数值和规则（是双向还是单向？）
- 羁绊激活条件（持有即激活 or 放在特定位置？）
- 索敌策略是否支持玩家手动切换
