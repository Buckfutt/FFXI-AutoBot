-- interaction.lua: Module for interacting with NPCs and simulating key presses

local interaction = {}
local packets = require('packets')  -- Default packets reference

-- Allow packet reference updates.
function interaction.set_packets(pkt)
    packets = pkt
end

-- Tab to Target
function interaction.target_npc(npc_name)
    npc_name = npc_name:lower()

    local attempts = 0
    local max_attempts = 100   -- enough to cycle through everything once

    local function try_cycle()
        attempts = attempts + 1

        local t = windower.ffxi.get_mob_by_target('t')
        if t and t.name and t.name:lower():find(npc_name, 1, true) then
            windower.add_to_chat(207, "[Interaction] Targeted: " .. t.name)
            return
        end

        if attempts >= max_attempts then
            windower.add_to_chat(123, "[Interaction] Could not find target: " .. npc_name)
            return
        end

        -- Press Tab
        windower.send_command('setkey tab down')
        coroutine.sleep(0.1)
        windower.send_command('setkey tab up')

        -- Try again shortly
        coroutine.schedule(try_cycle, 0.1)
    end

    try_cycle()
end

function interaction.press_key(key)
    local allowed_keys = {
        enter = true,
        up    = true,
        down  = true,
        left  = true,
        right = true,
        tab   = true,	-- Tab
        stab  = true,	-- Shift+Tab (we'll simulate this)
		f1    = true,
        f8    = true,   -- F8
		esc   = true	--Escape
    }
    key = key:lower()
    
    if not allowed_keys[key] then
        windower.add_to_chat(207, "Invalid key: " .. key)
        return
    end

    -- For Shift+Tab, simulate pressing Shift and Tab.
    if key == "stab" then
        windower.send_command('setkey shift down; setkey tab down;')
        coroutine.sleep(0.3)
        windower.send_command('setkey tab up; setkey shift up;')
    else
        windower.send_command('setkey ' .. key .. ' down;')
        coroutine.sleep(0.3)
        windower.send_command('setkey ' .. key .. ' up;')
    end
    
    windower.add_to_chat(207, "Pressed key: " .. key)
end

return interaction