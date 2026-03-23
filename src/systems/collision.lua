--[[
    src/systems/collision.lua
    碰撞检测系统，提供圆形碰撞检测和批量碰撞处理
    所有碰撞逻辑集中在此，实体本身不处理碰撞
]]

local Collision = {}

-- 检测两个圆形实体是否发生碰撞
-- @param ax:      实体 A 的中心 X
-- @param ay:      实体 A 的中心 Y
-- @param aRadius: 实体 A 的碰撞半径
-- @param bx:      实体 B 的中心 X
-- @param by:      实体 B 的中心 Y
-- @param bRadius: 实体 B 的碰撞半径
-- @return boolean，是否碰撞
function Collision.circleCircle(ax, ay, aRadius, bx, by, bRadius)
    local dx   = bx - ax
    local dy   = by - ay
    local dist = math.sqrt(dx * dx + dy * dy)
    return dist <= (aRadius + bRadius)
end

-- 检测投射物列表与敌人列表之间的碰撞
-- 命中后投射物销毁，敌人扣血，收集击杀列表
-- @param projectiles: 投射物列表
-- @param enemies:     敌人列表
-- @return kills: 本次检测中被击杀的敌人列表（含掉落物数据）
function Collision.projectilesVsEnemies(projectiles, enemies)
    local kills = {}  -- 本次检测中被击杀的敌人

    for _, proj in ipairs(projectiles) do
        -- Bug#41：跳过敌方投射物，敌方子弹不与敌人发生碰撞
        if not proj._isDead and not proj._isEnemyProjectile then
            for _, enemy in ipairs(enemies) do
                if not enemy._isDead then
                    -- 检测圆形碰撞
                    if Collision.circleCircle(
                        proj.x,  proj.y,  proj._radius,
                        enemy.x, enemy.y, enemy._radius)
                    then
                        -- 投射物命中敌人
                        proj:onHit(enemy)

                        -- 检测敌人是否被击杀，触发掉落
                        if enemy:isDead() then
                            local pickups = enemy:onDeath()
                            table.insert(kills, {
                                enemy   = enemy,    -- 被击杀的敌人
                                pickups = pickups,  -- 生成的掉落物列表
                            })
                        end

                        break  -- 一颗子弹只打一个敌人
                    end
                end
            end
        end
    end

    return kills
end

-- 检测敌人列表与玩家之间的接触伤害碰撞
-- @param enemies: 敌人列表
-- @param player:  玩家实体
-- @return totalDmg: 本帧玩家实际受到的总伤害（Phase 8 供技能 onHit 使用）
function Collision.enemiesVsPlayer(enemies, player)
    if player:isDead() then return 0 end

    local pr       = player.width / 2  -- 玩家碰撞半径
    local totalDmg = 0
    local hpBefore = player.hp

    for _, enemy in ipairs(enemies) do
        if not enemy._isDead then
            if Collision.circleCircle(
                enemy.x, enemy.y, enemy._radius,
                player.x, player.y, pr)
            then
                -- Phase 8：魔法护罩吸收下一次伤害
                if player._shieldActive and not player._shieldAbsorbed then
                    player._shieldAbsorbed = true
                    player._shieldActive   = false
                    player._shieldTimer    = 0
                    -- 跳过此次伤害
                else
                    enemy:tryContactDamage(player)
                end
            end
        end
    end

    -- 统计实际扣减
    totalDmg = math.max(0, hpBefore - player.hp)
    return totalDmg
end

-- 清理列表中所有已死亡的实体
-- @param list: 实体列表（原地修改）
function Collision.clearDead(list)
    for i = #list, 1, -1 do
        if list[i]._isDead then
            table.remove(list, i)
        end
    end
end

-- Phase 9：检测玩家投射物与 Boss 之间的碰撞
-- 只检测非敌方子弹（_isEnemyProjectile == nil/false）
-- @param projectiles: 投射物列表
-- @param boss:        Boss 实体
-- @return pickups: Boss 死亡时生成的掉落物列表（未死亡返回 nil）
function Collision.projectilesVsBoss(projectiles, boss)
    if not boss or boss._isDead then return nil end

    for _, proj in ipairs(projectiles) do
        if not proj._isDead and not proj._isEnemyProjectile then
            if Collision.circleCircle(
                proj.x,  proj.y,  proj._radius,
                boss.x,  boss.y,  boss._radius)
            then
                -- 命中 Boss：手动扣血（不通过 onHit，避免 takeDamage→onDeath 双重触发）
                if not proj._hit then
                    proj._hit    = true
                    proj._isDead = true
                    -- 计算暴击
                    local isCrit = math.random() < (proj._critRate or 0.05)
                    local origCrit = nil
                    if isCrit and proj._critDamage and proj._critDamage ~= boss.critDamage then
                        origCrit      = boss.critDamage
                        boss.critDamage = proj._critDamage
                    end
                    local actual = math.max(1, (proj._damage or 10) - (boss.defense or 0))
                    if isCrit then actual = math.floor(actual * boss.critDamage) end
                    if origCrit ~= nil then boss.critDamage = origCrit end
                    boss.hp = boss.hp - actual
                    if boss.hp <= 0 then
                        boss.hp = 0
                        -- Boss 死亡：收集掉落物并返回
                        local pickups = boss:onDeath()
                        return pickups or {}
                    end
                end
            end
        end
    end

    return nil
end

-- Phase 9：检测敌方投射物与玩家之间的碰撞
-- @param projectiles: 投射物列表（含玩家和敌方）
-- @param player:      玩家实体
-- @return totalDmg: 玩家本帧从敌方投射物受到的总伤害
function Collision.enemyProjectilesVsPlayer(projectiles, player)
    if player:isDead() then return 0 end

    local pr       = player.width / 2
    local hpBefore = player.hp

    for _, proj in ipairs(projectiles) do
        if not proj._isDead and proj._isEnemyProjectile then
            if Collision.circleCircle(
                proj.x,  proj.y,  proj._radius,
                player.x, player.y, pr)
            then
                -- 魔法护罩吸收
                if player._shieldActive and not player._shieldAbsorbed then
                    player._shieldAbsorbed = true
                    player._shieldActive   = false
                    player._shieldTimer    = 0
                    proj._isDead = true
                else
                    player:takeDamage(proj._damage or 10)
                    proj._isDead = true
                end
            end
        end
    end

    return math.max(0, hpBefore - player.hp)
end

return Collision
