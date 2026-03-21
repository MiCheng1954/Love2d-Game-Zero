# DEVLOG - Zero

> 记录每一步开发变更，精简为主。

---

## [2026-03-21] Phase 9 — 节奏控制器 + Boss 系统 + 精英/远程敌人

**做了什么：**

### 新增文件
- `config/bosses.lua` — 4 个 Boss 配置（碎骨者/幽灵法师/钢铁巨兽/虚空领主），含技能闭包、触发时间、isFinal 标记
- `src/entities/boss.lua` — Boss 实体类（继承 Enemy），独立技能计时器、冲刺状态、屏幕顶部大血条、死亡掉落爆炸散开
- `src/systems/rhythmController.lua` — 节奏控制器，统一管理生成间隔/批量大小/精英概率/远程概率，在 4/8/12/18 分钟触发 Boss 信号

### 改动文件
- `config/enemies.lua` — 新增 elite（精英怪）和 ranger（远程敌人）配置
- `src/entities/enemy.lua` — Phase 9 重写：精英怪金色光环 + 加深颜色，远程敌人保距 AI（150-280px）+ 定时射击，修复文件内重复内容
- `src/systems/spawner.lua` — 接入 RhythmController 参数，支持精英怪/远程敌人生成，远程敌人注入共享投射物列表
- `src/systems/collision.lua` — 新增 `projectilesVsBoss()`（玩家子弹 vs Boss）和 `enemyProjectilesVsPlayer()`（敌方投射物 vs 玩家）
- `src/states/game.lua` — 接入 RhythmController + Boss 实体：Boss 登场/更新/召唤小兵/胜利判断，屏幕顶部 Boss 血条，右上角计时器+节奏阶段显示，胜利画面覆盖
- `config/i18n/zh.lua` — 新增 Boss 名称 x4，胜利文本 x2

### 游戏设计
- 共 4 个 Boss，分别在 4/8/12/18 分钟出现
- 击败最终 Boss（虚空领主）即触发胜利，4 秒后跳转结算
- 精英怪：HP×3，伤害×2，速度+30%，金色外圈光晕，25% 概率额外掉落触发器
- 远程敌人：与玩家保持 150-280px 距离，每 2 秒向玩家射击一颗子弹
- 节奏阶段：calm → rising → peak → rest（每 120 秒一循环）→ surge（16 分钟后）

**测试：** 115 passed, 0 failed

---

## [2026-03-20 14:44:43] 项目规范确立

**做了什么：** 确定游戏类型、项目结构与开发规范

- 游戏类型：幸存者类射击游戏（类 Vampire Survivors）
- 确定项目目录结构（见下方）
- 实体设计采用面向对象（OOP）风格
- 配置数据统一放在 `config/` 目录
- 第三方库放在 `libs/`，后续按需补充
- 开发日志统一记录在 `docs/DEVLOG.md`

**项目结构：**
```
zero/
├── main.lua
├── conf.lua
├── src/
│   ├── states/
│   ├── entities/
│   ├── systems/
│   ├── ui/
│   └── utils/
├── config/
├── assets/
│   ├── images/
│   ├── audio/
│   │   ├── bgm/
│   │   └── sfx/
│   └── fonts/
├── libs/
└── docs/
    └── DEVLOG.md
```

## [2026-03-20 14:48:05] 确定代码风格规范

**做了什么：** 确定 Lua 代码风格与注释规范

- 命名规范：变量/函数 `camelCase`，类名 `PascalCase`，常量 `UPPER_SNAKE_CASE`，私有成员 `_` 前缀
- 缩进：4个空格
- 变量作用域：全部使用 `local`
- 字符串统一使用双引号
- 模块末尾统一 `return`
- 注释规范：每个变量和每个函数都必须写清楚用途，函数需注明 `@param` 参数说明

## [2026-03-20 15:01:59] 确定资源与渲染规范

**做了什么：** 确定资源策略与逻辑/表现解耦规范

- 开发阶段使用纯代码绘制（`love.graphics` 几何形状）代替美术资产
- 完善阶段再替换为真实素材，不影响任何逻辑代码
- 每个实体必须将渲染逻辑封装在独立的 `draw()` 方法中
- `draw()` 内部区分两种模式：有贴图时使用贴图，无贴图时使用代码绘制作为 fallback
- 禁止在 `update()` 或其他逻辑函数中混入任何渲染代码
- 逻辑与表现完全解耦，随时可替换资产而不改动逻辑层

## [2026-03-20 16:16:08] 确定开发阶段规划

**做了什么：** 规划完整的 13 个开发 Phase

- Phase 1  → 项目基础骨架（conf、main、状态机、工具库）
- Phase 2  → 玩家移动（输入系统、Entity基类、摄像机）
- Phase 3  → 敌人与战斗（Enemy、生成器、投射物、碰撞、自动攻击）
- Phase 4  → 掉落与属性（掉落系统、吸附、经验升级、属性成长）
- Phase 5  → 升级界面（多级奖励选择UI、灵魂刷新）
- Phase 6  → 武器背包（二维网格、背包UI、相邻增益）
- Phase 7  → 武器融合与羁绊（融合配方、武器/技能羁绊）
- Phase 8  → 技能系统（主动/被动、通用技能池、角色专属）
- Phase 9  → 节奏与Boss（节奏控制器、精英怪、Boss触发）
- Phase 10 → 死亡与传承（传承系统、复活、结算界面）
- Phase 11 → HUD与UI（常驻HUD、触发器UI、主菜单）
- Phase 12 → 场景扩展（场景基类、多场景机制）
- Phase 13 → 局外系统（后续讨论后开发）

## [2026-03-20 16:19:13] Phase 1 — 项目基础骨架

**做了什么：** 搭建项目目录结构，实现状态机框架与工具库

