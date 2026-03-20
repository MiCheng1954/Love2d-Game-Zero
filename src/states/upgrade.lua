--[[
    src/states/upgrade.lua
    升级奖励选择界面，玩家升级时暂停游戏并弹出此界面
    Phase 5：实现两级选择（大类 -> 子选项），键盘方向键导航
]]

local UpgradeConfig = require("config.upgrades")
local Input         = require("src.systems.input")
local Font          = require("src.utils.font")

local Upgrade = {}

-- 界面阶段枚举
local PHASE_CATEGORY = "category"  -- 选择大类阶段
local PHASE_OPTION   = "option"    -- 选择子选项阶段

-- 进入升级状态时调用
-- @param data: 上下文数据，需包含 player（玩家实例）、onDone（完成回调）
--              可选 onWeaponDrop(weapon) 回调：获得新武器时推送背包放置界面
function Upgrade:enter(data)
    self._player       = data.player
    self._onDone       = data.onDone
    self._onWeaponDrop = data.onWeaponDrop  -- 获得新武器时的回调（Phase 6）
    self._phase        = PHASE_CATEGORY
    self._catIndex     = 1
    self._optIndex     = 1
    self._selCatId     = nil

    -- 灵魂刷新相关
    self._refreshCost   = 10           -- 刷新一次消耗的灵魂
    self._currentOptions = {}          -- 当前展示的子选项列表

    -- 初始化输入（防止上一帧的输入残留触发误操作）
    Input.update()
end

-- 退出升级状态时调用
function Upgrade:exit()
    self._player        = nil
    self._onDone        = nil
    self._onWeaponDrop  = nil
    self._phase         = nil
end

-- 每帧更新升级界面逻辑
-- @param dt: 距上一帧的时间间隔（秒）
function Upgrade:update(dt)
    Input.update()

    if self._phase == PHASE_CATEGORY then
        self:_updateCategoryPhase()
    elseif self._phase == PHASE_OPTION then
        self:_updateOptionPhase()
    end
end

