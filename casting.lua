-- Casting Commands:
local casting = {}

function casting.cast_spell(spell, target)
    target = target or '<me>' -- Ensure proper self-targeting

    --windower.add_to_chat(207, "Casting ["..spell.."] on ["..target.."]")
	windower.send_command('input /p Casting ['..spell..'] on ['..target..']')

    -- Directly format and execute the casting command
    local command = 'input /ma "'..spell..'" '..target
    windower.send_command(command) -- Execute exactly as structured
end

function casting.stop_casting()
	windower.send_command('input /p Canceling Casting...')
    windower.send_command('input /heal')
    windower.send_command('wait 2; input /heal')
end

return casting