- 创建完整目录结构（src/states、entities、systems、ui、utils、config、assets、libs）
- `conf.lua`：窗口配置（1280×720，标题 Zero）
- `main.lua`：程序入口，注册 Love2D 回调，委托给 StateManager
- `src/states/stateManager.lua`：状态机管理器，支持注册/切换/事件转发
- `src/states/menu.lua`：主菜单状态（占位，Phase 11 完善）
- `src/states/game.lua`：游戏主状态（占位，后续各 Phase 填充）
- `src/states/upgrade.lua`：升级选择状态（占位，Phase 5 完善）
- `src/states/gameover.lua`：结算状态（占位，Phase 10 完善）
- `src/utils/math.lua`：数学工具库（distance/angle/normalize/lerp/clamp）
- `src/utils/timer.lua`：计时器工具库（after/every/cancel/update/clear）

## [2026-03-20 16:35:13] Phase 2 — 玩家移动与摄像机

**做了什么：** 接入输入系统、实体基类、玩家类、摄像机系统

- `src/systems/input.lua`：输入抽象层，WASD 映射到动作，预留手柄/鼠标接口，支持 isDown/isPressed/isReleased
- `src/entities/entity.lua`：实体基类，包含 10 项基础属性、takeDamage/heal/onDeath/getBounds 等方法
- `src/entities/player.lua`：玩家类，继承 Entity，WASD 移动、经验/灵魂获取、升级自动成长
- `src/systems/camera.lua`：摄像机，平滑跟随玩家，attach/detach 分离世界层与 UI 层
- `src/states/game.lua`：接入以上系统，背景参考网格，HUD 显示 HP/经验条/等级/灵魂

## [2026-03-20 16:44:30] 修复中文输入法拦截按键问题

**做了什么：** 修复 Windows 中文 IME 导致 WASD 无响应的 Bug

- `main.lua`：在 `love.load()` 中添加 `love.keyboard.setTextInput(false)`，禁用文字输入模式，防止 IME 拦截游戏按键

## [2026-03-20 16:59:09] Phase 3 — 敌人、战斗与自动攻击

**做了什么：** 接入敌人系统、投射物、生成器、碰撞检测、自动攻击、死亡跳转、调试面板

- `config/enemies.lua`：敌人配置数据（basic/fast/tank 三种类型），配置驱动便于扩展
- `src/entities/enemy.lua`：敌人类，继承 Entity，追踪 AI、接触伤害冷却、HP 条绘制、死亡掉落
- `src/entities/projectile.lua`：投射物类，飞行/最大距离/命中销毁/暴击，代码绘制含发光效果
- `src/systems/spawner.lua`：生成系统，按时间动态调整难度（间隔/批次），实现慢快节奏曲线
- `src/systems/collision.lua`：碰撞系统，圆形碰撞检测、子弹vs敌人、敌人vs玩家、死亡清理
- `src/states/game.lua`：接入所有系统，自动锁定最近敌人攻击，死亡后跳转 gameover，右上角调试面板

## [2026-03-20 17:34:33] Phase 5 — 升级奖励选择界面

**做了什么：** 实现两级升级奖励选择 UI，接入灵魂刷新，修复帧内崩溃与状态重置 Bug

- `config/upgrades.lua`：新增升级奖励配置表，大类（weapon/stat/skill）→子选项结构，每项含 `apply(player)` 函数，配置驱动无需改逻辑
- `src/states/upgrade.lua`：重写升级界面，两阶段状态机（大类→子选项），↑↓ 导航，Enter 确认，ESC 返回大类，← 消耗10灵魂刷新子选项顺序
- `src/states/stateManager.lua`：新增 `push/pop` 覆盖层机制，push 不调用底层 exit，pop 不调用底层 enter，保留游戏完整状态
- `src/states/game.lua`：升级回调改用 `_pendingUpgrade` 标志位延迟跳转，当帧 update 末尾统一处理，改用 `StateManager.push/pop` 保留玩家数据
- **修复**：升级回调同步触发 `StateManager.switch` 导致帧内 `_spawner` 被置 nil 崩溃
- **修复**：`StateManager.switch("game")` 重新调用 `Game:enter()` 导致玩家数据重置、等级不保存

## [2026-03-20 17:09:58] Phase 4 — 掉落物、吸附、经验升级

**做了什么：** 接入掉落物系统、自动吸附、经验升级、升级提示浮窗

- `src/entities/pickup.lua`：掉落物类（EXP/SOUL/TRIGGER），漂浮动画，吸附半径检测，飞向玩家，到达后触发拾取效果
- `src/systems/experience.lua`：经验升级系统，统一管理升级逻辑，支持连续升级，升级回调外部注册
- `src/entities/enemy.lua`：死亡时生成掉落物列表（经验+灵魂+10%概率触发器）
- `src/systems/collision.lua`：击杀返回掉落物数据，由 game.lua 统一加入场景
- `src/entities/player.lua`：移除 gainExp 内的升级逻辑，升级统一交由 Experience 系统处理
- `src/states/game.lua`：接入掉落物更新/绘制，升级时显示屏幕中央金色浮窗（含淡出效果）
- **修复**：player.lua 与 experience.lua 升级逻辑冲突导致升级回调不触发

## [2026-03-20 18:00:00] Phase 5.1 — 字体/i18n/控制台/Bug反馈

**做了什么：** 完善开发基础设施，解决中文乱码，新增开发者工具

### 字体与 i18n 系统
- `assets/fonts/wqy-microhei.ttc`：新增文泉驿微米黑字体（~5MB），修复游戏内所有中文乱码显示
- `src/utils/font.lua`：字体管理器，`Font.get(size)` 懒加载缓存，`Font.set(size)` 快捷设置，`Font.reset()` 恢复默认
- `src/utils/i18n.lua`：多语言访问器，`I18n.load(lang)` 加载语言表，`I18n.get(key, ...)` 支持 string.format 参数
- `config/i18n/zh.lua`：中文文本配置表，覆盖 HUD/升级界面/控制台/Bug反馈/菜单/结算/大类/子选项等所有文本
- `main.lua`：启动时注入 `_G.T = I18n.get`，全局可用 `T("key")` 访问文本
- `config/upgrades.lua`：大类和子选项的 `label/desc` 字段改为 `labelKey/descKey`（i18n key），由渲染层调 T() 翻译
- `src/states/game.lua`、`upgrade.lua`、`menu.lua`、`gameover.lua`：所有硬编码中文文本替换为 `T("key")`，菜单/结算使用大字体

