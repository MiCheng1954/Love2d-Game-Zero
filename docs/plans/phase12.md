# Phase 12 开发计划 — 场景扩展

## 目标
实现多场景框架，设计并实现第一批特色场景，每个场景有独特的机制和视觉风格。

---

## 一、主要模块

### 1.1 场景基类（BaseScene）
- 抽象出场景通用接口：背景绘制、障碍物、特殊机制钩子
- `scene:onEnter()`、`scene:onExit()`、`scene:update(dt)`、`scene:draw()`
- 场景可注入自定义生成规则（覆盖 RhythmController 的默认参数）
- 场景可定义自己的胜利/失败条件扩展

### 1.2 场景类型（初版规划）
根据需求文档，场景类型涵盖：

**场景 1 — 基础平原（当前场景升级版）**
- 无限延伸地图
- 障碍物随机分布（石块、树木，仅视觉）
- 作为新手默认场景

**场景 2 — 封闭竞技场**
- 固定边界，玩家无法出界
- 敌人从四周墙壁涌入
- 节奏更紧凑，空间压迫感强

**场景 3 — 地下城（待设计）**
- 房间+走廊结构
- 需确认具体机制

### 1.3 场景选择
- 主菜单或局开始时选择场景
- 每个场景有独立的难度曲线配置

### 1.4 场景配置（config/scenes.lua）
```lua
{
  id = "arena",
  nameKey = "scene.arena.name",
  descKey = "scene.arena.desc",
  bounds = { x=0, y=0, w=2560, h=1440 },  -- nil=无限延伸
  spawnOverride = { ... },  -- 覆盖节奏控制器参数（可选）
  onEnterEffect = function() ... end,
}
```

---

## 二、文件汇总（预估）

| 文件 | 操作 | 内容 |
|------|------|------|
| `src/systems/sceneManager.lua` | 新建 | 场景加载/切换管理 |
| `src/scenes/baseScene.lua` | 新建 | 场景基类 |
| `src/scenes/plains.lua` | 新建 | 基础平原场景 |
| `src/scenes/arena.lua` | 新建 | 封闭竞技场场景 |
| `config/scenes.lua` | 新建 | 场景配置表 |
| `src/states/game.lua` | 修改 | 接入场景系统 |

---

## 三、待确认事项
- 初版需要实现几个场景
- 各场景的具体特色机制（障碍物、边界规则、特殊敌人等）
- 场景是否影响掉落物类型
- 是否有场景专属 Boss
