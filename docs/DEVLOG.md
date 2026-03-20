# DEVLOG - Zero

> 记录每一步开发变更，精简为主。

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

