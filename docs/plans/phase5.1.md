# Phase 5.1 开发计划 — 字体/i18n/控制台/Bug反馈

## 目标
完善开发基础设施：解决中文乱码，建立多语言体系，新增开发者控制台、Bug反馈面板、运行日志系统。

---

## 一、新建/修改文件汇总

| 文件 | 操作 | 内容 |
|------|------|------|
| `assets/fonts/wqy-microhei.ttc` | 新增 | 文泉驿微米黑字体，修复中文乱码 |
| `src/utils/font.lua` | 新建 | 字体管理器，懒加载缓存 |
| `src/utils/i18n.lua` | 新建 | 多语言访问器 |
| `config/i18n/zh.lua` | 新建 | 中文文本配置表 |
| `src/utils/log.lua` | 新建 | 运行日志模块 |
| `src/states/console.lua` | 新建 | 开发者控制台（` 键） |
| `src/states/bugReport.lua` | 新建 | Bug 反馈面板（F12 键） |
| `data/features.md` | 新建 | 功能需求 backlog |
| `main.lua` | 修改 | 注册新状态，注入全局 T() |
| `config/upgrades.lua` | 修改 | label/desc 改为 labelKey/descKey |
| 各状态文件 | 修改 | 硬编码中文替换为 T("key") |

---

## 二、各模块设计

### 2.1 font.lua
```lua
Font.get(size)    -- 懒加载，返回指定大小的字体对象（缓存）
Font.set(size)    -- love.graphics.setFont(Font.get(size))
Font.reset()      -- 恢复默认字体
```

### 2.2 i18n.lua
```lua
I18n.load(lang)           -- 加载语言表（如 "zh"）
I18n.get(key, ...)        -- 获取文本，支持 string.format 参数
-- main.lua 中注入全局：_G.T = I18n.get
```

### 2.3 console.lua（` 键呼出）
- `StateManager.push("console")` 覆盖层，不暂停游戏
- 右下角半透明绿色面板（620×320）
- 历史输出行 + 光标闪烁输入行
- 支持指令：`level / levelup / hp / maxhp / souls / speed / attack / exp / kill / clear / help`

### 2.4 bugReport.lua（F12 键）
- 两阶段输入：描述文字 → 优先级（1/2/3）
- 写入 `data/bugs.json`
- 附带游戏快照（等级/HP/时长/敌人数）
- 日志快照写入 `data/logs/bug_<id>_<时间戳>.log`

### 2.5 log.lua
```lua
Log.init()                    -- 启动时初始化（main.lua 调用）
Log.info(msg)                 -- 普通信息
Log.warn(msg)                 -- 警告
Log.error(msg)                -- 错误
Log.event(tag, data)          -- 游戏事件记录
Log.snapshotForBug(id)        -- Bug提交时生成日志快照
```
写入 `data/game.log`，`love.quit()` 时关闭句柄。

---

## 三、验证步骤
1. 游戏内所有中文文字正常显示（无乱码）
2. ` 键呼出控制台，指令正常执行
3. F12 打开 Bug 反馈面板，提交后 bugs.json 正常写入
4. data/game.log 有运行日志输出
5. 所有状态文本通过 T() 显示，切换语言只需改 i18n/zh.lua
