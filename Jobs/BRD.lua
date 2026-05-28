local BRD = {}

local coroutine = require('coroutine')
local config = require('config')

-- Runtime state
local active = false
local songDelay = 15

-- Song slots
local song1, song2, song3, song4, song5 = nil, nil, nil, nil, nil

-- Settings bucket (AutoBot passes this in)
local settings = nil

--------------------------------------------------------------------------------
-- INIT
--------------------------------------------------------------------------------
function BRD.init(job_settings)
    settings = job_settings

    -- Ensure settings structure exists
    settings.savedSets = settings.savedSets or {}
    settings.songDelay = settings.songDelay or 15

    songDelay = settings.songDelay

    -- Auto-load default set if present
    if settings.default then
        song1 = settings.default[1]
        song2 = settings.default[2]
        song3 = settings.default[3]
        song4 = settings.default[4]
        song5 = settings.default[5]
    end

    windower.add_to_chat(207, "[AutoBot:BRD] Initialized Bard module.")
end

--------------------------------------------------------------------------------
-- START / STOP
--------------------------------------------------------------------------------
function BRD.start()
    if active then return end

    if not song1 then
        windower.add_to_chat(123, "[AutoBot:BRD] No song set loaded.")
        return
    end

    active = true
    coroutine.schedule(BRD.song_loop, 0)
    windower.add_to_chat(207, "[AutoBot:BRD] Bard automation started.")
end

function BRD.stop()
    active = false
    windower.add_to_chat(207, "[AutoBot:BRD] Bard automation stopped.")
end

--------------------------------------------------------------------------------
-- SONG LOOP
--------------------------------------------------------------------------------
function BRD.song_loop()
    while active do
        if not song1 then
            windower.add_to_chat(123, "[AutoBot:BRD] No songs loaded. Stopping.")
            active = false
            return
        end

        local queue = {song1, song2, song3, song4, song5}
        local played = false

        for _, song in ipairs(queue) do
            if not active then return end
            if song then
                windower.send_command('input /song "' .. song .. '" <me>')
                coroutine.sleep(songDelay)
                played = true
            end
        end

        if not played then
            windower.add_to_chat(123, "[AutoBot:BRD] No valid songs found.")
            coroutine.sleep(5)
        end

        coroutine.sleep(60)
    end
end

--------------------------------------------------------------------------------
-- SONG SET MANAGEMENT
--------------------------------------------------------------------------------
local function save_settings()
    settings.songDelay = songDelay
    config.save(settings)
end

local function create_set(name, songs)
    if #songs > 5 then
        windower.add_to_chat(123, "[AutoBot:BRD] Max 5 songs per set.")
        return
    end

    settings.savedSets[name] = songs
    save_settings()

    windower.add_to_chat(207, "[AutoBot:BRD] Created set '" .. name .. "'.")
end

local function load_set(name)
    local set = settings.savedSets[name]
    if not set then
        windower.add_to_chat(123, "[AutoBot:BRD] No set named '" .. name .. "'.")
        return
    end

    song1 = set[1]
    song2 = set[2]
    song3 = set[3]
    song4 = set[4]
    song5 = set[5]

    windower.add_to_chat(207, "[AutoBot:BRD] Loaded set '" .. name .. "'.")
end

--------------------------------------------------------------------------------
-- COMMAND HANDLER
--------------------------------------------------------------------------------
function BRD.command(cmd, args)
    cmd = cmd and cmd:lower()

    ------------------------------------------------------------------------
    -- //ab job brd start
    ------------------------------------------------------------------------
    if cmd == "start" then
        BRD.start()
        return
    end

    ------------------------------------------------------------------------
    -- //ab job brd stop
    ------------------------------------------------------------------------
    if cmd == "stop" then
        BRD.stop()
        return
    end

    ------------------------------------------------------------------------
    -- //ab job brd set <song1> <song2> ...
    ------------------------------------------------------------------------
    if cmd == "set" then
        song1 = args[1]
        song2 = args[2]
        song3 = args[3]
        song4 = args[4]
        song5 = args[5]

        windower.add_to_chat(207, "[AutoBot:BRD] Songs set.")
        return
    end

    ------------------------------------------------------------------------
    -- //ab job brd create <name> <songs...>
    ------------------------------------------------------------------------
    if cmd == "create" then
        local name = args[1]
        if not name then
            windower.add_to_chat(123, "[AutoBot:BRD] Usage: create <name> <songs>")
            return
        end

        local songs = {select(2, unpack(args))}
        create_set(name, songs)
        return
    end

    ------------------------------------------------------------------------
    -- //ab job brd load <name>
    ------------------------------------------------------------------------
    if cmd == "load" then
        local name = args[1]
        if not name then
            windower.add_to_chat(123, "[AutoBot:BRD] Usage: load <name>")
            return
        end

        load_set(name)
        return
    end

    ------------------------------------------------------------------------
    -- //ab job brd delay <seconds>
    ------------------------------------------------------------------------
    if cmd == "delay" then
        local n = tonumber(args[1])
        if not n or n <= 0 then
            windower.add_to_chat(123, "[AutoBot:BRD] Invalid delay.")
            return
        end

        songDelay = n
        save_settings()
        windower.add_to_chat(207, "[AutoBot:BRD] Delay set to " .. n)
        return
    end

    ------------------------------------------------------------------------
    -- //ab job brd list
    ------------------------------------------------------------------------
    if cmd == "list" then
        windower.add_to_chat(207, "[AutoBot:BRD] Saved song sets:")
        for name in pairs(settings.savedSets) do
            windower.add_to_chat(207, "- " .. name)
        end
        return
    end

    ------------------------------------------------------------------------
    -- //ab job brd songs
    ------------------------------------------------------------------------
    if cmd == "songs" then
        windower.add_to_chat(207, "[AutoBot:BRD] Current songs:")
        for i, s in ipairs({song1, song2, song3, song4, song5}) do
            if s then windower.add_to_chat(207, i .. ". " .. s) end
        end
        return
    end

    windower.add_to_chat(123, "[AutoBot:BRD] Unknown command: " .. tostring(cmd))
end

return BRD