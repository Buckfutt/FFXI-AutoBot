-- Combat Commands:
local combat = {}

function combat.assist(target)
    if target then
        windower.send_command('input /assist '..target)

        -- Wait briefly before engaging, ensuring assist completes
        coroutine.schedule(function()
            local player = windower.ffxi.get_player()
            if player and player.target_index then
				windower.send_command('input /p Target Locked - Engaging Combat.')
                combat.attack() -- Explicitly call attack function
            else
				windower.send_command('input /p Error: No valid target found.')
            end
        end, 1.5) -- Wait 0.5s before checking target status
    else
		windower.send_command('input /p Error: No target specified for assist.')
    end
end

function combat.attack()
	windower.send_command('input /p Engaging Target.')
	windower.send_command('input /attack')
end

function combat.turn()
	local player_info = windower.ffxi.get_mob_by_id(windower.ffxi.get_player().id)
    if not player_info then return end
	
	windower.send_command('input /p Turning Around!')
	
	windower.send_command('input /lockon')
	
    local backward_heading = player_rotation + math.pi -- Reverse direction
    windower.ffxi.turn(backward_heading) -- Face opposite direction

    -- Move backward briefly (0.75 seconds)
    windower.ffxi.run(true)
    coroutine.schedule(function() windower.ffxi.run(false) end, 0.5)
end

function combat.disengage()
    local player = windower.ffxi.get_player()

    if player.status == 1 then -- Status 1 means engaged
		windower.send_command('input /p Disengaging Target.')
        windower.send_command('input /attack')
    else
		windower.send_command('input /p Disengage Ignored - I am not engaged!')
    end
end

return combat