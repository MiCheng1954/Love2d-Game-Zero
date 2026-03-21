# Phase 10 开发计划 — 结算、传承与复活

> 更新日期：2026-03-22
> 前置：Phase 9（Boss 系统、胜利条件）已完成

## 目标
打通「局内结束 → 结算 → 传承选择 → 新局开始」的完整循环，实现复活机制和结算统计界面。

---

## 一、当前状态

Phase 9 完成后，胜利/死亡都跳转同一个 `gameover` 状态，目前只有：
- 金色胜利标题 / 红色 GAME OVER 文字
- 按 Enter 返回主菜单

**缺少：**
- 结算统计数据（存活时长、击杀数、等级、激活羁绊等）
- 传承技能选择流程
- 复活机制

---

## 二、功能模块

### 2.1 结算统计（必做）
在 `game.lua` 中收集并透传本局数据到 gameover：

| 统计项 | 来源 |
|--------|------|
| 存活时长 | `_rhythm:getElapsed()` |
| 最终等级 | `_player:getLevel()` |
| 总击杀数 | 新增计数器 `_killCount` |
| 收集灵魂总量 | `_player:getSouls()` |
| 激活的武器羁绊 | `bag._activeSynergies` |
| 是否胜利 | `_victory` |
| Boss 击杀列表 | 新增 `_killedBosses` 列表 |

**gameover.lua** 重构，显示统计数据表，胜利/死亡分别渲染：
- 胜利：金色标题 + 完整统计 + 传承技能选择入口
- 死亡：红色标题 + 完整统计 + 传承技能选择入口

### 2.2 复活机制（必做）
- 玩家有 `_revives = 1` 复活次数（默认1次）
- 死亡时：若还有复活次数 → 弹出「复活 or 传承」选择界面（新状态 `src/states/reviveUI.lua`）
  - 选择**复活**：HP 恢复50%，2 秒无敌帧，继续游戏
  - 选择**传承/结算**：进入传承流程
- 死亡时：若无复活次数 → 直接进入传承流程

### 2.3 传承技能系统（必做）
每局结算时生成 1~3 个传承技能候选，玩家选一个携带至下一局。

**传承技能生成规则：**
- 从本局持有的技能中随机抽取（同系列技能优先提炼出更强版本）
- 若本局没有技能，则从全局传承技能池随机生成
- 每局最多保留 1 个传承技能（新选择覆盖旧的，不累积）

**传承技能候选池（初版）：**

| 传承 ID | 效果 |
|---------|------|
| `legacy_speed` | 初始移速永久 +15 |
| `legacy_hp` | 最大 HP 永久 +30 |
| `legacy_attack` | 攻击力永久 +8 |
| `legacy_crit` | 暴击率永久 +5% |
| `legacy_cooldown` | 所有技能 CD 缩短 10% |
| `legacy_pickup` | 拾取范围永久 +40 |
| `legacy_exp` | 经验获取永久 +20% |
| `legacy_revive` | 下局额外获得 1 次复活机会 |

**持久化：** `data/legacy.json`（写入选择结果，下次开局读取）

**新局生效：**
- `game.lua enter()` 读取 `data/legacy.json`
- 将传承效果应用到玩家初始属性
- 技能栏中传承技能标注「传承」角标

### 2.4 传承选择界面（必做）
新建 `src/states/legacySelect.lua`：
- 展示 3 张候选卡片（上下键选择，Enter 确认）
- 每张卡片显示：传承名称、效果描述、视觉图标（代码绘制）
- 确认后写入 `data/legacy.json`，跳转主菜单

---

## 三、文件汇总

| 文件 | 操作 | 内容 |
|------|------|------|
| `src/states/gameover.lua` | 重写 | 胜利/死亡统计界面，展示本局数据 |
| `src/states/reviveUI.lua` | 新建 | 复活/传承二选一界面（overlay push） |
| `src/states/legacySelect.lua` | 新建 | 传承技能三选一界面 |
| `src/systems/legacyManager.lua` | 新建 | 传承技能读写、下局应用 |
| `config/legacy.lua` | 新建 | 传承技能候选池配置 |
| `data/legacy.json` | 新建（运行时） | 传承技能持久化存储 |
| `src/entities/player.lua` | 修改 | 新增 `_revives` 字段、复活逻辑、传承效果应用 |
| `src/states/game.lua` | 修改 | 收集统计数据，死亡走新流程，传入统计到 gameover |
| `config/i18n/zh.lua` | 修改 | 传承技能名称/描述，复活界面文本 |

---

## 四、设计决策记录

- **传承不累积**：每局只能带 1 个，避免指数级变强破坏平衡
- **复活是局内资源**，可被局内事件追加，不与传承挂钩
- **结算统计先做，传承系统后做**，两者可独立合并
- **gameover 传入数据结构**：
  ```lua
  StateManager.switch("gameover", {
      isVictory   = true/false,
      elapsed     = _rhythm:getElapsed(),
      level       = _player:getLevel(),
      killCount   = _killCount,
      souls       = _player:getSouls(),
      synergies   = bag._activeSynergies,
      killedBosses = _killedBosses,
  })
  ```

---

## 五、开发顺序建议

1. `game.lua` 补充统计收集 + 传入 gameover data
2. `gameover.lua` 重写：展示统计数据（胜利/死亡两套画面）
3. `config/legacy.lua` 传承技能配置池
4. `src/systems/legacyManager.lua` 读写逻辑
5. `src/states/legacySelect.lua` 传承选择界面
6. `player.lua` 下局传承效果应用
7. `src/states/reviveUI.lua` 复活二选一（可最后做）
