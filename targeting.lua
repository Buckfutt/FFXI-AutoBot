local targeting = {}
local settings_ref = nil
local packets = require('packets')
local targeting_event_id = nil         -- ID returned by windower.register_event
local last_locked_target = nil         -- Stores the last locked target ID
local last_target_change_time = 0      -- Timestamp of the last target change
local retarget_delay = 5              -- Seconds to wait before switching targets if a new mob gets closer
local debug = false                    -- Set true for extra debug output

----------------------------------------------------------------------
-- Facing Routine Functions (adapted from your autotarget addon)
----------------------------------------------------------------------

-- Global variable for rotation updates.
PlayerH = 0

-- Update PlayerH from outgoing chunk packets.
windower.register_event('outgoing chunk', function(id, data)
    if id == 0x015 then
        local action_message = packets.parse('outgoing', data)
        PlayerH = action_message["Rotation"]
    end
end)

-- Compute the heading from the player toward the given coordinates.
function Heading_To(X, Y)
    local player = windower.ffxi.get_mob_by_id(windower.ffxi.get_player().id)
    if not player or not (player.x and player.y) then return nil end
    local dx = X - player.x
    local dy = Y - player.y
    local H = math.atan2(dx, dy)
    return H - 1.5708
end

-- Turn the player toward the current target.
function Turn_To_Target()
    local target = windower.ffxi.get_mob_by_target('t')
    if not (target and target.x and target.y) then return end
    local destX = target.x
    local destY = target.y
    local desired_heading = Heading_To(destX, destY)
    if not desired_heading then return end
    local diff = math.abs(PlayerH - math.deg(desired_heading))
    if diff > 10 then
        windower.ffxi.turn(desired_heading)
        if debug then
            windower.add_to_chat(207, string.format("Turning: desired_heading = %.2f° (diff = %.2f°)", math.deg(desired_heading), diff))
        end
    elseif debug then
        windower.add_to_chat(207, string.format("No turn needed: diff = %.2f°", diff))
    end
end

-- Check target distance and adjust facing if needed.
function Check_Distance()
    local target = windower.ffxi.get_mob_by_target('t')
    if not target then return end
    local distance = math.sqrt(target.distance)
    if distance > 3 then
        Turn_To_Target()
        windower.ffxi.run(false) -- Make sure you’re not running.
    else
        windower.ffxi.run(false)
    end
end

-- Facing loop control.
local facing_running = false

-- Continuously call Turn_To_Target and Check_Distance while the player is engaged.
local function continuously_face_target()
    local player = windower.ffxi.get_player()
    if player and player.status == 1 then  -- engaged
        Turn_To_Target()
        Check_Distance()
    end
    if facing_running then
        coroutine.schedule(continuously_face_target, 0.5)
    end
end

-- Start the facing loop.
function targeting.start_facing()
    if not facing_running then
        facing_running = true
        continuously_face_target()
        if debug then
            windower.add_to_chat(207, "[Targeting DEBUG] Facing loop started.")
        end
    end
end

-- Stop the facing loop.
function targeting.stop_facing()
    facing_running = false
    if debug then
        windower.add_to_chat(207, "[Targeting DEBUG] Facing loop stopped.")
    end
end

----------------------------------------------------------------------
-- Attack Routine Functions
----------------------------------------------------------------------
-- NOTES:
-- There appears to be a bug here, we need to check to make sure
-- we're not receiving the "Cannot attack Target." Packet, and if
-- we are, then we need to attempt to target a different MobID
--
-- Or is it trying to re-target the dead mob?
-- Maybe check if to see if target ID = previous target ID
-- if so, then find new target ID
----------------------------------------------------------------------

-- Repeatedly issues "/attack <t>" until player becomes engaged.
local function attempt_attack_until_engaged()
    local player = windower.ffxi.get_player()
    if not player then return end
    if player.status ~= 1 then
         windower.send_command("input /attack <t>")
         coroutine.schedule(attempt_attack_until_engaged, 1)
    end
end

----------------------------------------------------------------------
-- Targeting Functions
----------------------------------------------------------------------

-- Provide settings (must include target_list and modules table).
function targeting.set_settings(cfg)
    settings_ref = cfg
    if not settings_ref.target_list then
        settings_ref.target_list = L{}  -- Initialize if missing.
    end
    if debug then
        windower.add_to_chat(207, "[Targeting DEBUG] Settings loaded.")
    end
end

-- Allow packet reference updates.
function targeting.set_packets(pkt)
    packets = pkt
end

