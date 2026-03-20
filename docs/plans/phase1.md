# Phase 1 开发计划 — 项目基础骨架

## 目标
搭建项目目录结构，实现状态机框架与工具库，为后续所有 Phase 提供基础设施。

---

## 一、文件结构规划

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

---

## 二、新建文件汇总

| 文件 | 内容 |
|------|------|
| `conf.lua` | 窗口配置（1280×720，标题 Zero） |
| `main.lua` | 程序入口，注册 Love2D 回调，委托给 StateManager |
| `src/states/stateManager.lua` | 状态机管理器，支持注册/切换/事件转发 |
| `src/states/menu.lua` | 主菜单状态（占位，Phase 11 完善） |
| `src/states/game.lua` | 游戏主状态（占位，后续各 Phase 填充） |
| `src/states/upgrade.lua` | 升级选择状态（占位，Phase 5 完善） |
| `src/states/gameover.lua` | 结算状态（占位，Phase 10 完善） |
| `src/utils/math.lua` | 数学工具库（distance/angle/normalize/lerp/clamp） |
| `src/utils/timer.lua` | 计时器工具库（after/every/cancel/update/clear） |
| `docs/DEVLOG.md` | 开发日志 |

---

## 三、状态机设计

- `StateManager.register(name, state)`：注册状态
- `StateManager.switch(name, data)`：切换状态（调用 exit/enter）
- 事件转发：`update(dt)`、`draw()`、`keypressed(key)`、`keyreleased(key)`

---

## 四、验证步骤
1. 运行游戏，窗口正常打开（1280×720）
2. 主菜单状态正常显示
3. 状态切换无报错
