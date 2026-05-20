-- interaction.lua: Module for interacting with NPCs and simulating key presses

local interaction = {}
local packets = require('packets')  -- Default packets reference

-- Allow packet reference updates.
function interaction.set_packets(pkt)
    packets = pkt
end

-- Function to target an NPC by name using packet injection.
function interaction.target_npc(npc_name)
    -- Clean up the provided target name: trim and convert to lowercase.
    npc_name = npc_name:lower():gsub("^%s+", ""):gsub("%s+$", "")
    
    local mob_array = windower.ffxi.get_mob_array()
    local target = nil
    
    -- Loop over every mob in the mob array.
    for _, mob in ipairs(mob_array) do
        if mob.name then
            -- Clean up the mob name
            local mob_name = mob.name:lower():gsub("^%s+", ""):gsub("%s+$", "")
            -- Instead of requiring an exact match, we use string.find so a substring match will succeed.
            if mob_name:find(npc_name, 1, true) then
                target = mob
                break
            end
        end
    end

    if target then
        local player = windower.ffxi.get_player()
        if player then
            coroutine.schedule(function()
                -- Build and inject a packet similar to your monster targeting code.
                local pkt = packets.new('incoming', 0x058, {
                    ['Player'] = player.id,
                    ['Target'] = target.id,
                    ['Player Index'] = player.index,
                })
                packets.inject(pkt)
                windower.add_to_chat(207, "Packet Targeting NPC: " .. target.name)
            end, 0.2)
        else
            windower.add_to_chat(207, "Error: Player not found!")
        end
    else
        windower.add_to_chat(207, "NPC not found: " .. npc_name)
    end
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