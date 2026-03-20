# Phase 6 开发计划 — 武器背包系统

## Context
Phase 5/5.1 已完成。Phase 6 目标：实现完整武器背包流程。
- 背包初始 2×2，最大成长至 6×8（高6宽8）
- 武器有形状（异形格子，支持旋转）
- 相邻增益预留接口（Phase 7 实装）
- 升级时可获得新武器并放入背包
- 武器影响实际自动攻击参数
- TAB 键打开背包 UI

### 核心设计决策
- **全员装备**：背包中所有武器均处于装备状态，不存在"选中激活"概念
- 每把武器拥有独立攻击计时器，独立锁定最近敌人，独立开火
- **索敌接口抽象**：`_findNearestEnemyInRange(range)` 作为独立函数，Phase 7 可替换

---

## 一、数据结构

### 武器形状（shape）
用 `{row, col}` 坐标数组描述（左上角为 0,0）：
```lua
shape = {{0,0}}             -- 单格
shape = {{0,0},{0,1}}       -- 横向 1×2
shape = {{0,0},{1,0},{1,1}} -- L形
```
旋转 90°（顺时针）：`(r,c) → (maxC-c, r)`，旋转后重新计算包围盒原点。

### 背包字段（player._bag）
```lua
player._bag = {
  cols    = 2,    -- 当前宽（最大 8）
  rows    = 2,    -- 当前高（最大 6）
  _grid   = {},   -- [row][col] = instanceId 或 nil
  _weapons = {},  -- instanceId → weapon 实例
}
```

---

## 二、初始武器定义（6种）

| ID | 名称 | 形状 | 特色 |
|----|------|------|------|
| `pistol`  | 手枪   | 1×1 单格     | 基础平衡 |
| `shotgun` | 散弹枪 | 1×2 横       | 高伤，射速慢，近程 |
| `smg`     | 冲锋枪 | 1×2 横       | 低伤，射速极快 |
| `sniper`  | 狙击枪 | 1×3 横       | 极高单发，极慢射速，超远程 |
| `cannon`  | 炮     | L形 3格      | 高伤，慢速 |
| `laser`   | 激光枪 | T形 4格      | 高射速，中等伤害 |

---

## 三、新建/修改文件汇总

| 文件 | 操作 | 内容 |
|------|------|------|
| `config/weapons.lua` | 新建 | 6种武器配置表 |
| `config/i18n/zh.lua` | 修改 | 补充武器/背包文本 key |
| `src/entities/weapon.lua` | 新建 | 武器实例类（含旋转、独立攻击计时器） |
| `src/systems/bag.lua` | 新建 | 背包管理（放置/移除/碰撞检测/扩展） |
| `src/states/bagUI.lua` | 新建 | 背包界面状态（TAB，push 覆盖，三模式） |
| `src/entities/player.lua` | 修改 | 新增 `_bag` 初始化；`getBag()` |
| `src/states/game.lua` | 修改 | 全员装备多武器独立攻击；暂停功能；TAB接入 |
| `src/systems/input.lua` | 修改 | 新增 rotateWeapon/pause 动作 |
| `config/upgrades.lua` | 修改 | weapon 大类子选项实装，deferred 模式 |
| `src/states/upgrade.lua` | 修改 | canShow 过滤，deferred onDone 支持 |
| `src/states/console.lua` | 修改 | 新增 weapon/set 指令，SET_ATTRS 数据驱动 |
| `src/systems/experience.lua` | 修改 | 升级事件 Log 记录 |
| `main.lua` | 修改 | 注册 bagUI 状态 |
| `docs/DEVLOG.md` | 修改 | 记录本阶段变更 |

---

## 四、各模块详细设计

### 4.1 config/weapons.lua
```lua
return {
  pistol = {
    id="pistol", nameKey="weapon.pistol.name", descKey="weapon.pistol.desc",
    shape={{0,0}}, color={0.5,0.8,1},
    damage=20, attackSpeed=1.0, bulletSpeed=450, range=350,
    maxLevel=3, levelBonus={damage=10},
  },
  shotgun = { shape={{0,0},{0,1}}, damage=45, attackSpeed=0.4, bulletSpeed=380, range=220, ... },
  smg     = { shape={{0,0},{0,1}}, damage=8,  attackSpeed=3.0, bulletSpeed=500, range=300, ... },
  sniper  = { shape={{0,0},{0,1},{0,2}}, damage=120, attackSpeed=0.25, bulletSpeed=700, range=700, ... },
  cannon  = { shape={{0,0},{1,0},{1,1}}, damage=80,  attackSpeed=0.5,  bulletSpeed=350, range=400, ... },
  laser   = { shape={{0,1},{1,0},{1,1},{1,2}}, damage=12, attackSpeed=4.0, bulletSpeed=600, range=320, ... },
}
```