### 开发者控制台（` 键）
- `src/states/console.lua`：`StateManager.push("console")` 覆盖层，不暂停游戏
- 支持 11 条指令：`level/levelup/hp/maxhp/souls/speed/attack/exp/kill/clear/help`
- 右下角半透明绿色面板（620×320），历史输出行 + 光标闪烁输入行
- `src/states/game.lua`：新增 `_getPlayer()/_getEnemies()/_getSpawner()/_triggerLevelUp()` 外部访问器
- `src/states/stateManager.lua`：新增 `textinput(text)` 转发方法
- `main.lua`：` 键在游戏状态下 push 控制台，新增 `love.textinput` 回调转发

### Bug 反馈面板（F12 键）
- `src/states/bugReport.lua`：`StateManager.push("bugReport")` 覆盖层，两阶段输入（描述 → 优先级1/2/3）
- Bug 数据含游戏快照（等级/HP/存活时间/敌人数）+ 当前运行日志快照路径索引
- 写入 `项目目录/data/bugs.json`，日志快照写入 `data/logs/bug_<id>_<时间戳>.log`
- **可剔除**：注释 `main.lua` 中的 `require BugReport`、`register("bugReport"...)`、`F12 分支` 三处即可完全移除，不影响游戏逻辑

### 运行日志系统
- `src/utils/log.lua`：新增运行日志模块，写入 `data/game.log`
- 支持 `Log.info/warn/error/event()` 四个级别
- `Log.snapshotForBug(id)`：提交 Bug 时自动将当前日志快照写入 `data/logs/`
- `main.lua`：启动时 `Log.init()`，退出时 `love.quit()` 钩子关闭句柄

### 需求跟踪
- 新建 `data/features.md`：功能需求 backlog，Claude 自动按优先级实现

## [2026-03-20 19:20:00] Phase 5.1 后续修复

**做了什么：** 修复联调阶段发现的 3 个 Bug

### Bug #1 — BugReport 面板崩溃（UTF-8 Invalid）
- **现象**：按 F12 打开 Bug 反馈面板后游戏立即崩溃
- **原因**：`love.graphics.printf()` 在渲染用户输入时收到非法 UTF-8 字符串。退格键处理逻辑用 `s:sub(1, -2)` 每次只删1字节，中文汉字占3字节，删到一半会留下孤立的多字节起始字节
- **修复**：新增 `utf8Backspace(s)` 函数，从字符串末尾向前扫描找到完整字符的起始字节（`b < 0x80 or b >= 0xC0`），一次性截掉整个 Unicode 字符

### Bug #2 — BugReport 存储路径调整
- **原需求**：Bug 记录写入 `%AppData%/LOVE/Zero/bugs.json`（Love2D 沙箱目录）
- **调整为**：写入项目目录 `data/bugs.json`，日志快照写入 `data/logs/`，便于开发时直接查阅和 Git 管理

### Bug #3 — 控制台 ESC 键穿透（状态切换残留）
- **现象**：在控制台按 ESC 关闭后，游戏立即退出到主菜单
- **原因**：`Input.isPressed("cancel")` 底层调用 `love.keyboard.isDown()` 轮询物理键盘状态。控制台 `pop()` 回到 game 状态后的第一帧，ESC 键物理上仍处于按下状态，game 的 `update()` 在同一帧内轮询到 cancel=true，误触发返回菜单
- **修复**：将 game.lua 中 ESC→返回菜单 的处理从 `update()` 的轮询逻辑移至 `keypressed()` 事件回调。`keypressed` 是 Love2D 的一次性事件，只在新按下瞬间触发，不受跨状态按键残留影响
- **经验**：覆盖层（push/pop）场景下，跨状态的"确认/取消"操作应统一走 `keypressed` 事件，而非 Input 系统的轮询；轮询适合连续输入（移动、攻击），不适合单次触发的状态切换

---

## [2026-03-20 21:30:00] Phase 6 — 武器背包系统

**做了什么：** 实现完整武器背包流程，包含武器实体、背包数据结构、背包UI、独立攻击系统、升级流程接入，以及多项开发辅助功能。

### 核心设计决策
- **全员装备**：背包中所有武器均处于装备状态，不存在"选中激活"概念；每把武器拥有独立攻击计时器，独立锁定最近敌人，独立开火
- **索敌接口抽象**：`_findNearestEnemyInRange(range)` 作为独立函数，Phase 7 可直接替换为更复杂的锁定逻辑而不影响武器系统
- **背包尺寸**：初始 2×2，最大扩展至 6×8（高6宽8），升级选项可扩展行列

### 新增文件

#### `config/weapons.lua`
- 定义 6 种武器配置：`pistol`（1×1）、`shotgun`（1×2）、`smg`（1×2）、`sniper`（1×3）、`cannon`（L形3格）、`laser`（T形4格）
- 每种武器含：id、i18n key、形状、颜色、伤害/射速/弹速/射程、最大等级、升级加成

#### `src/entities/weapon.lua`
- `Weapon.new(configId)`：从配置表创建实例，分配唯一 instanceId
- `Weapon.resetIdCounter()`：新游戏时重置 ID 计数，在 `Player.new()` 中调用
- `Weapon:rotate()`：顺时针 90° 旋转，公式 `(r,c) → (maxC-c, r)`，旋转后重新对齐原点
- `Weapon:getCells(originRow, originCol)`：返回武器当前旋转下占用的所有格子坐标列表
- `Weapon:getEffectiveDamage(playerAttack)`：武器基础伤害 + 玩家攻击加成
- `Weapon:tickAttack(dt)`：推进攻击计时器，返回本帧应触发的射击次数（0或多次）
- `Weapon:levelUp()`：等级+1，应用 levelBonus 字段加成

#### `src/systems/bag.lua`
- `Bag.new(rows, cols)`：创建背包，内部维护 `_grid[row][col] = instanceId` 和 `_weapons` 实例表
- `Bag:canPlace(weapon, row, col)`：检测放置合法性（不越界、不与他物冲突；同一武器移动时允许自身覆盖）
- `Bag:place(weapon, row, col)`：清除旧位置 → 写入新位置 → 记录锚点 `_bagRow/_bagCol`
- `Bag:remove(weapon)`：从网格中移除，清空锚点
- `Bag:expand(dRows, dCols)`：扩展背包，不超过 `MAX_ROWS=6, MAX_COLS=8`
- `Bag:getWeaponAt(row, col)`：返回指定格的武器实例，无则 nil
- `Bag:getAllWeapons()`：返回按 instanceId 排序的所有武器实例列表
- `Bag:hasSpace(weapon)`：扫描全部位置，判断能否放入当前形状的武器

#### `src/states/bagUI.lua`
三种模式，通过 `data.mode` 参数切换：
- **BROWSE 模式**（TAB 打开）：方向键移动光标，Enter 拾起武器进入 PLACE 子模式，ESC 关闭
- **PLACE 模式**（升级获得武器 / BROWSE 内拾起）：方向键移动预览，R 旋转，Enter 放置，ESC 丢弃/还原
- **SELECT 模式**（武器强化时选武器）：方向键移动光标，Enter 选中（受 filter 函数过滤），ESC 取消

布局（1280×720）：左侧背包网格（每格 64px），右侧武器详情，底部操作提示
绘制规则：武器格显示颜色填充 + 锚点格显示 `Lv{n}` 标签；SELECT 模式不可选武器变暗；PLACE 预览绿色=可放/红色=冲突

### 修改文件

#### `src/entities/player.lua`
- 引入 `Bag` 和 `Weapon` 模块
- `Player.new()`：调用 `Weapon.resetIdCounter()`，初始化 `self._bag = Bag.new(2, 2)`
- 新增 `Player:getBag()` 方法

#### `src/states/game.lua`
- 移除硬编码的 `AUTO_ATTACK_*` 常量，改为 `FALLBACK_*` 系列（无武器时的默认参数）
- `_updateAutoAttack(dt)`：遍历 `bag:getAllWeapons()`，每把武器独立 `tickAttack(dt)`，调用 `_findNearestEnemyInRange(weapon.range)` 独立开火；背包为空时使用 FALLBACK 参数
- `_findNearestEnemyInRange(range)`：抽象索敌逻辑，Phase 7 替换点
- **暂停功能**：P 键切换 `_paused` 状态，暂停时跳过所有游戏逻辑，绘制半透明遮罩 + "⏸ 已暂停"提示
- **TAB 打开背包**：在 keypressed 中处理 TAB → push bagUI（BROWSE 模式）
- `onWeaponDrop(weapon, onDone, selectOpts)` 回调：`weapon == "__select__"` 时推入 SELECT 模式；否则推入 PLACE 模式
- 调试面板：动态高度，逐行显示背包中所有武器信息（颜色区分）；显示暂停状态
- `Log.info` 记录：游戏开始、玩家死亡、暂停/恢复事件

#### `src/systems/input.lua`
- 新增 `rotateWeapon` 动作（映射 `r` 键）
- 新增 `pause` 动作（映射 `p` 键）

#### `config/upgrades.lua`
- `weapon_new_basic`：过滤背包能放下的候选武器；若全部放不下则先扩展背包1格再过滤；调用 `ctx.onWeaponDrop(weapon, ctx.onDone)` 并返回 `true`（延迟 onDone）
- `weapon_upgrade`：检测有可升级武器后调用 `ctx.onWeaponDrop("__select__", ctx.onDone, { filter, hint, onSelect })`，返回 `true`
- `weapon_bag_expand`：新增 `canShow(player)` — 背包已达最大尺寸时返回 false，从升级菜单隐藏该选项
- 所有 apply 函数记录 `Log.info`

#### `src/states/upgrade.lua`
- `enter(data)`：新增存储 `self._onWeaponDrop = data.onWeaponDrop`
- 大类/子选项渲染前通过 `canShow(player)` 过滤，最大背包时自动隐藏扩展选项
- 选项确认：`deferred = opt.apply(player, ctx) == true`；若 deferred 则不立即调用 `_onDone()`，由 apply 自行控制流程
- ctx 传入：`{ onWeaponDrop, onDone }`

#### `config/i18n/zh.lua`
- 新增：`hud.paused`、`hud.pause_hint`、TAB/P 键提示
- 新增：`bag.hint.browse/place/select/select_upgrade`
- 新增：6 种武器的 `nameKey/descKey`
- 新增：`opt.weapon_bag_expand.label/desc`

#### `src/states/console.lua`
- 引入 `config.weapons`，`weapon <id>` 指令做合法性校验
- 新增 `SET_ATTRS` 配置表（数据驱动属性修改），支持 11 项属性：`speed/attack/maxhp/hp/souls/critrate/critdamage/expbonus/soulbonus/pickupradius/defense`
- 新增 `set <attr> <val>` 指令：查表 → 范围限制 → 写入玩家字段
- 新增 `weapon <id>` 指令：创建武器实例，扫描背包第一个可放格位放入
- **修复**：`addExp` → `gainExp`（方法名笔误导致崩溃）

#### `src/systems/experience.lua`
- 升级时调用 `Log.info(...)` 记录升级事件

#### `main.lua`
- 引入并注册 `bagUI` 状态

### Bug 修复记录

#### Bug #2/#3/#7（合并）— 升级后背包流程立即关闭
- **现象**：选择「获得新武器」后背包 PLACE 界面一闪而过，无法放置武器
- **原因**：`upgrade.lua` 在 `apply()` 返回后立即调用 `_onDone()`，导致 bagUI 被推入后又被立即弹出
- **修复**：`apply()` 返回 `true` 表示延迟（deferred）流程，upgrade.lua 检查返回值决定是否立即 onDone；onDone 通过 ctx 传递给 apply，由 bagUI 回调在放置/丢弃完成后手动触发

#### Bug #4/#9（合并）— 武器旋转方向错误 / 旋转180°
- **现象 1**：武器旋转方向是逆时针（应为顺时针）
- **现象 2**：每次按 R 键武器旋转 180° 而不是 90°
- **原因 1**：旋转公式 `(r,c) → (c, maxR-r)` 为逆时针；应为 `(r,c) → (maxC-c, r)`
- **原因 2**：`bagUI:keypressed("r")` 和 `Input.isPressed("rotateWeapon")` 在同一帧内各调用一次 `rotate()`，导致旋转两次
- **修复 1**：更正旋转公式为顺时针
- **修复 2**：移除 `keypressed` 中的旋转处理，统一使用 `Input.isPressed` 轮询（PLACE 模式内每帧检测一次）

#### Bug #5 — 控制台 `exp` 指令崩溃
- **现象**：在控制台输入 `exp <n>` 后游戏崩溃
- **原因**：`player:addExp()` 方法不存在，正确方法名为 `player:gainExp()`
- **修复**：`console.lua` 中 `addExp` 改为 `gainExp`

#### Bug #6 — BROWSE 模式拾起武器后无法放回/退出
- **现象**：在背包 BROWSE 模式按 Enter 拾起武器后，按 ESC 或放置后界面卡死/武器消失
- **原因**：BROWSE→PLACE 切换时 `_onPlace` 和 `_onDiscard` 未设置，放置/取消均无回调，模式无法切回 BROWSE
- **修复**：在 `_updateBrowse()` 的 Enter 拾起逻辑处即时注册内联回调：`_onPlace` 切回 BROWSE 并清空 `_placing`；`_onDiscard` 尝试原位还原或扫描第一个空位放回，再切回 BROWSE

#### Bug #10 — 放置武器后颜色残留在背包格
- **现象**：移动武器后原先占用的格子仍显示颜色
- **原因**：`Bag:place()` 在写入新位置前未清除旧位置，导致旧格子的 instanceId 残留
- **修复**：`place()` 开头调用 `remove(weapon)` 清除所有旧格子，再写入新位置

#### Bug #11/#12（合并）— BROWSE 移动武器后原位残影
- 同 Bug #10，修复方式相同，在 `Bag:place()` 中统一处理

### 开发辅助功能

#### 游戏暂停（P 键）
- 暂停时所有游戏逻辑（敌人/投射物/掉落物/攻击/生成器）均停止更新
- TAB 在暂停状态下仍可打开背包
- 日志记录暂停/恢复时机和游戏时长

#### 控制台 `weapon` 指令
- 输入 `weapon <id>` 即可将指定武器放入背包
- 自动校验武器 ID 是否存在（非法 ID 时列出所有可用 ID）
- 自动扫描背包第一个可放置位置

#### 控制台 `set` 指令
- `set <attr> <val>` 数据驱动属性修改，支持 11 项玩家属性
- 自动范围限制（min/max）和整数取整
- 扩展新属性只需在 `SET_ATTRS` 表中添加一行

### 遗留 Bug（低优先级，Phase 7 前处理）
- **Bug #14**：背包中武器等级标签统一显示在锚点格左上角，cannon（L形）等非矩形武器的等级标签可能被其他格遮挡，需调整到更醒目的位置

---

## [2026-03-21] fix: Bug #14 — 武器等级标签位置修正

**做了什么：** 将武器等级标签从锚点格左上角改为显示在武器视觉中心

- `bagUI.lua`：计算武器所有格子的中心坐标，等级标签绘制在视觉中心位置，非矩形武器（cannon 等）不再被遮挡

---

## [2026-03-21] Phase 7 — 相邻增益 & 初版羁绊系统

**做了什么：** 实现武器相邻增益与基于武器组合的初版羁绊系统

### 相邻增益系统
- **新建 `src/systems/adjacency.lua`**：双向相邻增益计算，共享边的任意两把武器互相提供各自的 `adjacencyBonus`
- **触发时机**：每次 `bag:place()` / `bag:remove()` 末尾自动重算
- **缓存字段**：`weapon._adjBonus = { damage, attackSpeed, range, bulletSpeed }`
- 6 把武器各自的 adjacencyBonus 主题：pistol(射速)、shotgun(伤害)、smg(射速)、sniper(射程)、cannon(伤害)、laser(射速+射程)

### 初版羁绊系统（`config/synergies.lua` + `src/systems/synergy.lua`）
- **触发规则**：背包中同时持有 `requires` 列出的所有武器（不限位置）激活羁绊
- **效果字段**：写入 `weapon._synergyBonus`，与 adjBonus 叠加
- **3 个初版羁绊**：`rapid_duo`(pistol+smg)、`heavy_strike`(shotgun+cannon)、`precision_pair`(sniper+laser)

### weapon 新增 effective 方法族
- `getEffectiveDamage(playerAttack)`、`getEffectiveAttackSpeed()`、`getEffectiveRange()`、`getEffectiveBulletSpeed()`
- `tickAttack(dt)` 使用 `getEffectiveAttackSpeed()` 计算实际攻击间隔

---

## [2026-03-21] Phase 7.1 — 武器融合 & 单元测试框架

**做了什么：** 实现玩家主动拖拽触发的武器融合系统，并搭建自动化单元测试基础设施

### 武器融合
- **新建 `config/fusion.lua`**：3条融合配方（dual_pistol / siege_cannon / railgun），无序匹配
- **新建 `src/systems/fusion.lua`**：`findRecipe()` 查询配方，`apply()` 消耗原材料生成结果武器
- **`bagUI.lua` 新增 `MODE_FUSION`**：PLACE 模式下放置目标格冲突时检测融合，匹配则进入融合预览界面
  - 显示：原材料 A + B → 结果武器（名称/属性/形状/格子尺寸）
  - 操作：Enter 确认融合 / ESC 取消（A 放回原位）
- `config/weapons.lua` 新增 3 把融合产物配置（`dual_pistol`/`siege_cannon`/`railgun`）

### 单元测试框架（`tests/` 目录）
- **运行方式**：`python tests/run_lupa.py`（lupa Python 绑定，无需安装 busted）
- **`tests/mock/love.lua`**：Love2D API 完整 stub，屏蔽图形依赖
- **`tests/helper.lua`**：自实现 describe/it/before_each/assert 框架
- 初版测试覆盖（71个用例）：
  - `test_weapon.lua`：23 个（effective 方法族、tickAttack、rotate）
  - `test_bag.lua`：22 个（canPlace、place、remove、expand、getAllWeapons）
  - `test_adjacency.lua`：8 个（相邻增益计算）
  - `test_synergy.lua`：8 个（初版羁绊激活/移除）
  - `test_fusion.lua`：11 个（findRecipe 无序匹配、apply 消耗生成）

---

## [2026-03-21] Phase 7.2 — Tag 羁绊系统重设计 & Bug #15–#19 修复

**做了什么：** 将羁绊系统从「武器组合触发」完整重设计为 Tag 驱动的全局被动技能体系；修复 5 个 Bug；合并开发者反馈面板；新增 6 把基础武器

### Tag 羁绊系统（核心重设计）
- **`config/synergies.lua` 完整重写**：6 种流派 tag（速射/精准/重型/爆炸/科技/游击），每种 tag 两档（×2 / ×3）共 12 个羁绊档位
- **`src/systems/synergy.lua` 完整重写**：tag 计数（跳过 `isFused` 武器）→ 找最高满足档位 → 累加 `_playerSynergyBonus`
- **`bag._playerSynergyBonus`**：新增全局加成字段（speed/damage/critChance/critMult/maxHP/bulletSpeed/pickupRange/expMult）
- **`bag._tagCounts`**：新增 tag 计数字典，用于 UI 进度条显示
- **`game.lua`** 每帧读取 psb 应用到：移速、暴击率、暴击倍率、伤害、弹速、拾取范围、经验倍率、最大血量（增量缓存避免每帧重复叠加）
- **羁绊效果列举**：速射T1(+25速)→T2(+50速+8伤)；精准T1(+8%暴击)→T2(+15%暴击+40%倍率)；重型T1(+15伤)→T2(+30伤+30血)；爆炸T1(+80弹速)→T2(+160弹速+10伤)；科技T1(+60拾取)→T2(+120拾取+25%经验)；游击T1(+25血)→T2(+50血+20速)

### 新增 6 把基础武器
| 武器 | Tags | 格子 |
|------|------|------|
| burst_pistol（爆发手枪） | 速射/精准 | 1×1 |
| grenade_launcher（榴弹发射器） | 爆炸/重型 | 1×2 |
| double_barrel（双管猎枪） | 重型/游击 | 1×2 |
| gatling（加特林） | 速射/重型 | 2×2 |
| plasma_pistol（等离子手枪） | 科技/爆炸 | 1×1 |
| rail_rifle（磁轨步枪） | 精准/科技 | 1×3 |

### Bug 修复
- **Bug #15**：激活羁绊未显示效果描述 → `_drawDetail()` 在羁绊名下方追加 descKey 文本
- **Bug #16**：融合预览未显示结果武器 Tags → `MODE_FUSION` 新增 tags 展示行
- **Bug #17**：武器详情无 Tag 展示 → `_drawDetail()` 新增 tag 进度条区块（激活/进行中/未达到三色）
- **Bug #18**：独立羁绊面板布局混乱、信息重复 → 羁绊信息整合进武器详情面板，`_drawSynergies()` 改为 no-op
- **Bug #19**：融合预览显示错误武器尺寸（恒为2列）→ 旧 `#shape[1]` 恒为2，改为遍历所有格子取 maxR/maxC 后+1；三把融合武器均受影响

