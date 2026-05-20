-- jobs/BRD.lua
-- Job Script for BRD (Bard)
-- This script is loaded by AutoBot when the player's main or sub job is BRD.
-- It must expose a handle_command(args) function to process job-specific commands.

local brd = {}

-- Require needed libraries
local config = require('config')
require('tables')
local coroutine = require('coroutine')

-- Specify the job's own configuration file filename.
local job_config_file = 'BRD_Settings'

-- Load or initialize the Bard configuration from its own settings file.
local songSets = config.load({
    default = {},
    savedSets = {},
    songDelay = 15
}, job_config_file)
local songDelay = songSets.songDelay or 15

-- Global variables for song management and loop control
local active = false
local song1, song2, song3, song4, song5 = nil, nil, nil, nil, nil

-- Ensure that savedSets exists
if not songSets.savedSets then
    songSets.savedSets = {}
end

------------------------------------------------------------
-- Core Functions for Bard Functionality (Song Management) --
------------------------------------------------------------

-- Start the song loop
function brd.start()
    if active then return end
    if not song1 then
        windower.add_to_chat(167, "[BRD] No song set loaded. Use 'load' command first.")
        return
    end
    active = true
    coroutine.schedule(brd.song_loop, 0)
end

-- Stop the song loop
function brd.stop()
    active = false
end

-- Main loop to play songs sequentially
function brd.song_loop()
    while active do
        if not song1 then
            windower.add_to_chat(167, "[BRD] No active songs in queue. Restarting...")
            coroutine.sleep(5)
            brd.start()
            return
        end

        local songQueue = { song1, song2, song3, song4, song5 }
        local songsPlayed = false

        for i, song in ipairs(songQueue) do
            if song then
                windower.add_to_chat(2, "[BRD] Playing - \"" .. song .. "\"")
                windower.send_command('input /song "' .. song .. '" <me>')
                coroutine.sleep(songDelay)
                if not active then return end
                songsPlayed = true
            end
        end

        if not songsPlayed then
            windower.add_to_chat(167, "[BRD] No valid songs found. Restarting...")
            coroutine.sleep(5)
            brd.start()
            return
        end

        coroutine.sleep(60)
    end
end

-- Save the job's configuration to its own file
function brd.save_settings()
    songSets.songDelay = songDelay
    config.save(songSets, job_config_file)
    windower.add_to_chat(2, "[BRD] Settings saved!")
end

-- Create a new song set
function brd.create_song_set(name, ...)
    local songs = {...}
    if #songs > 5 then
        windower.add_to_chat(167, "[BRD] Maximum 5 songs per set.")
        return
    end

    -- Replace &apos; with an apostrophe
    for i = 1, #songs do
        songs[i] = songs[i]:gsub('&apos;', "'")
    end

    songSets.savedSets[name] = songs
    windower.add_to_chat(2, "[BRD] Song set \"" .. name .. "\" created!")
    brd.save_settings()
end

-- Load a song set
function brd.load_song_set(name)
    local setName = tostring(name)
    if songSets.savedSets[setName] and type(songSets.savedSets[setName]) == "table" then
        local orderedKeys = {}
        for key in pairs(songSets.savedSets[setName]) do
            table.insert(orderedKeys, tonumber(key))
        end
        table.sort(orderedKeys)
        song1 = songSets.savedSets[setName][tostring(orderedKeys[1])] or nil
        song2 = songSets.savedSets[setName][tostring(orderedKeys[2])] or nil
        song3 = songSets.savedSets[setName][tostring(orderedKeys[3])] or nil
        song4 = songSets.savedSets[setName][tostring(orderedKeys[4])] or nil
        song5 = songSets.savedSets[setName][tostring(orderedKeys[5])] or nil

        windower.add_to_chat(2, "[BRD] Loaded song set \"" .. setName .. "\"")
        windower.add_to_chat(2, "[BRD] Debug: Songs - " ..
            tostring(song1) .. ", " .. tostring(song2) .. ", " ..
            tostring(song3) .. ", " .. tostring(song4) .. ", " .. tostring(song5))
    else
        windower.add_to_chat(167, "[BRD] No saved song set named \"" .. setName .. "\"")
    end
