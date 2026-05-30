-- Combat Commands:
local combat = {}
local settings = nil  -- local settings reference

-- Distance at which we consider ourselves "in melee range"
local MELEE_RANGE = 1

function combat.set_settings(cfg)
    settings = cfg

    -- Ensure combat table exists
    settings.combat = settings.combat or {}
    settings.combat.approach = settings.combat.approach or false

    if settings.combat.approach then
        windower.add_to_chat(207, "[AutoBot:Combat] Combat settings loaded. Approach mode ENABLED.")
    else
        windower.add_to_chat(123, "[AutoBot:Combat] Combat settings loaded. Approach mode DISABLED.")
    end
end

windower.register_event('status change', function(new_status)
    if not settings or not settings.combat or not settings.combat.approach then
        return
    end

    -- 1 = engaged
    if new_status == 1 then
        coroutine.schedule(function()
            combat.approach_target()
        end, 0.2)
    end
end)

local approaching = false

function combat.approach_target()
    if not settings.combat or not settings.combat.approach then
        return
    end

    if approaching then return end
    approaching = true

    local function loop()
        local player = windower.ffxi.get_mob_by_target('me')
        local target = windower.ffxi.get_mob_by_target('t')

        if not player or not target then
            windower.ffxi.run(false)
            approaching = false
            return
        end

        -- Always chase if target is NOT engaged (status 0)
        -- Only stop when target IS engaged AND we are in melee range
        local dx = target.x - player.x
        local dy = target.y - player.y
        local distance = math.sqrt(dx*dx + dy*dy)

        if target.status ~= 1 then
            -- Target is pathing / running / repositioning → KEEP CHASING
            windower.ffxi.run(true)
            coroutine.schedule(loop, 0)
            return
        end

        -- Target IS engaged → stop only if in melee range
        if distance > MELEE_RANGE then
            windower.ffxi.run(true)
            coroutine.schedule(loop, 0)
            return
        end

        -- In melee range AND target is engaged → stop
        windower.ffxi.run(false)
        approaching = false
    end

    loop()
end

function combat.assist(target)
    if target then
        windower.send_command('input /assist '..target)

        coroutine.schedule(function()
            local player = windower.ffxi.get_player()
            if player and player.target_index then
                windower.send_command('input /p Target Locked - Engaging Combat.')
                combat.attack()
            else
                windower.send_command('input /p Error: No valid target found.')
            end
        end, 1.5)
    else
        windower.send_command('input /p Error: No target specified for assist.')
    end
end

function combat.attack()
    windower.send_command('input /p Engaging Target.')
    windower.send_command('input /attack')

    -- If approach mode is enabled, start moving toward target
    coroutine.schedule(function()
        combat.approach_target()
    end, 0.5)
end

function combat.turn()
    local player_info = windower.ffxi.get_mob_by_id(windower.ffxi.get_player().id)
    if not player_info then return end

    windower.send_command('input /p Turning Around!')
    windower.send_command('input /lockon')

    local backward_heading = player_rotation + math.pi
    windower.ffxi.turn(backward_heading)

    windower.ffxi.run(true)
    coroutine.schedule(function() windower.ffxi.run(false) end, 0.5)
end

function combat.disengage()
    local player = windower.ffxi.get_player()

    if player.status == 1 then
        windower.send_command('input /p Disengaging Target.')
        windower.send_command('input /attack')
    else
        windower.send_command('input /p Disengage Ignored - I am not engaged!')
    end
end

return combat
