--[[
    src/systems/experience.lua
    经验与升级系统，负责处理升级触发、属性成长和升级奖励弹出
    与 Player 解耦：Player 存储数据，此系统负责触发和通知
]]

local Experience = {}
Experience.__index = Experience

local Log = require("src.utils.log")

-- 构造函数，创建一个新的经验系统实例
-- @param player: 绑定的玩家实例
function Experience.new(player)
    local self = setmetatable({}, Experience)

    self._player         = player   -- 绑定的玩家
    self._onLevelUp      = nil      -- 升级回调函数（外部注册）
    self._pendingLevelUp = false    -- 是否有待处理的升级

    return self
end

-- 注册升级回调，升级时由外部决定如何弹出奖励界面
-- @param callback: 回调函数，参数为 (player, newLevel)
function Experience:onLevelUp(callback)
    self._onLevelUp = callback
end

-- 每帧检测升级状态
-- @param dt: 距上一帧的时间间隔（秒）
function Experience:update(dt)
    -- 支持连续升级（一次性拾取大量经验时）
    while self._player._exp >= self._player._expToNext do
        self:_triggerLevelUp()
    end
end

-- 触发升级流程
function Experience:_triggerLevelUp()
    -- 扣除经验，提升等级
    self._player._exp      = self._player._exp - self._player._expToNext
    self._player._level    = self._player._level + 1
    self._player._expToNext = math.floor(self._player._expToNext * 1.2)

    -- 基础属性自动成长
    self:_applyLevelUpGrowth()

    Log.info(string.format("玩家升级 -> Lv%d  HP:%d/%d  ATK:%d",
        self._player._level, self._player.hp,
        self._player.maxHp, self._player.attack))

    -- 触发升级回调（弹出奖励界面）
    if self._onLevelUp then
        self._onLevelUp(self._player, self._player._level)
    end
end

-- 升级时基础属性自动成长
function Experience:_applyLevelUpGrowth()
    local p = self._player

    p.maxHp        = p.maxHp  + 10          -- 最大生命值 +10
    p.hp           = math.min(              -- 升级回复 20 点血量
        p.hp + 20, p.maxHp)
    p.attack       = p.attack + 2           -- 攻击力 +2
    p.pickupRadius = p.pickupRadius + 2     -- 吸附半径微增
end

return Experience