### 开发者反馈面板合并（devReport）
- **新建 `src/states/devReport.lua`**：三阶段输入（描述 → 优先级 → Bug/需求 类型），取代原 bugReport + featureRequest
- **F12 统一入口**：main.lua 中 F12 改为推送 devReport，移除 F11 独立入口
- DONE 阶段边框颜色随类型变化（红=Bug，蓝=需求），1.5 秒后自动关闭

### 单元测试更新
- **`test_synergy.lua` 完整重写**：16 个用例，覆盖 tag 计数 / T1 激活 / T2 激活与降级 / psb 累加 / isFused 跳过
- **`test_fusion.lua` 新增 Bug#19 专项**：6 个用例，验证三把融合武器正确尺寸，并反向确认旧算法确实有误
- **最终测试成绩：86 passed, 0 failed**

---

## [2026-03-21] Phase 8 — 技能系统（完整实装）

**做了什么：** 实装完整的技能体系（主动/事件被动/纯被动/角色专属），包含技能槽位制、视觉特效、HUD 技能栏、背包技能面板、技能羁绊，以及 Bug #20-#29、需求 #1-#7 全量修复。

### 核心架构

#### 技能分类（共 20 个）
- **主动（6）**：dash(空格)、time_slow(Q)、bomb_throw(E)、blink(Q)、battle_cry(F)、mana_shield(F)
- **事件被动-定时（3）**：emp_burst(12s)、heal_pulse(15s)、ammo_supply(10s)
- **事件被动-击杀（2）**：explosion(每5击杀)、soul_drain(每3击杀)
- **事件被动-受伤（3）**：counter_shot(CD10s)、rage(CD20s)、thorns(CD8s)
- **纯被动（5）**：iron_body、swift_feet、sharpshooter、energy_field、iron_will
- **角色专属（1）**：overload(F，default角色)

