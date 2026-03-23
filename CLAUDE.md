# CLAUDE.md — Zero 项目开发规范

> 每次会话开始时自动读取，用于恢复上下文、避免重复犯错。

---

## 一、项目基本信息

- **游戏类型**：幸存者类射击游戏（类 Vampire Survivors），俯视角，WASD 移动，自动攻击
- **技术栈**：Love2D 11.x + Lua 5.1（LuaJIT），窗口 1280×720
- **项目路径**：`D:\WorkSpace_Love2d\Zero`
- **当前进度**：Phase 10 已完成，下一阶段为 Phase 11（HUD 与 UI）

---

## 二、目录结构规范

```
Zero/
├── main.lua                  -- 程序入口，只负责初始化和 Love2D 回调注册
├── conf.lua                  -- 窗口配置
├── config/                   -- 纯数据配置，不含逻辑
│   ├── weapons.lua           -- 武器配置表（含 tags / shape / isFused 等字段）
│   ├── synergies.lua         -- Tag 羁绊配置（6 tag × 2 档）
│   ├── fusion.lua            -- 武器融合配方表
│   ├── upgrades.lua          -- 升级奖励配置
│   └── i18n/zh.lua           -- 中文文本配置（所有 UI 文本通过 T("key") 访问）
├── src/
│   ├── states/               -- 游戏状态（stateManager.lua 管理）
│   │   ├── stateManager.lua  -- 状态机，支持 push/pop 覆盖层
│   │   ├── game.lua          -- 游戏主状态（最核心，各系统接入点）
│   │   ├── bagUI.lua         -- 背包 UI（BROWSE/PLACE/SELECT/FUSION 四模式）
│   │   ├── upgrade.lua       -- 升级奖励选择界面
│   │   ├── console.lua       -- 开发者控制台（` 键，仅游戏状态可用）
│   │   └── devReport.lua     -- Bug/需求反馈面板（F12，三阶段流程）
│   ├── entities/             -- 游戏实体
│   │   ├── entity.lua        -- 实体基类
│   │   ├── player.lua        -- 玩家（支持 extraSpeed 参数）
│   │   ├── enemy.lua         -- 敌人
│   │   ├── weapon.lua        -- 武器实体（含 getEffective* 方法族）
│   │   └── projectile.lua    -- 投射物（支持 _critRate / _critDamage 字段）
│   ├── systems/              -- 游戏系统
│   │   ├── bag.lua           -- 背包数据结构
│   │   ├── adjacency.lua     -- 相邻增益计算
│   │   ├── synergy.lua       -- Tag 羁绊计算
│   │   ├── fusion.lua        -- 武器融合逻辑
│   │   ├── spawner.lua       -- 敌人生成器
│   │   ├── collision.lua     -- 碰撞检测
│   │   ├── experience.lua    -- 经验升级系统
│   │   ├── camera.lua        -- 摄像机
│   │   └── input.lua         -- 输入抽象层
│   └── utils/                -- 工具库
│       ├── font.lua          -- 字体管理（Font.set/reset）
│       ├── i18n.lua          -- 多语言访问器
│       ├── log.lua           -- 运行日志
│       └── math.lua / timer.lua
├── data/                     -- 运行时数据（可 Git 追踪）
│   ├── bugs.json             -- Bug 记录（devReport 写入）
│   ├── features.json         -- 需求记录
│   ├── features.md           -- 需求 Markdown
│   └── logs/                 -- Bug 快照日志
├── docs/
│   ├── DEVLOG.md             -- 开发日志（每个 Phase 完成后更新）
│   ├── REQUIREMENTS.md       -- 游戏需求文档
│   ├── DISCUSSION.md         -- 需求讨论记录
│   └── plans/                -- 各 Phase 开发计划（phase1.md … phase13.md）
├── tests/                    -- 单元测试
│   ├── run_lupa.py           -- 测试运行器（python tests/run_lupa.py）
│   ├── helper.lua            -- describe/it/assert 框架
│   ├── mock/love.lua         -- Love2D API stub
│   ├── entities/             -- 实体测试
│   └── systems/              -- 系统测试
└── assets/fonts/wqy-microhei.ttc  -- 中文字体
```

---

## 三、代码规范

### 3.1 命名规范
- 变量/函数：`camelCase`
- 类名/模块名：`PascalCase`
- 常量：`UPPER_SNAKE_CASE`
- 私有成员：`_` 前缀（如 `self._bagRow`、`self._activeSynergies`）
- 缓存/内部状态字段：`_` 前缀

### 3.2 代码风格
- 缩进：4 个空格
- 变量作用域：全部使用 `local`
- 字符串：统一使用双引号
- 模块末尾：统一 `return ModuleName`
- 注释：每个函数说明用途，复杂逻辑写行内注释

### 3.3 渲染规范
- 开发阶段使用 `love.graphics` 几何形状代替美术资产
- 渲染逻辑必须封装在 `draw()` 方法内，**严禁在 update() 里混入任何渲染代码**
- 每次 draw 调用前后必须 `love.graphics.setColor(1,1,1,1)` 归位（避免颜色污染）
- 字体使用 `Font.set(size)` / `Font.reset()` 成对调用

### 3.4 i18n 规范
- 所有 UI 展示文本必须通过 `T("key")` 访问，**禁止硬编码中文字符串**到逻辑代码中
- 新增 UI 文本时先在 `config/i18n/zh.lua` 注册 key，再在代码中引用

---

## 四、系统架构要点

### 4.1 状态机（StateManager）
- `switch(name)`：切换状态，调用旧状态 `exit()`，新状态 `enter()`
- `push(name, data)`：叠加覆盖层，不调用底层 `exit()`，保留底层完整状态
- `pop()`：弹出覆盖层，不调用底层 `enter()`
- **规范**：覆盖层（console/bagUI/devReport）必须用 push/pop，不能用 switch

### 4.2 武器 Shape 格式
```lua
-- shape 是零起坐标数组，每个元素 {row, col}
shape = {{0,0}, {0,1}, {1,0}}  -- L形3格

