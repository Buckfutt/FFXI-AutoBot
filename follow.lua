-- follow.lua
local follow = {}
local following = false             -- Whether we are actively following
local follow_target = nil           -- The name of the player to follow
local player_rotation = 0           -- Stored rotation (from outgoing packets)
local packets_ref = nil             -- Packets reference placeholder

-- Variables for distance re-issue:
local follow_range = 3              -- Desired follow range (in game units)
local distance_threshold = follow_range + 2  -- If distance exceeds this, re-issue follow command
local last_reissue_time = 0         -- Timestamp when /follow was last re-issued
local reissue_delay = 2             -- Minimum seconds between re-issued follow commands

-------------------------------------------------------------
-- Set packets reference from main module.
-------------------------------------------------------------
function follow.set_packets(packets)
    packets_ref = packets
end

-------------------------------------------------------------
-- Track player's rotation via outgoing packets.
-------------------------------------------------------------
windower.register_event('outgoing chunk', function(id, data)
    if id == 0x015 and packets_ref then
        local action_message = packets_ref.parse('outgoing', data)
        player_rotation = action_message["Rotation"]
    end
end)

-------------------------------------------------------------
-- Move_Backward: Turn around and run backward briefly.
-------------------------------------------------------------
local function Move_Backward()
    local self = windower.ffxi.get_player()
    if not self then return end
    local backward_heading = player_rotation + math.pi  -- Reverse heading
    windower.ffxi.turn(backward_heading)                  -- Turn to face backward
    windower.ffxi.run(true)
    coroutine.schedule(function()
        windower.ffxi.run(false)
    end, 0.5)
end

-------------------------------------------------------------
-- Start following using the in-game /follow command.
-------------------------------------------------------------
function follow.start_follow(target_name)
    following = true
    follow_target = target_name
    last_reissue_time = os.clock()
    windower.send_command('input /p Following: ' .. target_name)
    windower.send_command('input /follow ' .. target_name)
end

-------------------------------------------------------------
-- Stop following – also do a brief backward step.
-------------------------------------------------------------
function follow.stop_follow()
    following = false
    follow_target = nil
    Move_Backward()
    windower.send_command('input /p Stopping Follow!')
end

-------------------------------------------------------------
-- Polling function: Reissue /follow if target is available.
-------------------------------------------------------------
local function pollForFollowTarget()
    if not following or not follow_target then return end
    local target = windower.ffxi.get_mob_by_name(follow_target)
    if target then
        windower.send_command('input /follow ' .. follow_target)
        last_reissue_time = os.clock()  -- Reset timer upon re-issuing
    else
        coroutine.schedule(pollForFollowTarget, 0.5)
    end
end

-------------------------------------------------------------
-- On zone change, begin polling for the follow target.
-------------------------------------------------------------
windower.register_event('zone change', function(new, old)
    if following and follow_target then
        pollForFollowTarget()
    end
end)

-------------------------------------------------------------
-- Persistent distance monitoring.
-- If our distance to the target exceeds distance_threshold,
-- reissue the /follow command (if a minimum delay has passed).
-------------------------------------------------------------
windower.register_event('prerender', function()
    if not following or not follow_target then return end
    
    local player = windower.ffxi.get_mob_by_target('me')
    local target = windower.ffxi.get_mob_by_name(follow_target)
    if not player or not target then return end
    
    local dx = target.x - player.x
    local dy = target.y - player.y
    local distance = math.sqrt(dx * dx + dy * dy)
    
    if distance > distance_threshold then
        local current_time = os.clock()
        if current_time - last_reissue_time > reissue_delay then
            windower.send_command('input /follow ' .. follow_target)
            last_reissue_time = current_time
        end
    end
end)

-------------------------------------------------------------
-- Adjust follow distance (and threshold) via command.
-------------------------------------------------------------
function follow.set_follow_distance(new_distance)
    new_distance = tonumber(new_distance)
    if new_distance then
        follow_range = new_distance
        distance_threshold = follow_range + 5
    end
end

return follow