### 4.2 src/entities/weapon.lua
```lua
Weapon.new(configId)                    -- 从配置创建实例，分配唯一 instanceId
Weapon.resetIdCounter()                 -- 新游戏时重置 ID 计数
Weapon:rotate()                         -- 顺时针 90°：(r,c) → (maxC-c, r)
Weapon:getBounds()                      -- 返回包围盒 {rows, cols}
Weapon:getCells(originRow, originCol)   -- 返回所有占格的 {row,col} 列表
Weapon:getEffectiveDamage(playerAttack) -- 武器伤害 + 玩家基础攻击
Weapon:tickAttack(dt)                   -- 推进计时器，返回本帧射击次数
Weapon:levelUp()                        -- 等级+1，应用 levelBonus
```

### 4.3 src/systems/bag.lua
```lua
Bag.new(rows, cols)
Bag:canPlace(weapon, row, col)  -- 检测合法性（不越界、不冲突）
Bag:place(weapon, row, col)     -- 清除旧位置 → 写入新位置 → 记录锚点
Bag:remove(weapon)              -- 清除网格，清空锚点
Bag:expand(dRows, dCols)        -- 扩展（不超 MAX_ROWS=6, MAX_COLS=8）
Bag:getWeaponAt(row, col)       -- 返回武器实例或 nil
Bag:getAllWeapons()              -- 返回所有武器实例列表（按 instanceId 排序）
Bag:hasSpace(weapon)            -- 判断是否能放入
```

### 4.4 src/states/bagUI.lua
三种模式（通过 `data.mode` 参数进入）：
- **BROWSE 模式**（TAB 打开）：方向键移动光标，Enter 拾起武器进入 PLACE，ESC 关闭
- **PLACE 模式**（升级获得武器/BROWSE内拾起）：方向键移动预览，R 旋转，Enter 放置，ESC 丢弃/还原
- **SELECT 模式**（武器强化选武器）：方向键移动，Enter 确认（受 filter 过滤），ESC 取消

布局（1280×720）：
- 左侧：背包网格（每格 64px，GRID_X=80，GRID_Y=120）
- 右侧：选中武器详情（名称/描述/等级/伤害/射速/弹速/射程）
- 底部：操作提示栏

绘制规则：
- 武器格：武器颜色填充，锚点格显示 `Lv{n}`
- SELECT 模式：不可选武器变暗（颜色×0.25）
- PLACE 预览：绿色=可放，红色=冲突

### 4.5 自动攻击改造（game.lua）
```lua
-- 背包有武器时：所有武器独立开火
for _, weapon in ipairs(bag:getAllWeapons()) do
  local shots = weapon:tickAttack(dt)
  if shots > 0 then
    local target = Game._findNearestEnemyInRange(weapon.range)
    if target then
      -- 生成投射物
    end
  end
end

-- 背包为空时：使用 FALLBACK 参数
```

### 4.6 升级流程（deferred 模式）
- `apply()` 返回 `true` 表示延迟 onDone，自行控制流程
- `upgrade.lua` 检查返回值决定是否立即调用 `_onDone()`
- ctx 传入：`{ onWeaponDrop, onDone }`

### 4.7 控制台新增指令
- `weapon <id>`：创建武器实例放入背包（自动扫描可放位置）
- `set <attr> <val>`：数据驱动属性修改，11项属性，自动范围限制

---

## 五、验证步骤
1. 进入游戏升级 → 选「武器强化→获得新武器」→ 背包弹出（PLACE 模式），可放置武器
2. TAB 键打开背包（BROWSE 模式），光标移动查看武器详情
3. BROWSE 模式：Enter 拾起武器 → PLACE 子模式 → 放置/ESC还原
4. R 键旋转武器，预览形状正确变化（顺时针90°）
5. 背包放满后放置显示红色冲突预览
6. 升级选「强化现有武器」→ SELECT 模式选择 → 武器 level+1
7. 升级选「背包扩展」→ 背包行列+1；背包达最大值时该选项隐藏
8. P 键暂停/恢复，暂停时游戏逻辑停止，TAB 仍可打开背包
9. 控制台 `weapon pistol` 成功放入手枪
10. 控制台 `set speed 500` 正确修改玩家速度
11. 多武器同时在背包：各自独立攻击计时，各自独立开火
