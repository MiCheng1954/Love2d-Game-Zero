# Bug #54 — 局外成长界面无法通过 Q/E 切换面板

## Bug 描述
`src/states/progression.lua` 中面板切换使用了 `Input.isPressed("bagLeft")` 和 `Input.isPressed("bagRight")`，但这两个 action 在 `src/systems/input.lua` 中不存在，导致 Q/E 键无论如何都无法切换面板。

## 根因分析
`input.lua` 的 action 映射：
- Q → `skill2`
- E → `skill3`

`progression.lua` 的代码（约第 150 行）：
```lua
if Input.isPressed("bagLeft") then        -- Q  ← action 不存在
    self._tab = TAB_COMMON
elseif Input.isPressed("bagRight") then   -- E  ← action 不存在
    self._tab = TAB_TREE
```

`bagLeft`/`bagRight` 是 agent 自行发明的 action 名，实际从未注册到 input 系统。

## 涉及文件
- `src/states/progression.lua`（修改）

## 修改计划
将 `bagLeft`/`bagRight` 改为正确的 `skill2`/`skill3`（Q/E 实际映射的 action 名）。

progression.lua 是局外界面（push/pop 覆盖层），不在 game 状态时运行，不会与技能激活冲突。

## 代码 Diff
```diff
- if Input.isPressed("bagLeft") then        -- Q
+ if Input.isPressed("skill2") then         -- Q
      self._tab = TAB_COMMON
- elseif Input.isPressed("bagRight") then   -- E
+ elseif Input.isPressed("skill3") then     -- E
      self._tab = TAB_TREE
```

## 潜在风险
无。progression 界面不在游戏局内运行，skill2/skill3 在此上下文不会触发任何技能。

## 验证方法
进入主菜单 → 成长界面，按 Q/E 确认可以在「通用加成」和「英雄技能树」面板之间切换。