#### 槽位制设计
- `slotType="dash"` → skill1(空格)，`slotType="exclusive"` → skill4(F)，`slotType="active"` → cfg.key 直接定向（skill2=Q 或 skill3=E）
- `add()` 返回：`true`=成功，`false`=失败，`{conflict=true,...}`=槽位冲突，`{passiveFull=true,...}`=被动满（需求7已移除上限）
- `resolveSlot()` 直接用 `cfg.key` 定向，不再顺序填充（修复 Bug #21/#24）

#### 全局减速状态（Bug #20）
- `SkillManager._globalSlowActive/_globalSlowRate/_globalSlowTimer`
- `setGlobalSlow(rate, duration)` / `getGlobalSlow()` — 供技能 effect 设置，供 Spawner 新敌人查询

### 新建文件

#### `config/skills.lua`
20 个技能完整配置，含 type/slotType/key/cooldown/trigger/tag/characterId/effect/passive/levelBonus。

#### `config/skill_synergies.lua`
4 个技能 tag 羁绊（防御/爆发/辅助/精准），每档含 tiers 数组，格式同 synergies.lua。

#### `src/systems/skillManager.lua`
- `new()`：初始化 `_slots={skill1~4}`、`_passives=[]`、全局减速状态、`_firedThisFrame=[]`
- `add(skillId, player)`：角色校验 → 槽位路由 → 冲突检测 → 插入/升级
- `tryActivate(slotKey, player, ctx, cdReduce)`：CD 检测 → 触发 effect → 重置计时
- `update(dt, player, ctx, cdReduce)`：推进 CD/充能计时器；触发 passive_timed；衰减 buff(battleCry/rage/overload/shield/soulDrain)；减速恢复；全局减速衰减；每帧清空 `_firedThisFrame` 并记录触发的被动技能
- `onKill(player, enemy, ctx)`：passive_onkill 击杀计数，满阈值触发 effect
- `onHit(player, dmg, ctx)`：passive_onhit CD 检测，触发 effect
- `recalcPassive(psb)`：纯被动每帧写入 psb
- `getCooldownRatio(skillId)`：支持 active(CD进度)、passive_onhit(CD进度)、passive_timed(充能进度)
- `setGlobalSlow/getGlobalSlow`：全局减速状态管理

