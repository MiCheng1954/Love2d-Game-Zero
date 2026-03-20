# Phase 7.2 开发日志 — Tag 羁绊系统重设计 & Bug 修复

> **状态：✅ 已完成 (2026-03-21)**
> 将原有「武器组合触发」羁绊系统重设计为 **Tag 驱动的全局被动技能系统**；
> 同步修复 Bug #14–#19，合并 Bug/需求反馈面板，新增 6 把基础武器。

---

## 一、Tag 羁绊系统（核心重设计）

### 1.1 设计思路

原有羁绊（`rapid_duo` / `heavy_strike` / `precision_pair`）基于「持有特定武器组合」触发，
效果局限于武器自身 `_synergyBonus`，与融合系统高度重叠、扩展性差。

7.2 重设计为：
- 每把武器携带 **1–3 个流派 tag**（`速射` / `精准` / `重型` / `爆炸` / `科技` / `游击`）
- 背包中凑齐 **N 把同 tag 武器** → 激活对应档次的羁绊（每 tag 两档：×2 / ×3）
- 效果作用于 **玩家全局属性**（移速/暴击/伤害/HP 等），等同于被动技能
- `isFused=true` 的融合武器**不计入** tag 计数，避免融合后「白送」羁绊

### 1.2 6 种流派 Tag

| Tag | 主题 |
|-----|------|
| `速射` | 快速射击流派 |
| `精准` | 高单发/远程流派 |
| `重型` | 高伤害/重武器流派 |
| `爆炸` | 弹速/爆炸流派 |
| `科技` | 能量武器流派 |
| `游击` | 近程高爆发流派 |

### 1.3 羁绊档次（每 tag 2 档）

| Tag | T1（×2） | 效果 | T2（×3） | 效果 |
|-----|---------|------|---------|------|
| 速射 | 急速光环 | `speed+25` | 弹雨狂潮 | `speed+50, damage+8` |
| 精准 | 精准感知 | `critChance+8%` | 致命精度 | `critChance+15%, critMult+40%` |
| 重型 | 重装压制 | `damage+15` | 铁甲破阵 | `damage+30, maxHP+30` |
| 爆炸 | 弹道强化 | `bulletSpeed+80` | 爆破先锋 | `bulletSpeed+160, damage+10` |
| 科技 | 能量感应 | `pickupRange+60` | 科技领域 | `pickupRange+120, expMult+25%` |
| 游击 | 战场直觉 | `maxHP+25` | 游击突袭 | `maxHP+50, speed+20` |

---

## 二、新增 6 把基础武器

| configId | 中文名 | Tags | 格子 | 特色 |
|---------|--------|------|------|------|
| `burst_pistol` | 爆发手枪 | 速射/精准 | 1×1 | 高射速精准型 |
| `grenade_launcher` | 榴弹发射器 | 爆炸/重型 | 1×2 | 高伤爆炸型 |
| `double_barrel` | 双管猎枪 | 重型/游击 | 1×2 | 近程暴力型 |
| `gatling` | 加特林 | 速射/重型 | 2×2 | 持续输出型 |
| `plasma_pistol` | 等离子手枪 | 科技/爆炸 | 1×1 | 科技爆炸型 |
| `rail_rifle` | 磁轨步枪 | 精准/科技 | 1×3 | 超远程穿透型 |

> 新武器均**不可融合**（无对应配方），可在升级奖励中获取。

---

## 三、Bug 修复记录（#14–#19）

### Bug #14 — 武器等级标签位置异常（已在上次提交修复）
- 等级标签改为显示在武器视觉中心

### Bug #15 — 激活羁绊未显示效果描述
- **修复**：`_drawDetail()` 激活档位现在同时显示 `descKey` 文本（在羁绊名称下方）

### Bug #16 — 融合预览未显示结果武器 Tags
- **修复**：`MODE_FUSION` 预览界面新增结果武器 tags 展示行

### Bug #17 — 武器详情没有 Tag 展示
- **修复**：`_drawDetail()` 新增「标签」区块，遍历该武器的所有 tag，显示进度条与羁绊状态

### Bug #18 — 独立羁绊面板布局混乱，信息重复
- **修复**：将羁绊信息整合进武器详情面板（右侧），`_drawSynergies()` 改为 no-op，删除独立面板

### Bug #19 — 融合预览显示错误武器尺寸（恒为 2 列）
- **根本原因**：`#shape[1]` 取的是第一个格子 `{row, col}` 的长度，恒为 2，而非实际列数
- **所有三把融合武器均受影响**：
  | 武器 | 旧显示（错误） | 正确尺寸 |
  |------|-------------|---------|
  | dual_pistol | 2行×2列 | 1行×2列 |
  | siege_cannon | 4行×2列 | 2行×2列 |
  | railgun | 4行×2列 | 1行×4列 |
- **修复**：遍历所有格子取 `maxRow` / `maxCol`，`rows = maxR+1, cols = maxC+1`

---

## 四、开发者反馈面板合并（devReport）

原有 `bugReport.lua` 和 `featureRequest.lua` 合并为单一 `devReport.lua`：

- **入口**：F12（任意状态，排除 Console 和 DevReport 自身）
- **三阶段流程**：
  1. `PHASE_DESC` — 输入文字描述（支持中文 UTF-8）
  2. `PHASE_PRIORITY` — 按 1/2/3 选优先级（低/中/高）
  3. `PHASE_TYPE` — 按 1=Bug / 2=需求 选类型
  4. `PHASE_DONE` — 显示保存确认，1.5 秒后自动关闭
- **存储**：Bug → `data/bugs.json` + 日志快照；需求 → `data/features.json` + `data/features.md`
- **边框颜色**：DONE 阶段根据类型变色（红=Bug，蓝=需求）

