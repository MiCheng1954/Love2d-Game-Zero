# Phase 8 开发计划 — 技能系统

## 目标
实现主动/被动技能池，支持角色专属技能，建立技能羁绊机制。

---

## 一、主要模块

### 1.1 技能分类
- **主动技能**：需要触发条件（如每隔N秒、击杀N个敌人后），自动执行效果
- **被动技能**：持有即生效，修改角色属性或战斗规则
- **通用技能池**：所有角色都可在升级/拾取中获得
- **角色专属技能**：特定角色才能获得，需预留扩展接口

### 1.2 技能配置（config/skills.lua）
```lua
{
  id = "speed_burst",
  type = "active",           -- active / passive
  nameKey = "skill.speed_burst.name",
  descKey = "skill.speed_burst.desc",
  maxLevel = 3,
  levelBonus = { ... },
  trigger = { type="interval", value=8 },  -- 每8秒触发
  effect = function(player, level) ... end,
}
```

### 1.3 玩家技能槽
- 玩家持有技能列表（无格子限制，仅列表）
- 主动技能各自维护独立计时器
- 升级时可获得新技能或升级已有技能（接入现有升级系统）

### 1.4 技能羁绊
- 同时拥有特定技能组合时激活羁绊
- 复用 Phase 7 的羁绊框架（或合并到统一羁绊系统）

### 1.5 升级系统接入
- `config/upgrades.lua` 技能大类子选项实装
- 随机从技能池中抽取玩家未持有或可升级的技能
- `canShow` 过滤已满级技能

---

## 二、文件汇总（预估）

| 文件 | 操作 | 内容 |
|------|------|------|
| `config/skills.lua` | 新建 | 技能配置表（通用池） |
| `src/systems/skillManager.lua` | 新建 | 技能持有、计时、触发管理 |
| `src/entities/player.lua` | 修改 | 新增技能槽，接入 skillManager |
| `src/states/game.lua` | 修改 | 每帧更新主动技能计时器 |
| `config/upgrades.lua` | 修改 | 技能大类子选项实装 |
| `config/i18n/zh.lua` | 修改 | 补充技能文本 key |

---

## 三、待确认事项
- 初版技能的具体种类和数量
- 主动技能的触发类型（时间间隔/击杀数/受伤触发等）
- 技能羁绊是否与武器羁绊共用同一套框架
- 角色专属技能的设计（Phase 8 内实装还是预留接口）