#### `src/systems/skillSynergy.lua`
统计 `skillTagCounts` → 找最高满足档位 → 累加 psb → 返回 activeSynergies。

#### `src/systems/skillEffects.lua`（需求1）
视觉特效系统：`spawn(skillId, player, ctx)` / `update(dt)` / `draw(camX, camY)` / `drawScreenEffects()` / `clear()`
- 世界特效：trail(冲刺拖尾)、ring_expand(爆炸/闪现/战吼/治疗)、orbit_ring(护盾)
- 屏幕特效：screen_flash(减速/超载/狂怒)

#### `src/states/skillSelectUI.lua`
技能升级选择界面，展示 3 个候选（名称/描述/当前等级/"NEW"），Enter 确认，ESC 取消，push/pop 覆盖层。

#### `src/states/skillConflictUI.lua`
槽位冲突时弹出，左右对比展示旧技能和新技能，← → 选择保留/替换，Enter 确认，ESC = 保留旧技能。

### 修改文件

#### `src/entities/player.lua`
- 新增战斗属性：`attack=10, critRate=0.05, critDamage=1.5, defense=0`
- 新增角色标识：`characterId="default"`
- 新增方向缓存：`_lastDx=1, _lastDy=0`（静止时保持最后移动方向，供技能瞄准用，修复 Bug #29）
- `_handleMovement()`：有输入时同步更新 `_lastDx/_lastDy`
- 挂载 `_skillManager = SkillManager.new()`，新增 `getSkillManager()`

