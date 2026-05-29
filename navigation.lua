-----------------------------------------
-- AutoBot Navigation Module
-----------------------------------------

local navigation = {}
local config = require('config')

local recording = false
local current_path = {}
local current_path_name = nil

local loop_enabled = false
local reverse_enabled = false     -- one-shot reverse mode
local bounce_enabled = false      -- infinite back-and-forth mode

local playback_active = false
local playback_index = 1
local last_record_time = 0
local direction = 1               -- 1 = forward, -1 = backward

-- Tuning
local record_interval = 0.5
local jitter_threshold = 0.15
local nav_path_dir = windower.addon_path .. "NavPaths/"

windower.create_dir(nav_path_dir)

---------------------------------------------------------
-- Utility: Distance
---------------------------------------------------------
local function distance(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    local dz = a.z - b.z
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

local function should_record_point(last, current)
    if not last then return true end
    return distance(last, current) >= jitter_threshold
end

---------------------------------------------------------
-- Simple table serializer
---------------------------------------------------------
local function serialize(tbl, indent)
    indent = indent or ""
    local next_indent = indent .. "    "
    local result = "{\n"

    for k, v in pairs(tbl) do
        local key = type(k) == "string" and string.format("[%q]", k) or string.format("[%s]", tostring(k))

        if type(v) == "table" then
            result = result .. next_indent .. key .. " = " .. serialize(v, next_indent) .. ",\n"
        elseif type(v) == "string" then
            result = result .. next_indent .. key .. " = " .. string.format("%q", v) .. ",\n"
        else
            result = result .. next_indent .. key .. " = " .. tostring(v) .. ",\n"
        end
    end

    result = result .. indent .. "}"
    return result
end

---------------------------------------------------------
-- Save / Load
---------------------------------------------------------
local function save_path(name, path)
    local file = io.open(nav_path_dir .. name .. ".lua", "w+")
    if not file then
        windower.add_to_chat(123, "[AutoBot:Nav] Failed to save path: " .. name)
        return
    end
    file:write("return " .. serialize(path))
    file:close()
    windower.add_to_chat(207, "[AutoBot:Nav] Saved path: " .. name)
end

local function load_path(name)
    local file = io.open(nav_path_dir .. name .. ".lua", "r")
    if not file then
        windower.add_to_chat(123, "[AutoBot:Nav] No saved path found: " .. name)
        return nil
    end

    local chunk = file:read("*a")
    file:close()

    local ok, result = pcall(loadstring(chunk))
    if not ok then
        windower.add_to_chat(123, "[AutoBot:Nav] Failed to load path: " .. name)
        return nil
    end

    windower.add_to_chat(207, "[AutoBot:Nav] Loaded path: " .. name)
    return result
end

---------------------------------------------------------
-- RECORDING
---------------------------------------------------------
function navigation.start_record(name)
    if playback_active then
        windower.add_to_chat(123, "[AutoBot:Nav] Cannot record while navigating.")
        return
    end

    recording = true
    current_path = {}
    current_path_name = name
    last_record_time = os.clock()

    windower.add_to_chat(207, "[AutoBot:Nav] Recording started: " .. name)
end

function navigation.stop_record()
    if not recording then return end

    recording = false
    windower.ffxi.run(false)
    save_path(current_path_name, current_path)

    windower.add_to_chat(207, "[AutoBot:Nav] Recording stopped and saved.")
end

function navigation.is_recording()
    return recording
end

---------------------------------------------------------
-- PLAYBACK
---------------------------------------------------------
function navigation.start_playback(name)
    if recording then
        windower.add_to_chat(123, "[AutoBot:Nav] Cannot start navigation while recording.")
        return
    end

    local path = load_path(name)
    if not path then return end

    current_path = path
    current_path_name = name
    playback_active = true

    -- Determine starting direction
    if reverse_enabled then
        direction = -1
        playback_index = #current_path
    else
        direction = 1
        playback_index = 1
    end

    windower.add_to_chat(207, "[AutoBot:Nav] Starting navigation: " .. name)
end

function navigation.stop_playback()
    if playback_active then
        playback_active = false
        windower.ffxi.run(false)
        windower.add_to_chat(207, "[AutoBot:Nav] Navigation stopped.")
    end
end

---------------------------------------------------------
-- TOGGLES
---------------------------------------------------------
function navigation.toggle_loop()
    loop_enabled = not loop_enabled
    windower.add_to_chat(207, "[AutoBot:Nav] Looping is now " .. (loop_enabled and "ENABLED" or "DISABLED"))
end

function navigation.toggle_reverse()
    reverse_enabled = not reverse_enabled

    if reverse_enabled then
        bounce_enabled = false
    end

    windower.add_to_chat(207, "[AutoBot:Nav] Reverse mode is now " .. (reverse_enabled and "ENABLED" or "DISABLED"))
end

function navigation.toggle_bounce()
    bounce_enabled = not bounce_enabled

    if bounce_enabled then
        reverse_enabled = false
    end

    windower.add_to_chat(207, "[AutoBot:Nav] Bounce mode is now " .. (bounce_enabled and "ENABLED" or "DISABLED"))
end

---------------------------------------------------------
-- TICK
---------------------------------------------------------
function navigation.tick()
    local player = windower.ffxi.get_mob_by_target("me")
    if not player then return end

    -----------------------------------------------------
    -- RECORDING
    -----------------------------------------------------
    if recording then
        local now = os.clock()
        if now - last_record_time >= record_interval then
            last_record_time = now

            local pos = { x = player.x, y = player.y, z = player.z }
            local last_point = current_path[#current_path]

            if should_record_point(last_point, pos) then
                table.insert(current_path, pos)
                windower.add_to_chat(207, "[AutoBot:Nav] Recorded point #" .. #current_path)
            end
        end
    end

    -----------------------------------------------------
    -- PLAYBACK
    -----------------------------------------------------
    if playback_active and #current_path > 0 then
        local target = current_path[playback_index]
        if not target then return end

        local dist = distance(player, target)

        if dist < 1.0 then
            playback_index = playback_index + direction

            -- Bounce mode
            if bounce_enabled then
                if playback_index > #current_path then
                    direction = -1
                    playback_index = #current_path - 1
                elseif playback_index < 1 then
                    direction = 1
                    playback_index = 2
                end

            -- Reverse mode (one-shot)
            elseif reverse_enabled then
                if playback_index < 1 then
                    navigation.stop_playback()
                end

            -- Loop mode
            elseif loop_enabled then
                if playback_index > #current_path then
                    playback_index = 1
                end

            -- Normal stop
            else
                if playback_index > #current_path then
                    navigation.stop_playback()
                end
            end

        else
            windower.ffxi.run(target.x - player.x, target.y - player.y)
        end
    end
end

return navigation
