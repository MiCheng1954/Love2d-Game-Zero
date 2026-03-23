> 更新日期：2026-03-24（QA 确认版 v2 — 新增通用机制树）

# Phase 13 开发计划 — 局外系统

## 目标
实现局外持久成长体系：双轨成长系统（通用加成 + 角色专属技能树）、3个差异化角色、里程碑系统、成就系统框架。

---

## 一、核心架构：双轨成长系统

### 轨道一 — 通用永久加成（所有角色共享）
- **货币来源**：每局结算按表现自动获得成长点数
  - 击杀数 / 存活时间 / Boss 击败数 各有权重
- **花费方式**：在局外界面花点数升级通用属性 **或** 解锁通用机制树节点（共用同一货币）
- **属性升级**（Tab 1 左侧）：攻击力 / 移速 / 最大HP / 暴击率 / 拾取范围 / 经验倍率，各 3~5 档
- **通用机制树**（Tab 1 右侧）：星形扩散图，5 个维度 × 3 层 = 15 节点，所有角色共用
  - **攻击维度**：暴击爆发 / 击杀连击 / 穿透
  - **生存维度**：受伤减速 / 回血 / 护甲
  - **经济维度**：经验加成 / 灵魂获取 / 点数产出
  - **武器装备维度**：武器冷却 / 弹速 / 融合强化
  - **技能维度**：技能冷却 / 技能强度 / 双技能槽
- **数据存储**：`data/progression.json`

### 轨道二 — 角色专属技能树（各角色独立）
- **货币来源**：完成与角色特性绑定的里程碑任务，获得该角色的里程碑点数
- **树形态**：分支树（主干 + 分支，前置解锁后续）
- **每角色**：2-3 条主干，每条主干 3-4 个节点
- **数据存储**：`data/progression.json` 内按 characterId 分表

---

## 二、角色系统

### 角色列表（共 3 个，初始全部可选）

| characterId | 显示名 | 风格 | 专属F技能 | 专属升级池方向 |
|-------------|--------|------|----------|-------------|
| `engineer` | 工程师 | 科技 / 超载 | overload（武器射速翻倍） | 武器系、科技羁绊、射速强化 |
| `berserker` | 狂战士 | 近身爆发 / 高风险高回报 | 血越低攻击越高 / 冲刺反伤 | 暴击系、重型羁绊、HP换伤害 |
| `phantom` | 幽灵 | 速度 / 闪避 | 瞬移强化 / 减速领域扩大 | 速射系、游击羁绊、CD缩减 |

### default → engineer 迁移
- `player.characterId = "default"` → `"engineer"`
- `config/skills.lua` 中 `characterId = "default"` → `"engineer"`
- i18n 新增角色显示名

### 各角色基础属性差异（待开发阶段确认数值）
- **工程师**：标准基础属性（沿用现有 default 数值）
- **狂战士**：HP+50%，速度-10%，攻击+30%
- **幽灵**：速度+40%，HP-20%，CD缩减+20%

---

## 三、里程碑系统

### 设计原则
- 里程碑目标与角色特性强绑定（狂战士侧重击杀/低血量，幽灵侧重速度/闪避）
- 达成里程碑 → 获得该角色的里程碑点数 → 解锁专属分支树节点

### 里程碑示例（开发阶段细化）

| 角色 | 里程碑目标 | 点数奖励 |
|------|----------|---------|
| 工程师 | 单局内触发超载 10 次 | +3 |
| 工程师 | 同时拥有 6 把不同武器 | +5 |
| 狂战士 | 在 HP < 30% 时存活 5 分钟 | +5 |
| 狂战士 | 单局击杀 500 个敌人 | +3 |
| 幽灵 | 单局使用瞬移 20 次 | +3 |
| 幽灵 | 在竞技场存活 15 分钟 | +5 |

### 技能树节点示例（开发阶段细化）

**工程师 — 超载主干：**
超载时长+1s → 超载期间获得护盾 → 超载冷却缩短30%

**狂战士 — 血怒主干：**
HP<50%时攻击+15% → HP<30%时攻击+30% → 死亡前一次触发无敌1s

