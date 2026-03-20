# Phase 5 开发计划 — 升级奖励选择界面

## 目标
实现两级升级奖励选择 UI，接入灵魂刷新机制，修复 StateManager push/pop 相关问题。

---

## 一、新建/修改文件汇总

| 文件 | 操作 | 内容 |
|------|------|------|
| `config/upgrades.lua` | 新建 | 升级奖励配置表（大类→子选项） |
| `src/states/upgrade.lua` | 重写 | 升级选择界面，两阶段状态机 |
| `src/states/stateManager.lua` | 修改 | 新增 push/pop 覆盖层机制 |
| `src/states/game.lua` | 修改 | 升级改用 push/pop，_pendingUpgrade 延迟处理 |

---

## 二、各模块设计

### 2.1 config/upgrades.lua
结构：大类（category）→子选项（option）
```lua
{
  id = "weapon",
  labelKey = "upgrade.category.weapon",
  options = {
    { id="weapon_new_basic", labelKey="...", descKey="...", apply=function(player) ... end },
    { id="weapon_upgrade",   labelKey="...", descKey="...", apply=function(player) ... end },
  }
}
```
配置驱动，新增奖励只需添加配置行，不改逻辑。

### 2.2 upgrade.lua（两阶段状态机）
- **阶段一**：显示大类列表（武器相关/属性相关/技能相关）
- **阶段二**：显示选中大类的子选项列表
- 操作：↑↓ 导航，Enter 确认，ESC 返回大类
- 灵魂刷新：← 键，消耗10灵魂，重新随机子选项顺序

### 2.3 StateManager push/pop
```lua
StateManager.push(name, data)   -- 推入覆盖层，不调用底层 exit
StateManager.pop()              -- 弹出覆盖层，不调用底层 enter
```
事件转发只传递给栈顶状态。

### 2.4 _pendingUpgrade 机制（game.lua）
- 升级回调触发时，设置 `_pendingUpgrade = true`
- 当帧 `update()` 末尾统一检测并执行 `StateManager.push("upgrade")`
- 避免在回调中途直接切换状态导致帧内崩溃

---

## 三、验证步骤
1. 升级时画面暂停，弹出大类选择界面
2. ↑↓ 选择大类，Enter 进入子选项
3. ESC 返回大类选择
4. 选中子选项后 apply() 执行，关闭界面继续游戏
5. ← 消耗灵魂刷新子选项顺序
6. 升级界面关闭后，玩家数据（等级/HP/武器）完整保留
