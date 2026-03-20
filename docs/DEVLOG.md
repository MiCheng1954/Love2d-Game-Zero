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
