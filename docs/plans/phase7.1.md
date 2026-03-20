# Phase 7.1 开发计划 — 武器融合 & 单元测试框架

> **状态：✅ 已完成 (2026-03-20)**
> Phase 7 完成后的补充阶段，包含武器融合（原 Phase 7.5）与自动化测试基础设施。

---

## 一、武器融合（Weapon Fusion）

> 从 Phase 7.5 前移，作为本阶段主要玩法内容。

### 1.1 触发方式（玩家主动拖拽融合）

玩家在背包界面**手动将两把武器拖到相邻/重叠位置**触发融合检测，而非系统自动弹出：

1. **BROWSE 模式**：玩家用 Enter 拾起一把武器，进入 PLACE 模式拖动
2. **放置目标格已被另一把武器占据**（冲突格）时：
   - 检测这两把武器是否构成融合配方
   - 若**匹配配方** → 不执行普通放置，改为弹出**融合预览界面**
   - 若**不匹配** → 维持现有冲突提示（红色高亮），不可放置
3. **融合预览界面**（新增 `MODE_FUSION` 覆盖层）：
   - 显示：原材料 A + 原材料 B → 融合结果武器的名称、属性、外观
   - 操作：**Enter 确认融合**（消耗 A、B，生成结果武器放入背包）/ **ESC 取消**（A 放回原位）

### 1.2 配方设计原则
- 配方为**无序匹配**（A+B 等同于 B+A）
- 同一武器不与自身融合
- 融合结果武器为新的 configId（需在 `config/weapons.lua` 补充）

### 1.3 新建文件
- **`config/fusion.lua`** — 融合配方表
  ```lua
  { ingredients = {"pistol", "smg"}, result = "dual_pistol" }
  ```
- **`src/systems/fusion.lua`** — 融合查询与执行逻辑
  - `Fusion.findRecipe(configIdA, configIdB)` → 返回匹配的配方，或 nil
  - `Fusion.apply(bag, weaponA, weaponB, recipe)` → 移除 A、B，生成结果武器并尝试放入背包

### 1.4 修改文件
- **`src/states/bagUI.lua`**：
  - PLACE 模式放置时检测冲突格是否触发融合
  - 新增 `MODE_FUSION` 子状态，展示融合预览并等待玩家确认/取消
- **`config/i18n/zh.lua`** — 新增融合相关文本 key（预览标题、确认/取消提示等）

---

## 二、单元测试框架

> 目标：让 Claude 能在终端直接运行测试，验证游戏逻辑（不依赖 Love2D 图形窗口）。

### 2.1 技术方案
- **测试运行器**：使用 [busted](https://lunarmodules.github.io/busted/)（Lua 主流 BDD 测试框架）
  - 安装：`luarocks install busted`
  - 运行：`busted tests/`
- **Mock Love2D**：在 `tests/mock/` 下提供 `love` 全局 stub，屏蔽图形依赖
- **测试目录**：`tests/` 与 `src/`、`config/` 平级

### 2.2 目录结构
```
tests/
├── mock/
│   └── love.lua          -- love.* API 的空 stub（graphics、timer 等）
├── systems/
│   ├── test_bag.lua       -- Bag 放置/移除/边界测试
│   ├── test_adjacency.lua -- 相邻增益计算测试
│   └── test_synergy.lua   -- 羁绊激活/重算测试
├── entities/
│   └── test_weapon.lua    -- 武器有效属性方法测试
└── run.sh                 -- 一键运行所有测试的脚本
```

### 2.3 初版测试用例覆盖
#### `test_weapon.lua`
- `getEffectiveDamage` 含 adjBonus + synergyBonus
- `getEffectiveAttackSpeed` / `getEffectiveRange` / `getEffectiveBulletSpeed`
- `tickAttack` 使用有效射速计算间隔

#### `test_bag.lua`
- `canPlace` 越界 / 冲突检测
- `place` → `getAllWeapons` 正确返回
- `remove` → 武器从网格清除
- `expand` 扩展后旧武器位置不变

#### `test_adjacency.lua`
- 两武器相邻 → adjBonus 正确累加
- 同一武器不与自身相邻
- 移除一把武器后 adjBonus 归零
- 多武器多邻接关系叠加

#### `test_synergy.lua`
- 持有 pistol + smg → rapid_duo 激活，_synergyBonus 正确写入
- 只有 pistol → 不激活
- 移除 smg → 羁绊清除，_synergyBonus 归零
- 多羁绊同时激活不互相干扰

### 2.4 新建文件
| 文件 | 说明 |
|------|------|
| `tests/mock/love.lua` | Love2D API stub |
| `tests/systems/test_bag.lua` | Bag 测试 |
| `tests/systems/test_adjacency.lua` | 相邻增益测试 |
| `tests/systems/test_synergy.lua` | 羁绊系统测试 |
| `tests/entities/test_weapon.lua` | 武器实体测试 |
| `tests/run.sh` | 一键测试脚本 |

### 2.5 验收标准
```bash
$ bash tests/run.sh
# 期望输出：所有测试 PASS，0 failures
```

---

## 三、开发顺序建议

1. **先搭测试框架**（安装 busted、写 mock、写 bag 测试确认框架可用）
2. 补充 adjacency / synergy / weapon 测试（覆盖 Phase 7 核心逻辑）
3. 再实现武器融合，并为融合逻辑补充对应测试

---

## 四、关键文件路径

| 文件 | 操作 |
|------|------|
| `config/fusion.lua` | **新建** |
| `src/systems/fusion.lua` | **新建** |
| `src/states/bagUI.lua` | 修改（融合 UI） |
| `config/i18n/zh.lua` | 修改（融合文本） |
| `tests/` 目录 | **新建**（单元测试框架） |