-- 大类选择阶段的输入处理
function Upgrade:_updateCategoryPhase()
    local cats = UpgradeConfig.categories

    -- 上下方向键移动选择
    if Input.isPressed("moveUp") then
        self._catIndex = math.max(1, self._catIndex - 1)
    elseif Input.isPressed("moveDown") then
        self._catIndex = math.min(#cats, self._catIndex + 1)
    end

    -- 确认选择大类，进入子选项阶段
    if Input.isPressed("confirm") then
        self._selCatId = cats[self._catIndex].id
        self._optIndex = 1
        -- 过滤掉 canShow 返回 false 的选项（如背包已满时隐藏扩展选项）
        local all = UpgradeConfig[self._selCatId] or {}
        local filtered = {}
        for _, opt in ipairs(all) do
            if not opt.canShow or opt.canShow(self._player) then
                table.insert(filtered, opt)
            end
        end
        self._currentOptions = filtered
        self._phase = PHASE_OPTION
    end
end

-- 子选项选择阶段的输入处理
function Upgrade:_updateOptionPhase()
    local opts = self._currentOptions

    -- 上下方向键移动选择
    if Input.isPressed("moveUp") then
        self._optIndex = math.max(1, self._optIndex - 1)
    elseif Input.isPressed("moveDown") then
        self._optIndex = math.min(#opts, self._optIndex + 1)
    end

    -- 返回大类选择
    if Input.isPressed("cancel") then
        self._phase = PHASE_CATEGORY
        return
    end

    -- 灵魂刷新子选项（按左键）
    if Input.isPressed("moveLeft") then
        if self._player:spendSouls(self._refreshCost) then
            -- 消耗灵魂成功，重新随机排列子选项
            self:_shuffleOptions()
        end
    end

    -- 确认选择子选项，应用效果并结束
    if Input.isPressed("confirm") then
        local opt = opts[self._optIndex]
        local deferred = false
        if opt and opt.apply then
            -- 传入 ctx，让 apply 可以触发 onWeaponDrop 等回调
            -- apply 返回 true 表示它自己负责后续流程（如推入背包界面），此时不立即调用 _onDone
            local ctx = { onWeaponDrop = self._onWeaponDrop, onDone = self._onDone }
            deferred = opt.apply(self._player, ctx) == true
        end
        -- 仅在非延迟时触发完成回调，返回游戏
        if not deferred and self._onDone then
            self._onDone()
        end
    end
end

-- 打乱当前子选项顺序（灵魂刷新时调用）
function Upgrade:_shuffleOptions()
    local opts = UpgradeConfig[self._selCatId] or {}
    -- 浅拷贝后随机排列
    local copy = {}
    for _, v in ipairs(opts) do
        table.insert(copy, v)
    end
    for i = #copy, 2, -1 do
        local j = math.random(i)
        copy[i], copy[j] = copy[j], copy[i]
    end
    self._currentOptions = copy
    self._optIndex       = 1
end

-- 每帧绘制升级界面
function Upgrade:draw()
    Font.set(16)

    -- 半透明遮罩
    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", 0, 0, 1280, 720)

    -- 标题
    love.graphics.setColor(1, 0.85, 0.1)
    love.graphics.printf(T("upgrade.title"), 0, 80, 1280, "center")

    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.printf(T("hud.level") .. self._player:getLevel(), 0, 116, 1280, "center")

    if self._phase == PHASE_CATEGORY then
        self:_drawCategoryPhase()
    elseif self._phase == PHASE_OPTION then
        self:_drawOptionPhase()
    end

    Font.reset()
end

-- 绘制大类选择界面
function Upgrade:_drawCategoryPhase()
    local cats  = UpgradeConfig.categories
    local baseY = 220   -- 第一个选项的起始 Y
    local cardH = 90    -- 每张卡片的高度
    local cardW = 500   -- 卡片宽度
    local cardX = (1280 - cardW) / 2  -- 卡片居中 X

    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.printf(T("upgrade.cat.label"), 0, 180, 1280, "center")

    for i, cat in ipairs(cats) do
        local cy       = baseY + (i - 1) * (cardH + 16)
        local selected = (i == self._catIndex)

        -- 卡片背景
        if selected then
            love.graphics.setColor(cat.color[1] * 0.3, cat.color[2] * 0.3, cat.color[3] * 0.3, 0.95)
        else
            love.graphics.setColor(0.12, 0.12, 0.16, 0.9)
        end
        love.graphics.rectangle("fill", cardX, cy, cardW, cardH, 8, 8)

        -- 卡片边框
        if selected then
            love.graphics.setColor(cat.color)
        else
            love.graphics.setColor(0.3, 0.3, 0.35)
        end
        love.graphics.rectangle("line", cardX, cy, cardW, cardH, 8, 8)

        -- 大类标签
        if selected then
            love.graphics.setColor(cat.color)
        else
            love.graphics.setColor(0.8, 0.8, 0.8)
        end
        love.graphics.printf(T(cat.labelKey), cardX, cy + 28, cardW, "center")

        -- 选中箭头
        if selected then
            love.graphics.setColor(cat.color)
            love.graphics.print("▶", cardX + 20, cy + 28)
        end
    end

    -- 操作提示
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.printf(T("upgrade.cat.hint"), 0, 630, 1280, "center")
end

-- 绘制子选项选择界面
function Upgrade:_drawOptionPhase()
    local opts  = self._currentOptions
    local cat   = nil
    -- 找到当前大类配置（用于颜色）
    for _, c in ipairs(UpgradeConfig.categories) do
        if c.id == self._selCatId then cat = c break end
    end
    local color = cat and cat.color or {1, 1, 1}

    local baseY = 180
    local cardH = 80
    local cardW = 600
    local cardX = (1280 - cardW) / 2

    -- 大类标题
    love.graphics.setColor(color)
    love.graphics.printf(cat and T(cat.labelKey) or "", 0, 140, 1280, "center")

    for i, opt in ipairs(opts) do
        local cy       = baseY + (i - 1) * (cardH + 12)
        local selected = (i == self._optIndex)

        -- 卡片背景
        if selected then
            love.graphics.setColor(color[1] * 0.25, color[2] * 0.25, color[3] * 0.25, 0.95)
        else
            love.graphics.setColor(0.12, 0.12, 0.16, 0.9)
        end
        love.graphics.rectangle("fill", cardX, cy, cardW, cardH, 8, 8)

        -- 卡片边框
        if selected then
            love.graphics.setColor(color)
        else
            love.graphics.setColor(0.3, 0.3, 0.35)
        end
        love.graphics.rectangle("line", cardX, cy, cardW, cardH, 8, 8)

        -- 选项名称
        if selected then
            love.graphics.setColor(color)
        else
            love.graphics.setColor(0.85, 0.85, 0.85)
        end
        love.graphics.print(T(opt.labelKey), cardX + 20, cy + 12)

        -- 选项描述
        love.graphics.setColor(0.65, 0.65, 0.65)
        love.graphics.print(T(opt.descKey), cardX + 20, cy + 36)

        -- 选中箭头
        if selected then
            love.graphics.setColor(color)
            love.graphics.print("▶", cardX - 20, cy + 22)
        end
    end

    -- 灵魂刷新提示
    love.graphics.setColor(0.4, 0.7, 1.0)
    love.graphics.printf(
        T("upgrade.refresh", self._refreshCost, self._player:getSouls()),
        0, 620, 1280, "center")

    -- 操作提示
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.printf(T("upgrade.opt.hint"), 0, 648, 1280, "center")
end

-- 键盘按下事件（Input 系统统一处理，此处留空）
-- @param key: 按下的键名
function Upgrade:keypressed(key)
end

return Upgrade
