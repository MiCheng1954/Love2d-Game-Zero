# Phase 2 开发计划 — 玩家移动与摄像机

## 目标
接入输入系统、实体基类、玩家类、摄像机系统，实现玩家在场景中的基本移动。

---

## 一、新建/修改文件汇总

| 文件 | 操作 | 内容 |
|------|------|------|
| `src/systems/input.lua` | 新建 | 输入抽象层，WASD 映射到动作，预留手柄/鼠标接口 |
| `src/entities/entity.lua` | 新建 | 实体基类，10项基础属性，通用方法 |
| `src/entities/player.lua` | 新建 | 玩家类，继承 Entity，WASD 移动 |
| `src/systems/camera.lua` | 新建 | 摄像机，平滑跟随玩家 |
| `src/states/game.lua` | 修改 | 接入以上系统，背景参考网格，HUD |

---

## 二、各模块设计

### 2.1 input.lua
```lua
-- 支持的动作
Input.actions = {
    moveUp, moveDown, moveLeft, moveRight,
    confirm, cancel,
}
-- 接口
Input.update()              -- 每帧调用，刷新状态
Input.isDown(action)        -- 持续按下
Input.isPressed(action)     -- 本帧刚按下
Input.isReleased(action)    -- 本帧刚松开
```

### 2.2 entity.lua（基类）
基础属性：`x, y, hp, maxHp, speed, attack, defense, radius, isDead, color`
通用方法：`takeDamage(dmg)`, `heal(amt)`, `onDeath()`, `getBounds()`, `draw()`, `update(dt)`

### 2.3 player.lua
- 继承 Entity
- WASD 移动，速度由 `speed` 属性控制
- 经验/灵魂获取接口：`gainExp(n)`, `gainSouls(n)`
- 升级回调：`onLevelUp`

### 2.4 camera.lua
- `Camera.attach()` / `Camera.detach()`：分离世界层与 UI 层
- 平滑跟随：`lerp(cam.x, target.x, 0.1)`

### 2.5 HUD（game.lua）
- HP 条、经验条、等级、灵魂数量
- 使用 `Camera.detach()` 后绘制，始终固定在屏幕坐标

---

## 三、验证步骤
1. WASD 控制玩家移动，摄像机平滑跟随
2. 背景参考网格随摄像机滚动
3. HUD 固定在屏幕角落不随摄像机移动
4. Windows 中文 IME 下 WASD 正常响应（需禁用 TextInput）
