--[[
    src/entities/boss.lua
    Boss 实体类，继承自 Enemy
    Phase 9：每个 Boss 拥有独立技能计时器列表，屏幕顶部大血条，死亡触发胜利条件
]]

local Enemy  = require("src.entities.enemy")
local Pickup = require("src.entities.pickup")
local Font   = require("src.utils.font")

local Boss = setmetatable({}, { __index = Enemy })
Boss.__index = Boss

-- 构造函数
-- @param x:   初始世界坐标 X
-- @param y:   初始世界坐标 Y
-- @param cfg: Boss 配置（来自 config/bosses.lua 的一个 entry）
function Boss.new(x, y, cfg)
    -- 构造一个虚拟的 "enemyCfg" 格式，复用 Enemy 基础字段初始化
    -- Boss 不走 EnemyConfig 查表，直接传入 cfg
    local self = setmetatable({}, Boss)

    -- 手动调用 Entity 基类构造
    local Entity = require("src.entities.entity")
    local base = Entity.new(x, y)
    for k, v in pairs(base) do
        self[k] = v
    end
    setmetatable(self, Boss)

    -- 基础战斗属性
    self._typeName    = cfg.id
    self._bossName    = cfg.nameKey         -- i18n key，渲染时通过 T() 访问
    self.maxHp        = cfg.hp
    self.hp           = cfg.hp
    self.attack       = cfg.attack
    self.defense      = cfg.defense
    self.speed        = cfg.speed
    self._radius      = cfg.radius
    self.width        = cfg.radius * 2
    self.height       = cfg.radius * 2
    self._color       = cfg.color
    self._expDrop     = cfg.expDrop
    self._soulDrop    = cfg.soulDrop
    self._damage      = cfg.attack          -- 接触伤害 = attack
    self._contactRate = 1.0                 -- Boss 接触伤害冷却 1 秒
    self._contactTimer = 0

    -- Phase 9：精英/远程标记（Boss 不是普通精英/远程）
    self._isElite   = false
    self._isRanger  = false

    -- Boss 专属
    self._isFinal   = cfg.isFinal or false  -- 最终 Boss 标记
    self._isBoss    = true                  -- 标识为 Boss（供 game.lua 判断）
    self._isBossKill = false                -- 死亡时设为 true，供 game.lua 检测

    -- 技能系统：每个技能独立计时
    self._skills = {}
    if cfg.skills then
        for _, sk in ipairs(cfg.skills) do
            table.insert(self._skills, {
                id       = sk.id,
                interval = sk.interval,
                timer    = sk.interval * math.random(),  -- 随机偏移初始计时，避免全部同时触发
                effect   = sk.effect,
            })
        end
    end

    -- 冲刺状态（charge 技能用）
    self._chargeDx    = 0
    self._chargeDy    = 0
    self._chargeTimer = 0
    self._chargeSpeed = 0

    -- 视觉闪光计时（stomp/punch 命中用）
    self._stompFlash = 0
    self._punchFlash = 0

    -- Phase 12：冲锋者蓄力计时（>0 表示蓄力中，倒计时结束后执行冲刺）
    self._windupTimer = 0

    -- AI 状态
    self._target          = nil
    self._projectileList  = nil  -- 由 game.lua 注入共享投射物列表
    self._summonPending   = 0    -- 待生成小兵数量（summon 技能写入）

    return self
end

-- 设置追踪目标
function Boss:setTarget(target)
    self._target = target
end

-- 设置共享投射物列表
function Boss:setProjectileList(list)
    self._projectileList = list
end

-- 每帧更新 Boss 逻辑
-- @param dt: 帧时间（秒）
function Boss:update(dt)
    if self._isDead then return end

    -- 接触伤害冷却
    if self._contactTimer > 0 then
        self._contactTimer = self._contactTimer - dt
    end

    -- 视觉闪光倒计时
    if self._stompFlash > 0 then self._stompFlash = self._stompFlash - dt end
    if self._punchFlash > 0 then self._punchFlash = self._punchFlash - dt end

    -- 移动：冲刺状态 > 蓄力等待 > 普通追踪
    if self._windupTimer and self._windupTimer > 0 then
        -- 蓄力阶段：停滞，倒计时结束后进入冲刺
        self._windupTimer = self._windupTimer - dt
        if self._windupTimer <= 0 then
            self._windupTimer = 0
            -- 蓄力结束，开始冲刺 0.5s
            self._chargeTimer = 0.5
            self._chargeSpeed = 800
        end
        -- 蓄力期闪烁（视觉反馈）
        self._stompFlash = 0.1
    elseif self._chargeTimer > 0 then
        self._chargeTimer = self._chargeTimer - dt
        self.x = self.x + self._chargeDx * self._chargeSpeed * dt
        self.y = self.y + self._chargeDy * self._chargeSpeed * dt
    else
        self:_chase(dt)
    end

    -- 技能计时与触发
    for _, sk in ipairs(self._skills) do
        sk.timer = sk.timer + dt
        if sk.timer >= sk.interval then
            sk.timer = sk.timer - sk.interval
            sk.effect(self, self._target, self._projectileList)
        end
    end
end

-- 普通追踪（复用逻辑，不通过 Enemy._chase 避免 self 混乱）
function Boss:_chase(dt)
    if not self._target then return end
    local dx   = self._target.x - self.x
    local dy   = self._target.y - self.y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < 1 then return end
    self.x = self.x + (dx / dist) * self.speed * dt
    self.y = self.y + (dy / dist) * self.speed * dt
