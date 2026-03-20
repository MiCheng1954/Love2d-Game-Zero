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
        if not proj._isDead then
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
function Collision.enemiesVsPlayer(enemies, player)
    if player:isDead() then return end

    local pr = player.width / 2  -- 玩家碰撞半径

    for _, enemy in ipairs(enemies) do
        if not enemy._isDead then
            if Collision.circleCircle(
                enemy.x, enemy.y, enemy._radius,
                player.x, player.y, pr)
            then
                enemy:tryContactDamage(player)
            end
        end
    end
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

return Collision