#### `src/entities/entity.lua`
- `takeDamage()`：defense < 1 时作百分比减免；新增 `_dropProcessed=false` 通过 Enemy 子类标记（修复 Bug #28）

#### `src/entities/enemy.lua`
- `onDeath()`：新增 `_dropProcessed = false`，标记掉落物尚未被游戏主循环处理

#### `src/systems/spawner.lua`
- 新增 `setSkillManager(sm)` 接口
- `_spawnOne()` 新敌人生成后查询 `getGlobalSlow()`，若全局减速激活则同步施加减速（修复 Bug #20）

#### `src/systems/input.lua`
- 新增 skill1(空格)/skill2(q)/skill3(e)/skill4(f) 动作映射

#### `src/states/game.lua`
- `enter()`：`_spawner:setSkillManager(sm)` 接入全局减速
- `update()`：合并技能 psb → mergedPsb；技能 ctx 使用 `_lastDx/_lastDy`；`sm:update()` 后遍历 `_firedThisFrame` 触发 FX；扫描 `_dropProcessed==false` 的死亡敌人补全掉落流水线（修复 Bug #28）；`FX.update(dt)`
- `draw()`：`FX.draw(0,0)`（世界坐标）+ `FX.drawScreenEffects()`（屏幕坐标）
- `keypressed()`：skill1~4 按键 → `sm:tryActivate()` → 成功时 `FX.spawn()`；技能 ctx 使用 `_lastDx/_lastDy`
- `_drawSkillBar()`（需求2/3）：左下角 4 个主动槽框（按键标签+技能名+CD进度条）+ 被动列表（定时被动/onhit被动含充能进度条，修复 Bug #22）
- TAB 打开背包传入 `player=_player` 供技能面板使用