-- ⚠️ 计算行列数的正确方式（Bug#19 修复后）：
local maxR, maxC = 0, 0
for _, cell in ipairs(shape) do
    if cell[1] > maxR then maxR = cell[1] end
    if cell[2] > maxC then maxC = cell[2] end
end
local rows, cols = maxR + 1, maxC + 1

-- ❌ 错误方式（旧 Bug）：
-- local rows = #shape      -- 格子数 ≠ 行数
-- local cols = #shape[1]   -- 恒为 2（每个 {r,c} 长度为2）
```

### 4.3 Tag 羁绊系统
- **tag 计数**：`bag._tagCounts`，`isFused=true` 的武器**不计入**
- **激活记录**：`bag._activeSynergies`（每 tag 最多 1 档，T2 覆盖 T1）
- **玩家加成**：`bag._playerSynergyBonus = { speed, damage, critChance, critMult, maxHP, bulletSpeed, pickupRange, expMult }`
- **重算时机**：每次 `bag:place()` / `bag:remove()` 末尾自动调用 `Synergy.recalculate(bag)`
- **应用时机**：`game.lua` 每帧读取 psb 并传入各系统（不修改 player 基础属性本身）
- **maxHP/pickupRange/expMult** 使用增量缓存（`_psbXxxLast`）避免每帧重复叠加

### 4.4 武器融合
- **触发**：PLACE 模式拖拽武器 → 目标格有冲突 → 检测配方 → 弹出 MODE_FUSION 预览
- **结果武器**：`isFused = true`，不参与 tag 计数，不再显示在融合菜单中
- 配方查询：`Fusion.findRecipe(configIdA, configIdB)`（无序匹配）
- 融合执行：`Fusion.apply(bag, weaponA, weaponB, recipe)`（失败时还原 B）

### 4.5 背包系统
- 初始尺寸：2×2，最大：6×8（MAX_ROWS=6，MAX_COLS=8）
- 坐标：1-indexed（row=1 为第一行）
- `place()` 内部先 `remove()` 清除旧位置，再写入新位置

### 4.6 暴击系统
- 投射物携带 `_critRate`（暴击概率）和 `_critDamage`（暴击倍率）
- `onHit()` 内根据 `_critRate` 随机判定，命中时临时将目标的 `critDamage` 替换为 `_critDamage`
- game.lua 中计算：`effectiveCritRate = player.critRate + psb.critChance/100`

---

## 五、开发者工具使用

### 5.1 游戏内控制台（` 键）
常用指令：
```
weapon <id>       -- 将武器放入背包（如 weapon pistol）
level <n>         -- 设置等级
hp <n>            -- 设置当前血量
set speed <n>     -- 设置移速
kill              -- 清除所有敌人
```
可用武器 id：`pistol / shotgun / smg / sniper / cannon / laser / burst_pistol / grenade_launcher / double_barrel / gatling / plasma_pistol / rail_rifle`

### 5.2 单元测试
```bash
cd D:/WorkSpace_Love2d/Zero
python tests/run_lupa.py          # 运行所有测试
python tests/run_lupa.py tests/systems/test_fusion.lua  # 运行单个文件
```
当前测试成绩：**86 passed, 0 failed**

新增测试时遵循：
- 每个测试文件对应一个系统/实体
- `before_each` 中重置 `Weapon.resetIdCounter()` 和 `Bag.new()`
- 放置多格武器时注意格子冲突（如 sniper 1×3 放 (1,1) 占 1-3 列，下一把不能放同行前3列）

### 5.3 Bug/需求反馈（F12）
三阶段：描述 → 优先级（1低/2中/3高）→ 类型（1=Bug/2=需求）
数据存储：`data/bugs.json` / `data/features.json` / `data/features.md`

---

## 六、Bug 处理优先级规则

- **高优先级**：立即处理，不等指示
- **中优先级**：只记录，等明确说「处理 Bug #X」时再动
- **低优先级**：记录，demo 完成后统一处理

Bug 和需求数据优先从以下路径读取：
- `D:\WorkSpace_Love2d\Zero\data\bugs.json`
- `D:\WorkSpace_Love2d\Zero\data\features.json`
- `D:\WorkSpace_Love2d\Zero\data\features.md`

---

## 七、Git 提交规范

- 每个 Phase 完成后提交，提交信息格式：
  ```
  feat: Phase X.x — 简短标题
  fix: Bug #N — 描述
  docs: 补全 DEVLOG / 计划文档
  ```
- 提交后必须 `git push origin main`（本地 commit 不等于远端可见）
- 每次 Phase 完成后同步更新：
  1. `docs/DEVLOG.md` — 追加开发记录
  2. `docs/plans/phaseX.x.md` — 新建该阶段计划/日志

---

## 八、下一阶段（Phase 11）预览

**主题**：HUD 与 UI
- 常驻 HUD 完善
- 触发器 UI
- 主菜单界面
- 详细计划见：`docs/plans/phase11.md`

---

## 九、已知遗留问题

> 当前无高优先级遗留 Bug，低优先级待 demo 完成后处理。
