# Phase 12 开发计划 — 场景扩展

## 目标
实现多场景框架，设计并实现 3 个特色场景，每个场景有独特的机制和视觉风格。
场景在主菜单选择，game.lua 接入场景系统。

---

## 设计决策（已确认）

| 问题 | 决策 |
|------|------|
| 场景数量 | 3 个（平原 / 竞技场 / 地下城） |
| 竞技场边界 | 边界 + 受伤（50px 内 5/s，0px 处 20/s） |
| 掉落 & Boss | 掉落不同，竞技场专属 Boss（近战冲锋型） |
| 场景入口 | 主菜单 → 开始游戏 → 场景选择界面 |

---

## 一、主要模块

### 1.1 场景基类（BaseScene）
- 抽象出场景通用接口：背景绘制、障碍物、特殊机制钩子
- `scene:onEnter(player)`、`scene:onExit()`、`scene:update(dt, player)`、`scene:draw(camera)`
- 场景可注入自定义生成规则（覆盖 RhythmController 默认参数）
- 场景可定义边界约束（nil = 无限延伸）
- 场景可定义专属 Boss 池覆盖（nil = 使用全局 Boss 池）

### 1.2 场景管理器（SceneManager）
- `SceneManager.set(sceneId)`：设置当前场景
- `SceneManager.get()` → scene 实例
- `SceneManager.current()` → sceneId 字符串
- game.lua 每帧委托 `scene:update()` / `scene:draw()`

### 1.3 场景类型

**场景 1 — 基础平原（plains）**
- 无限延伸地图（bounds = nil）
- 随机视觉障碍物（石块/树木，不阻挡移动）
- 默认难度曲线（沿用现有 RhythmController）
- Boss 池：全局 4 个 Boss
- 掉落：标准比例

**场景 2 — 封闭竞技场（arena）**
- 固定边界 2560×1440
- 边界受伤机制：边界 50px 内持续受伤 5/s，0px 处 20/s
- 敌人从四面墙壁随机点生成（而非屏幕外圆圈）
- 节奏更紧凑（间隔缩短 20%）
- 专属 Boss：冲锋者（近战高速冲锋，血量 ×1.5，巡逻→冲锋→蓄力循环）
- 掉落：灵魂 ×1.3（高压补偿）

**场景 3 — 地下城（dungeon）**
- Phase 12 只实现框架骨架（房间+走廊数据结构 + 基础绘制）
- 具体探索机制留 Phase 12.x 讨论后实装
- 本 Phase 目标：可进入、可战斗、地图可见即可

### 1.4 场景选择界面（sceneSelect.lua）
- 主菜单「开始游戏」→ 推入场景选择界面
- 显示场景卡片（名称 / 描述 / 难度标签）
- ← → 切换，Enter 确认，ESC 返回主菜单

### 1.5 竞技场专属 Boss — 冲锋者（Charger）
- 3 阶段行为：巡逻（随机游走）→ 蓄力（停止，瞄准玩家 1.5s）→ 冲锋（高速直线 800px/s，碰墙停止）
- HP：3000，伤害：60/次接触，速度冲锋期 800，巡逻期 120
- 死亡：爆炸分裂 6 个小型追击体

---

## 二、文件汇总

| 文件 | 操作 | 内容 |
|------|------|------|
| `src/systems/sceneManager.lua` | 新建 | 场景注册/切换管理 |
| `src/scenes/baseScene.lua` | 新建 | 场景基类（接口定义） |
| `src/scenes/plains.lua` | 新建 | 基础平原场景 |
| `src/scenes/arena.lua` | 新建 | 封闭竞技场（边界+受伤） |
| `src/scenes/dungeon.lua` | 新建 | 地下城骨架（本 Phase 只实现框架） |
| `config/scenes.lua` | 新建 | 场景配置表（id/name/desc/bounds/spawnOverride/bossPool） |
| `src/states/sceneSelect.lua` | 新建 | 场景选择界面（主菜单→进入游戏中间层） |
| `src/entities/boss_charger.lua` | 新建 | 竞技场专属 Boss — 冲锋者 |
| `src/states/menu.lua` | 修改 | 「开始游戏」→ push sceneSelect 而非直接 switch game |
| `src/states/game.lua` | 修改 | 接入 SceneManager：enter 时加载场景，update/draw 委托场景 |
| `config/i18n/zh.lua` | 修改 | 新增场景相关文本（3 个场景名/描述、Boss 名） |
| `main.lua` | 修改 | 注册 sceneSelect 状态 |

**合计：8 新建 + 4 修改 = 12 个文件**

---

## 三、开发顺序

1. **Step 1**：新建 `config/scenes.lua` + `src/scenes/baseScene.lua` — 数据结构先行
2. **Step 2**：新建 `src/systems/sceneManager.lua` — 场景注册/切换核心
3. **Step 3**：新建 `src/scenes/plains.lua` — 平原场景（当前地图规范化）
4. **Step 4**：新建 `src/scenes/arena.lua` — 竞技场 + 边界受伤机制
5. **Step 5**：修改 `src/states/game.lua` — 接入 SceneManager，委托 update/draw
6. **Step 6**：新建 `src/states/sceneSelect.lua` + 修改 `src/states/menu.lua` — 场景选择UI
7. **Step 7**：新建 `src/entities/boss_charger.lua` — 竞技场专属 Boss
8. **Step 8**：新建 `src/scenes/dungeon.lua` — 地下城骨架框架
9. **Step 9**：补全 `config/i18n/zh.lua` 文本 + `main.lua` 注册

---

## 四、特别注意事项

1. **Spawner 生成位置适配**：竞技场场景需要修改生成点为「墙壁边缘随机点」而非「屏幕外圆圈」，需给 Spawner 暴露 spawnOverride 接口
2. **Boss 池覆盖**：game.lua 的 Boss 触发逻辑当前硬编码使用 `config/bosses.lua`，需支持场景覆盖 Boss 池
3. **边界受伤不触发无敌帧**：竞技场边界受伤属于「环境伤害」，不应消耗 `invincible` Buff，需单独处理
4. **地下城 Phase 12 只做框架**：房间数据结构 + 基础绘制，探索机制 Phase 12.x 讨论后实装
5. **冲锋者冲锋期碰墙判断**：需对场景边界做射线检测，不能用现有圆形碰撞

---

## 五、测试计划

```bash
python tests/run_lupa.py   # 目标：147 passed（不新增测试文件，纯集成验证）

# 游戏内验证：
# 1. 主菜单 → 场景选择 → 平原，确认与现有游戏一致
# 2. 主菜单 → 场景选择 → 竞技场，确认边界受伤、专属Boss、灵魂1.3x
# 3. 主菜单 → 场景选择 → 地下城，确认可进入+可战斗
# 4. F12 Bug 反馈仍正常工作
```
