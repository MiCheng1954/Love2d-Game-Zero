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
