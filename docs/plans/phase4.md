# Phase 4 开发计划 — 掉落物、吸附、经验升级

## 目标
接入掉落物系统、自动吸附、经验升级流程，打通「击杀→掉落→拾取→升级」完整循环。

---

## 一、新建/修改文件汇总

| 文件 | 操作 | 内容 |
|------|------|------|
| `src/entities/pickup.lua` | 新建 | 掉落物类（EXP/SOUL/TRIGGER） |
| `src/systems/experience.lua` | 新建 | 经验升级系统 |
| `src/entities/enemy.lua` | 修改 | 死亡时生成掉落物列表 |
| `src/systems/collision.lua` | 修改 | 击杀返回掉落物数据 |
| `src/entities/player.lua` | 修改 | 移除内置升级逻辑，交由 Experience 系统 |
| `src/states/game.lua` | 修改 | 接入掉落物更新/绘制，升级提示浮窗 |

---

## 二、各模块设计

### 2.1 pickup.lua
掉落物类型：
- `EXP`：经验值，拾取后调用 `player:gainExp(n)`
- `SOUL`：灵魂，拾取后调用 `player:gainSouls(n)`
- `TRIGGER`：特殊事件触发器（Phase 5 对接）

行为：
- 漂浮动画（sin 波动）
- 进入吸附半径后飞向玩家（加速靠近）
- 到达玩家位置触发拾取效果并销毁

### 2.2 experience.lua
```lua
Experience.new(player, onLevelUp)
Experience:gainExp(n)       -- 增加经验，自动判断升级
Experience:_triggerLevelUp() -- 处理升级逻辑（属性成长 + 回调）
```
- 升级时角色基础属性自动成长（由配置表驱动）
- 支持连续升级（一次获得大量经验触发多次）
- 升级回调外部注册，不耦合 UI

### 2.3 升级提示浮窗（game.lua）
- 升级瞬间屏幕中央显示金色 "LEVEL UP!" 浮窗
- 淡出动画（约1秒）
- 不阻断游戏进行

---

## 三、验证步骤
1. 击杀敌人后场景中出现经验/灵魂掉落物
2. 进入吸附半径后掉落物自动飞向玩家
3. 拾取经验后经验条增长
4. 经验满时触发升级，显示 LEVEL UP 浮窗
5. 升级后属性正确成长（HP、攻击力等）
6. 升级回调正确触发（为 Phase 5 升级界面准备）