end

-- Set the song delay
function brd.set_song_delay(seconds)
    local num = tonumber(seconds)
    if num and num > 0 then
        songDelay = num
        windower.add_to_chat(2, "[BRD] Song delay set to " .. num .. " seconds.")
        brd.save_settings()
    else
        windower.add_to_chat(167, "[BRD] Invalid delay. Please enter a positive number.")
    end
end

-- List song sets
function brd.list(setName)
    if setName then
        local songSet = songSets.savedSets[tostring(setName)]
        if songSet and type(songSet) == "table" then
            windower.add_to_chat(2, "[BRD] Songs in \"" .. setName .. "\" set:")
            local orderedKeys = {}
            for key in pairs(songSet) do
                table.insert(orderedKeys, tonumber(key))
            end
            table.sort(orderedKeys)
            for _, key in ipairs(orderedKeys) do
                windower.add_to_chat(2, key .. ". " .. songSet[tostring(key)])
            end
        else
            windower.add_to_chat(167, "[BRD] No saved song set named \"" .. setName .. "\"")
        end
    else
        windower.add_to_chat(2, "[BRD] Available song sets:")
        for name in pairs(songSets.savedSets) do
            windower.add_to_chat(2, "- " .. name)
        end
    end
end

-- Display currently set songs
function brd.songs()
    windower.add_to_chat(2, "[BRD] Currently set songs:")
    local songs = {song1, song2, song3, song4, song5}
    for i, song in ipairs(songs) do
        if song then
            windower.add_to_chat(2, i .. ". " .. song)
        end
    end
end

-- Auto-load default song set if one exists
if songSets.default then
    song1 = songSets.default[1] or nil
    song2 = songSets.default[2] or nil
    song3 = songSets.default[3] or nil
    song4 = songSets.default[4] or nil
    song5 = songSets.default[5] or nil
end

---------------------------------------------------------------
-- Job Script Interface: handle_command(args) for BRD      --
---------------------------------------------------------------
function brd.handle_command(args)
    if #args < 1 then
        windower.add_to_chat(2, "[BRD] No command given.")
        return
    end

    local cmd = args[1]:lower()
    if cmd == "start" or cmd == "on" then
        brd.start()
    elseif cmd == "stop" or cmd == "off" then
        brd.stop()
    elseif cmd == "create" then
        if #args >= 2 then
            brd.create_song_set(args[2], table.unpack(args, 3))
        else
            windower.add_to_chat(167, "[BRD] Usage: BRD create <name> <song1> [song2] [song3] [song4] [song5]")
        end
    elseif cmd == "load" then
        if args[2] then
            brd.load_song_set(args[2])
        else
            windower.add_to_chat(167, "[BRD] Usage: BRD load <name>")
        end
    elseif cmd == "save" then
        brd.save_settings()
    elseif cmd == "delay" then
        if args[2] then
            brd.set_song_delay(args[2])
        else
            windower.add_to_chat(167, "[BRD] Usage: BRD delay <seconds>")
        end
    elseif cmd == "list" then
        brd.list(args[2])
    elseif cmd == "songs" then
        brd.songs()
    elseif cmd == "help" then
        windower.add_to_chat(2, "[BRD] Commands:")
        windower.add_to_chat(2, "BRD start/on         - Start auto song loop")
        windower.add_to_chat(2, "BRD stop/off         - Stop auto song loop")
        windower.add_to_chat(2, "BRD create <name> <song1> ... - Create a song set")
        windower.add_to_chat(2, "BRD load <name>      - Load a song set")
        windower.add_to_chat(2, "BRD save             - Save settings")
        windower.add_to_chat(2, "BRD delay <seconds>  - Set song delay")
        windower.add_to_chat(2, "BRD list [name]      - List song set(s)")
        windower.add_to_chat(2, "BRD songs            - Show currently set songs")
        windower.add_to_chat(2, "BRD help             - Show this help message")
    else
        windower.add_to_chat(123, "[BRD] Unknown command: " .. cmd)
    end
end

return brd