-- Find the nearest valid target within 20 units.
function targeting.find_nearest_target()
    if not settings_ref or not settings_ref.target_list or #settings_ref.target_list == 0 then
        if debug then
            windower.add_to_chat(207, "[Targeting DEBUG] Target list is empty or not loaded correctly!")
        end
        return nil
    end

    local mob_array = windower.ffxi.get_mob_array()
    local closest_target = nil
    local closest_distance = math.huge

    for _, mob in pairs(mob_array) do
        local mob_name = mob.name:lower():gsub("^%s*(.-)%s*$", "%1")
        for _, target_name in ipairs(settings_ref.target_list) do
            local target_name_norm = target_name:lower():gsub("^%s*(.-)%s*$", "%1")
            if mob.valid_target and mob_name == target_name_norm and mob.hpp > 99 then
                local distance = math.sqrt(mob.distance)
                if distance <= 20 and distance < closest_distance then
                    closest_target = mob
                    closest_distance = distance
                end
            end
        end
    end

    if debug then
        if closest_target then
            windower.add_to_chat(207, "[Targeting DEBUG] Closest target: " .. closest_target.name .. " at distance " .. string.format("%.1f", closest_distance))
        else
            windower.add_to_chat(207, "[Targeting DEBUG] No valid target found within 20 units.")
        end
    end

    return closest_target and closest_target.id or nil
end

-- Main targeting function called on each prerender event.
function targeting.find_target()
    local player = windower.ffxi.get_player()
    if not player then return end

    -- Do not change target while engaged.
    if player.status == 1 then
        if debug then
            windower.add_to_chat(207, "[Targeting DEBUG] Player is engaged; not retargeting.")
        end
        return
    end

    if debug then
        windower.add_to_chat(207, "[Targeting DEBUG] find_target() called.")
    end

    if not settings_ref then
        if debug then windower.add_to_chat(207, "[Targeting DEBUG] settings_ref is nil!") end
        return
    end
    if not settings_ref.modules or not settings_ref.modules.targeting then
        if debug then windower.add_to_chat(207, "[Targeting DEBUG] Targeting module is disabled in settings!") end
        return
    end

    local new_target_id = targeting.find_nearest_target()

    if new_target_id then
        local current_target = windower.ffxi.get_mob_by_target('t')
        -- If already targeting this mob, update timestamp and do nothing.
        if current_target and current_target.id == new_target_id then
            if debug then
                windower.add_to_chat(207, "[Targeting DEBUG] Already targeting this mob!")
            end
            last_locked_target = new_target_id
            last_target_change_time = os.time()
            return
        end

        local now = os.time()
        if not last_target_change_time then last_target_change_time = 0 end
        -- Enforce a delay before retargeting if a new mob appears too quickly.
        if last_locked_target and new_target_id ~= last_locked_target and (now - last_target_change_time) < retarget_delay then
            if debug then
                windower.add_to_chat(207, "[Targeting DEBUG] Retarget delay active. Not switching targets yet.")
            end
            return
        end

        if new_target_id ~= last_locked_target then
            last_locked_target = new_target_id
            last_target_change_time = now
            coroutine.schedule(function()
                packets.inject(packets.new('incoming', 0x058, {
                    ['Player'] = player.id,
                    ['Target'] = new_target_id,
                    ['Player Index'] = player.index,
                }))
                local hex_id = string.format("0x%X", new_target_id)
                windower.add_to_chat(207, "[Targeting] Locked onto target: " .. hex_id)
                windower.send_command("input /attack <t>")
                attempt_attack_until_engaged()
            end, 0.2)
        else
            if debug then
                windower.add_to_chat(207, "[Targeting DEBUG] Target remains unchanged.")
            end
        end
    else
        if debug then windower.add_to_chat(207, "[Targeting DEBUG] No valid targets found.") end
        last_locked_target = nil
    end
end

----------------------------------------------------------------------
-- Module Toggle Functions
----------------------------------------------------------------------

-- Start the targeting module; register the prerender event and begin the facing loop.
function targeting.start()
    if targeting_event_id then
        windower.add_to_chat(207, "[Targeting] Already started!")
        return
    end
    targeting_event_id = windower.register_event('prerender', targeting.find_target)
    windower.add_to_chat(207, "[Targeting] Started!")
    targeting.start_facing()
end

-- Stop the targeting module; unregister the event and stop facing.
function targeting.stop()
    if targeting_event_id then
        windower.unregister_event(targeting_event_id)
        targeting_event_id = nil
        windower.add_to_chat(207, "[Targeting] Stopped!")
        last_locked_target = nil
    else
        windower.add_to_chat(207, "[Targeting] Not currently running!")
    end
    targeting.stop_facing()
end

return targeting