**幽灵 — 疾影主干：**
瞬移距离+30% → 瞬移后2s内攻速+50% → 瞬移CD缩短40%

---

## 四、成就系统（框架）

### Phase 13 目标：只建框架，不填内容
- `src/systems/achievementManager.lua`：条件注册 / 检测 / 解锁接口
- `config/achievements.lua`：空配置表，预留结构，后续快速添加
- `src/states/achievements.lua`：成就列表 UI（push/pop），显示已解锁 / 未解锁
- 成就数据：`data/achievements.json`

### 成就管理器接口
```lua
AchievementManager.register(id, condition, reward)  -- 注册成就
AchievementManager.notify(event, data)               -- 游戏事件通知
AchievementManager.getAll()                          -- 获取全部（供UI）
AchievementManager.isUnlocked(id)                    -- 查询解锁状态
```

---

## 五、主菜单扩展

- **角色选择**：开始游戏 → 角色选择 → 场景选择 → 进入游戏
- **局外成长**：主菜单新增「成长」入口 → 通用加成商店 + 角色技能树
- **成就**：主菜单新增「成就」入口 → 成就列表
- **图鉴**（可选，后续讨论）

---

## 六、文件汇总

| 文件 | 操作 | 内容 |
|------|------|------|
| `config/characters.lua` | 新建 | 3 个角色配置（基础属性 / 专属技能 / 里程碑定义 / 技能树结构） |
| `config/achievements.lua` | 新建 | 成就配置表（空壳，预留结构） |
| `src/systems/progressionManager.lua` | 新建 | 读写 progression.json，通用加成 + 角色树数据管理 |
| `src/systems/milestoneManager.lua` | 新建 | 里程碑条件注册、事件通知、点数结算 |
| `src/systems/achievementManager.lua` | 新建 | 成就框架（注册/检测/解锁/持久化） |
| `src/states/characterSelect.lua` | 新建 | 角色选择界面（主菜单 → 角色选择 → 场景选择） |
| `src/states/progression.lua` | 新建 | 局外成长界面（通用加成商店 + 角色分支树 UI） |
| `src/states/achievements.lua` | 新建 | 成就列表界面 |
| `src/entities/player.lua` | 修改 | 接入 character config，从配置初始化角色属性 |
| `src/states/game.lua` | 修改 | 结算时计算成长点数；里程碑事件通知 |
| `src/states/gameover.lua` | 修改 | 结算界面显示本局获得的成长点数 |
| `src/states/menu.lua` | 修改 | 新增成长/成就入口；开始游戏走角色选择 |
| `config/skills.lua` | 修改 | `characterId = "default"` → `"engineer"` |
| `config/i18n/zh.lua` | 修改 | 角色名/描述、里程碑文本、成长界面文本、成就框架文本 |
| `data/progression.json` | 新建 | 局外成长持久化（通用加成档位 + 各角色树解锁状态） |
| `data/achievements.json` | 新建 | 成就解锁持久化 |

---

## 七、开发顺序

1. **角色配置 + 迁移**：`config/characters.lua` + `default→engineer` 重命名 + 新增 berserker/phantom 配置
2. **角色选择界面**：`characterSelect.lua`，接入主菜单流程
3. **进度管理器**：`progressionManager.lua`，读写 progression.json
4. **里程碑系统**：`milestoneManager.lua` + 接入 game.lua 事件通知
5. **局外成长界面**：`progression.lua`（通用加成商店 + 角色分支树 UI）
6. **结算点数**：`gameover.lua` 显示本局获得点数
7. **成就框架**：`achievementManager.lua` + `achievements.lua` UI
8. **主菜单扩展**：新增成长/成就入口
9. **单元测试**：progressionManager + milestoneManager 测试

---

## 八、待细化事项（开发中逐步与冰冰确认）

- 各角色分支树的完整节点内容和数值
- 里程碑的完整条件列表和点数权重
- 通用加成的具体档位数值和上限
- 结算点数公式（击杀/存活/Boss各自权重）
- 角色解锁门槛（暂不设置，后续讨论）