end

-- 接触伤害
function Boss:tryContactDamage(target)
    if self._isDead then return end
    if self._contactTimer > 0 then return end
    target:takeDamage(self._damage)
    self._contactTimer = self._contactRate
end

-- 绘制 Boss 本体（世界空间）
function Boss:draw()
    if not self._isVisible or self._isDead then return end

    local c = self._color

    -- 外圈光晕（双层）
    love.graphics.setColor(c[1], c[2], c[3], 0.2)
    love.graphics.circle("fill", self.x, self.y, self._radius + 14)
    love.graphics.setColor(c[1], c[2], c[3], 0.6)
    love.graphics.setLineWidth(3)
    love.graphics.circle("line", self.x, self.y, self._radius + 14)
    love.graphics.setLineWidth(1)

    -- 震地/重拳闪光效果
    local flash = math.max(self._stompFlash, self._punchFlash)

    -- Phase 12：冲锋者蓄力时显示橙色警告光圈
    if self._windupTimer and self._windupTimer > 0 then
        local pulse = math.abs(math.sin(self._windupTimer * 20))
        love.graphics.setColor(1.0, 0.4, 0.0, 0.55 * pulse)
        love.graphics.circle("fill", self.x, self.y, self._radius + 22)
    end

    if flash > 0 then
        love.graphics.setColor(1, 1, 1, flash * 2)
        love.graphics.circle("fill", self.x, self.y, self._radius + 8)
    end

    -- 身体
    love.graphics.setColor(c)
    love.graphics.circle("fill", self.x, self.y, self._radius)

    -- 边框
    love.graphics.setColor(math.min(1, c[1]*1.4), math.min(1, c[2]*1.4), math.min(1, c[3]*1.4))
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", self.x, self.y, self._radius)
    love.graphics.setLineWidth(1)

    -- Boss 标识"★"（使用小字体绘制）
    Font.set(14)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.printf("★", self.x - 10, self.y - 8, 20, "center")
    Font.reset()

    love.graphics.setColor(1, 1, 1, 1)
end

-- 绘制屏幕顶部 Boss 大血条（UI 空间，由 game.lua 在 HUD 层调用）
-- @param screenW: 屏幕宽度
-- @param bossName: Boss 显示名称（已 T() 转换）
function Boss:drawHUD(screenW, bossName)
    if self._isDead then return end

    local barW  = screenW * 0.6
    local barH  = 18
    local bx    = (screenW - barW) / 2
    local by    = 12
    local ratio = math.max(0, self.hp / self.maxHp)
    local c     = self._color

    -- 背景
    love.graphics.setColor(0.1, 0.1, 0.1, 0.85)
    love.graphics.rectangle("fill", bx - 2, by - 2, barW + 4, barH + 4, 3, 3)

    -- 血条底色
    love.graphics.setColor(0.25, 0.05, 0.05)
    love.graphics.rectangle("fill", bx, by, barW, barH, 2, 2)

    -- 血条前景（Boss 颜色）
    love.graphics.setColor(c[1] * 0.9, c[2] * 0.9, c[3] * 0.9)
    if ratio > 0 then
        love.graphics.rectangle("fill", bx, by, barW * ratio, barH, 2, 2)
    end

    -- 血条边框
    love.graphics.setColor(0.8, 0.8, 0.8, 0.6)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", bx, by, barW, barH, 2, 2)

    -- Boss 名称 + HP 数字
    Font.set(13)
    love.graphics.setColor(1, 1, 1, 1)
    local label = (bossName or self._typeName) .. "   " .. self.hp .. " / " .. self.maxHp
    love.graphics.printf(label, bx, by + 2, barW, "center")
    Font.reset()

    love.graphics.setColor(1, 1, 1, 1)
end

-- 死亡回调
-- @return pickups: 掉落物列表
function Boss:onDeath()
    self._isDead        = true
    self._isVisible     = false
    self._dropProcessed = false
    self._isBossKill    = true   -- 通知 game.lua 发生了 Boss 击杀

    local pickups = {}

    if self._expDrop > 0 then
        -- Boss 掉落以爆炸方式散开
        for i = 1, 5 do
            local angle = (i / 5) * math.pi * 2
            local r     = math.random(10, 30)
            table.insert(pickups, Pickup.new(
                self.x + math.cos(angle) * r,
                self.y + math.sin(angle) * r,
                Pickup.TYPE.EXP,
                math.floor(self._expDrop / 5)))
        end
    end

    if self._soulDrop > 0 then
        for i = 1, 3 do
            table.insert(pickups, Pickup.new(
                self.x + math.random(-20, 20),
                self.y + math.random(-20, 20),
                Pickup.TYPE.SOUL,
                math.floor(self._soulDrop / 3)))
        end
    end

    -- Boss 必定掉落 2 个触发器
    for i = 1, 2 do
        table.insert(pickups, Pickup.new(
            self.x + math.random(-25, 25),
            self.y + math.random(-25, 25),
            Pickup.TYPE.TRIGGER,
            1))
    end

    return pickups
end

-- 获取击杀经验值掉落量
function Boss:getExpDrop()
    return self._expDrop
end

-- 获取击杀灵魂掉落量
function Boss:getSoulDrop()
    return self._soulDrop
end

return Boss