> 移除：`src/states/bugReport.lua`（功能已合并）
> 保留：`src/states/featureRequest.lua`（文件未删除，但不再注册/使用）

---

## 五、玩家属性系统扩展

新增字段以支持 Tag 羁绊效果：

| 字段 | 含义 |
|------|------|
| `player.critRate` | 暴击概率（0–1） |
| `player.critDamage` | 暴击伤害倍率 |
| `player.pickupRange` | 拾取感应半径 |
| `player.expMult` | 经验倍率 |

`game.lua` 每帧读取 `bag._playerSynergyBonus`（简称 psb），以增量缓存方式应用：
- `maxHP` / `pickupRange` / `expMult` 通过 `_psbXxxLast` 哨兵字段检测变化，避免每帧重复叠加
- `speed` / `damage` / `critChance` / `critMult` / `bulletSpeed` 每帧直接作为参数传入，不修改 player 基础属性

---

## 六、单元测试新增

### test_synergy.lua（完整重写）
16 个测试用例，覆盖：
- Tag 计数（4 个）：放置/移除武器后 `_tagCounts` 正确变化；`isFused` 武器跳过
- T1 激活 ×2（3 个）：速射/重型达到门槛激活；未达门槛不激活
- T2 激活 ×3 覆盖 T1（3 个）：T2 激活时 T1 不重复出现；移除后降级回 T1
- `playerSynergyBonus` 累加（4 个）：无羁绊全零；多 tag 同时激活正确叠加；移除清零
- `isFused` 跳过（2 个）：融合武器独占背包无羁绊；混合时只计非融合

### test_fusion.lua（新增 describe 块）
6 个新测试用例（Bug #19 专项）：
- 3 个验证正确算法对三把融合武器均返回正确尺寸
- 3 个反向验证旧 `#shape[1]` 算法在三把武器上均产生错误结果

**最终测试成绩：86 passed, 0 failed**

---

## 七、修改文件清单

| 文件 | 操作 | 说明 |
|------|------|------|
| `config/weapons.lua` | 修改 | 所有武器加 `tags` 字段；新增 6 把基础武器；融合武器加 `isFused=true` + `tags` |
| `config/synergies.lua` | **完整重写** | 6 tag 条目，每 tag 2 档（tiers 数组结构） |
| `config/fusion.lua` | 新建 | 武器融合配方表（3 个配方） |
| `config/i18n/zh.lua` | 修改 | 新增 6 把武器文本；12 个羁绊档位 key；6 个 tag 显示名；删除旧羁绊 key |
| `config/upgrades.lua` | 修改 | 新增 6 把武器到升级候选池 |
| `src/systems/synergy.lua` | **完整重写** | Tag 计数 + 最高满足档位激活 + `playerSynergyBonus` 累加 |
| `src/systems/fusion.lua` | 新建 | `findRecipe` / `apply` 融合逻辑 |
| `src/systems/adjacency.lua` | 新建 | 相邻增益计算（Phase 7 遗留，随本次一并提交） |
| `src/systems/bag.lua` | 修改 | `Bag.new()` 初始化 `_tagCounts` / `_playerSynergyBonus`；接入 Adjacency/Synergy |
| `src/entities/weapon.lua` | 修改 | `getEffectiveBulletSpeed(extraBulletSpeed)` 新增可选参数 |
| `src/entities/player.lua` | 修改 | `update(dt, extraSpeed)` / `_handleMovement` 支持外部速度加成 |
| `src/entities/projectile.lua` | 修改 | `onHit()` 支持 `_critDamage` 字段覆盖暴击倍率 |
| `src/states/game.lua` | 修改 | 每帧读取并应用 `psb`；暴击率/伤害/弹速/移速/拾取范围/经验倍率全部接入羁绊加成 |
| `src/states/bagUI.lua` | 修改 | `_drawDetail()` 新增 tag 进度条 + 羁绊状态；`_drawSynergies()` 改为 no-op；Bug#19 shape 尺寸修复；融合预览显示 tags |
| `src/states/devReport.lua` | **新建** | Bug/需求反馈三阶段面板（合并原两个面板） |
| `src/states/console.lua` | 修改 | 适配新武器 configId，支持通过控制台生成新武器 |
| `main.lua` | 修改 | 注册 `devReport`；F12 改为推送 `devReport`；移除 F11 |
| `tests/systems/test_synergy.lua` | **完整重写** | 16 个 Tag 羁绊测试用例 |
| `tests/systems/test_fusion.lua` | 修改 | 新增 6 个 Bug#19 shape 尺寸测试用例 |

---

## 八、验收验证步骤

1. **tag 计数**：控制台 `weapon pistol` 放入背包，调试面板 tagCounts = `速射:1 精准:1`
2. **T1 激活**：再放 `weapon smg`，`速射:2`，HUD 右上角出现「急速光环」，player.speed +25
3. **T2 覆盖**：再放 `weapon burst_pistol`，`速射:3`，HUD 显示「弹雨狂潮」（T1 消失）
4. **降级**：TAB 进背包移走 burst_pistol，`速射:2`，HUD 回到「急速光环」
5. **bag tag 进度**：TAB 打开背包，右侧详情面板显示各 tag 进度条与羁绊状态
6. **武器 tags 展示**：光标移到手枪，详情显示「[速射] [精准]」并附进度信息
7. **融合预览尺寸**：将手枪拖到冲锋枪上触发融合预览，`dual_pistol` 显示 1×2（不再误显 2×2）
8. **devReport**：F12 呼出反馈面板 → 输入描述 → 选优先级 → 选 Bug/需求 → 保存确认
9. **单元测试**：`python tests/run_lupa.py` → 86 passed, 0 failed