#### `src/states/bagUI.lua`
- `enter(data)`：存储 `self._player`
- 新增 `_drawSkillList()`（需求4）：显示所有主动槽（按键+名称+等级+描述）+ 被动列表，位于详情面板下方

#### `config/upgrades.lua`
- 技能大类 `skill_get` 实装：`canShow` 检测技能池可用项，`apply` 随机抽 3 个推入 skillSelectUI；处理 conflict 时推入 skillConflictUI

#### `src/states/console.lua`
- `skill <id>`：`sm:add()` 结构化返回处理；conflict 时强制 replaceSlot；`skill list` 列出所有技能 id

#### `config/i18n/zh.lua`
- 新增：20 个技能 name/desc；4 个技能 tag 显示名；4 个技能羁绊 name/desc（T2/T3）；技能栏 HUD key；升级界面 skill_get key；需求5修改：被动描述改为"被动："前缀

### Bug 修复汇总（本 Phase）

| Bug | 描述 | 修复方案 |
|-----|------|---------|
| #20 | 全屏减速对新生成敌人无效 | Spawner 查询 SkillManager.getGlobalSlow() 施加初始减速 |
| #21/#24 | 技能槽按获取顺序填充而非按 cfg.key | resolveSlot() 改为直接用 cfg.key 定向 |
| #22 | 定时被动无充能 UI | getCooldownRatio() 支持 passive_timed，HUD 显示充能进度条 |
| #23 | bomb_throw 描述说 E 但落在 Q 槽 | 根本原因同 #21/#24，随 resolveSlot 修复 |
| #26 | 被动技能触发无视觉效果 | _firedThisFrame 机制 + game.lua 遍历调用 FX.spawn() |
| #28 | 被技能打死的敌人不掉落 | enemy._dropProcessed 标记 + game.lua 扫描补全掉落流水线 |
| #29 | 指向性技能不用最后移动方向 | player._lastDx/_lastDy 缓存 + 技能 ctx 改用最后方向 |

### 需求完成汇总

| 需求 | 描述 | 实现 |
|------|------|------|
| #1 | 技能释放视觉效果 | skillEffects.lua 几何特效系统 |
| #2 | HUD 显示技能 | _drawSkillBar() 左下角 4 槽 + 被动列表 |
| #3 | 技能槽按键对应 | 槽位制 + resolveSlot() |
| #4 | 背包显示技能描述 | bagUI._drawSkillList() |
| #5 | 被动描述改为"被动:" | i18n zh.lua 全部被动 desc 更新 |
| #6 | 技能槽冲突让玩家选择 | skillConflictUI 弹窗 |
| #7 | 被动技能不设上限 | 移除 MAX_PASSIVES 检查 |

### 自动化钩子

#### `.claude/check_pending.py` + `settings.local.json`
- `UserPromptSubmit` 钩子：每次冰冰发送消息时自动扫描 bugs.json/features.json 的 pending 条目
- 若有待处理条目则注入 additionalContext，触发 Claude 立即开始处理
- 使用 `python -X utf8` 保证 Windows 下中文正常输出

### 测试成绩
**最终：115 passed, 0 failed**（新增 29 个 test_skillManager 用例）

---

## [2026-03-21] Phase 8 后续 — 背包技能面板重设计 & Bug #30-#31 修复

**做了什么：** 将背包界面的技能展示从"武器详情下方附加列表"完整重设计为独立的技能面板，支持 Q/E 键切换；修复 2 个遗留 Bug；新增一键启动脚本。

### 背包界面技能面板重设计

#### 面板切换机制（Q/E 键）
- **Q 键** → 武器面板（背包网格 + 右侧武器详情，与原有布局完全一致）
- **E 键** → 技能面板（背包网格隐藏，技能面板撑满整个内容区）
- PLACE / SELECT / FUSION 模式强制显示武器面板，不受 Q/E 影响
- Tab 标签栏固定在内容区左上角（`GRID_X` 位置），当前选中高亮紫色

#### 技能面板布局（全宽）
- **左列（220px）**：技能列表，按主动槽（空格/Q/E/F）→ 被动的顺序排列；方向键上下导航，选中项高亮背景 + 紫色边框；右侧显示按键小标签（`[空格]`/`[Q]`/`[被动]` 等）
- **竖分割线**：列表与详情之间
- **右列（余宽）**：选中技能完整详情
  - 技能名（紫色大字）+ 类型标签 + 对应按键
  - 技能描述（灰色，自动换行）
  - 等级（当前/最大）
  - 冷却时间 / 自动触发间隔 / 击杀触发次数（按类型显示对应字段）
  - 纯被动：显示当前等级实际加成数值
  - 升级预览（未满级时显示下一级加成）
  - 角色专属标记
- **无技能时**：显示友好提示文字，不报错、不隐藏面板

#### 修复：操作提示中文乱码
- **原因**：`_drawSkillPanel()` 末尾 `Font.reset()` 重置为默认字体（不支持中文），`_drawHint()` 接着渲染中文导致乱码
- **修复**：`_drawHint()` 自带 `Font.set(13)` / `Font.reset()` 成对调用，不依赖外部字体状态；技能面板模式下提示文字单独显示对应操作说明

### Bug 修复

| Bug | 描述 | 修复方案 |
|-----|------|---------|
| #30 | 游戏开始无技能时左下角技能栏不显示 | 移除 `_drawSkillBar()` 中无技能时的 `return`，始终绘制 4 个空槽框 |
| #31 | 背包页面技能详情不显示 | ① TAB 打开背包时补传 `player=_player`；② `_drawSkillList()` 内局部变量 `GRID_X/CELL_SIZE` 与模块常量冲突，改用模块顶部常量 |

### 一键启动脚本
- 新建 `run.bat`：自动探测多个常见路径的 `love.exe`，优先使用 `D:\WorkSpace_Love2d\Engine\LOVE\love.exe`，找不到时给出友好提示；双击即可启动游戏

