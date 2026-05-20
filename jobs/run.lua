-- jobs/run.lua
-- Job Script for Rune Fencer (RUN)
-- Converts the Auto Rune Fencer addon to a job script for our framework.
-- It saves settings to its own file ("RUN_Settings") and provides a handle_command(args) function.
 
local run = {}  -- our module table

--------------------------------
-- Required Libraries & Modules
--------------------------------
local files   = require('files')
local chat    = require('chat')
local texts   = require('texts')
local images  = require('images')
local tables  = require('tables')
local res     = require('resources')
local logger  = require('logger')
local packets = require('packets')
require('sets')
require('strings')
require('actions')
require('pack')
local config  = require('config')
local coroutine = require('coroutine')

-------------------------------
-- Configuration & Global Vars
-------------------------------
local job_config_file = 'RUN_Settings'  -- custom settings filename for this job
local settings = config.load({
    useSwipe      = false,
    useLunge      = false,
    useSwordplay  = false,
    useVal        = false,
    usePflug      = false,
    setRunes      = {}
}, job_config_file)

-- Local toggles and state variables for the job script
local enableJob      = false    -- toggles automation on/off
local lastUsedJA     = os.time()
local cooldownPeriod = 1        -- seconds between ability uses
local acting         = false

local useSwipe      = settings.useSwipe
local useLunge      = settings.useLunge
local useSwordplay  = settings.useSwordplay
local useVal        = settings.useVal
local usePflug      = settings.usePflug
local setRunes      = settings.setRunes or {}

-- Buff and ability tracking variable (for runes active on player)
local activeRunes = {}  -- will be recalculated with each update

---------------------------------------------
-- Utility Functions
---------------------------------------------
-- If not already defined, add a split method to strings.
if not string.split then
    function string:split(delimiter)
        local result = {}
        local from = 1
        local delim_from, delim_to = string.find(self, delimiter, from)
        while delim_from do
            table.insert(result, string.sub(self, from, delim_from - 1))
            from = delim_to + 1
            delim_from, delim_to = string.find(self, delimiter, from)
        end
        table.insert(result, string.sub(self, from))
        return result
    end
end

-- Helper: Count number of keys in a table.
local function countTable(tbl)
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

---------------------------------------------
-- Rune Processing & Ability Functions
---------------------------------------------
local function inRunes(val)
    local runeArr = {'ignis', 'gelus', 'flabra', 'tellus', 'sulpor', 'unda', 'lux', 'tenebrae'}
    for _, value in ipairs(runeArr) do
        if value == val then
            return true
        end
    end
    return false
end

local function set_Runes(arg1, arg2, arg3)
    local elementToRune = {
        fire      = 'ignis',
        ice       = 'gelus',
        wind      = 'flabra',
        earth     = 'tellus',
        thunder   = 'sulpor',
        lightning = 'sulpor',
        water     = 'unda',
        light     = 'lux',
        dark      = 'tenebrae'
    }
  
    setRunes = {}  -- reset rune storage
  
    local function processRune(arg)
        if arg then
            local lowerArg = arg:lower()
            if elementToRune[lowerArg] then
                return elementToRune[lowerArg]
            elseif inRunes(lowerArg) then
                return lowerArg
            else
                windower.add_to_chat(2, arg .. " is not a valid rune or element.")
                return nil
            end
        end
    end
  
    local convertedRunes = { processRune(arg1), processRune(arg2), processRune(arg3) }
    for _, rune in ipairs(convertedRunes) do
        if rune then
            setRunes[rune] = (setRunes[rune] or 0) + 1
        end
    end
  
    local keys = {}
    for k in pairs(setRunes) do
        table.insert(keys, k)
    end
    local runeList = table.concat(keys, ", ")
    windower.add_to_chat(2, "Runes set: " .. (runeList ~= "" and runeList or "None"))
end

local function autoJA(str, tar)
    windower.send_command(string.format('input /ja "%s" %s', str, tar))
    coroutine.sleep(1)
end

---------------------------------------------
-- Buff & Rune Tracking Functions
---------------------------------------------
local function activeBuffs()
    local buffs = {}
    activeRunes = {}  -- reset active runes each update

    local runeMap = {
        [523] = 'ignis', [524] = 'gelus', [525] = 'flabra', [526] = 'tellus',
        [527] = 'sulpor', [528] = 'unda', [529] = 'lux', [530] = 'tenebrae'
    }

    local player = windower.ffxi.get_player()
    if not player then return nil end
    local playerBuffs = player.buffs or {}
    for _, v in ipairs(playerBuffs) do
        if runeMap[v] then
            activeRunes[runeMap[v]] = (activeRunes[runeMap[v]] or 0) + 1
        end
    end
    local incapacitated = false
    -- You can add further incapacitation checking if needed.
    return incapacitated
end

local function compare_buffs()
    local currentTime = os.time()
    if currentTime - lastUsedJA < cooldownPeriod or acting then
        return
    end

    local runeList = {'ignis', 'gelus', 'flabra', 'tellus', 'sulpor', 'unda', 'lux', 'tenebrae'}
    for _, rune in ipairs(runeList) do
        if setRunes[rune] and setRunes[rune] > 0 and 
           (not activeRunes[rune] or activeRunes[rune] < setRunes[rune]) then
            acting = true
            autoJA(rune, "<me>")
            lastUsedJA = os.time()
            coroutine.schedule(function() acting = false end, cooldownPeriod)
            return
        end
    end
end

local function removeRune(count)
    local runeKeys = {}
    for rune, _ in pairs(activeRunes) do
        table.insert(runeKeys, rune)
    end
    table.sort(runeKeys, function(a, b) return activeRunes[a] > activeRunes[b] end)
    for i = 1, count do
        if #runeKeys > 0 then
            local runeToRemove = runeKeys[1]
            activeRunes[runeToRemove] = activeRunes[runeToRemove] - 1
            if activeRunes[runeToRemove] <= 0 then
                activeRunes[runeToRemove] = nil
            end
            table.remove(runeKeys, 1)
        end
    end
    coroutine.schedule(compare_buffs, cooldownPeriod)
end

local function performAbilities()
    local recast = windower.ffxi.get_ability_recasts()
    local player = windower.ffxi.get_player()
    if not player then return end
    local playerStatus = player.status
    if playerStatus ~= 1 then
        return
    end

    if useSwipe and recast[141] == 0 and countTable(activeRunes) >= 1 then
        windower.send_command('input /ja "Swipe" <t>')
        removeRune(1)
    end
    if useLunge and recast[142] == 0 and countTable(activeRunes) >= 1 then
        windower.send_command('input /ja "Lunge" <t>')
        removeRune(countTable(activeRunes))
    end
    if useSwordplay and recast[68] == 0 then
        windower.send_command('input /ja "Swordplay" <me>')
    end
    if useVal and recast[23] == 0 and countTable(activeRunes) >= 1 then
        windower.send_command('input /ja "Vallation" <me>')
    end
    if usePflug and recast[24] == 0 and countTable(activeRunes) >= 1 then
        windower.send_command('input /ja "Pflug" <me>')
    end
end

---------------------------------------------
-- Save Settings for the RUN Job
---------------------------------------------
local function saveSettings()
    settings.useSwipe     = useSwipe
    settings.useLunge     = useLunge
    settings.useSwordplay = useSwordplay
    settings.useVal       = useVal
    settings.usePflug     = usePflug
    settings.setRunes     = setRunes

    config.save(settings, job_config_file)
    windower.add_to_chat(2, "RUN: Settings saved!")
end

---------------------------------------------
-- Prerender Event for Automatic Ability Use
---------------------------------------------
windower.register_event('prerender', function()
    if enableJob then
        local incap = activeBuffs()
        if not incap then
            compare_buffs()
            performAbilities()
        end
    end
end)

---------------------------------------------
-- Job Command Interface: handle_command(args)
---------------------------------------------
-- This function is called when the user types:
--   //autobot RUN <command> [args...]
function run.handle_command(args)
    windower.add_to_chat(2, "[RUN DEBUG] Received: " .. table.concat(args, " "))
    if #args < 1 then
        windower.add_to_chat(2, "RUN: No command provided.")
        return
    end

    local cmd = args[1]:lower()

    if cmd == "start" or cmd == "on" then
        enableJob = true
        windower.add_to_chat(2, "RUN: Enabled!")
    elseif cmd == "stop" or cmd == "off" then
        enableJob = false
        windower.add_to_chat(2, "RUN: Disabled!")
    elseif cmd == "set" then
        windower.add_to_chat(2, "[RUN DEBUG] Processing set command with arguments: " .. table.concat(args, " "))
        set_Runes(args[2], args[3], args[4])
        windower.add_to_chat(2, "RUN: Runes updated.")
    elseif cmd == "swipe" then
        useSwipe = not useSwipe
        windower.add_to_chat(2, "RUN: Swipe Loop " .. (useSwipe and "Enabled" or "Disabled"))
    elseif cmd == "lunge" then
        useLunge = not useLunge
        windower.add_to_chat(2, "RUN: Lunge Loop " .. (useLunge and "Enabled" or "Disabled"))
    elseif cmd == "swordplay" then
        useSwordplay = not useSwordplay
        windower.add_to_chat(2, "RUN: Swordplay Loop " .. (useSwordplay and "Enabled" or "Disabled"))
    elseif cmd == "vallation" then
        useVal = not useVal
        windower.add_to_chat(2, "RUN: Vallation Loop " .. (useVal and "Enabled" or "Disabled"))
    elseif cmd == "pflug" then
        usePflug = not usePflug
        windower.add_to_chat(2, "RUN: Pflug Loop " .. (usePflug and "Enabled" or "Disabled"))
    elseif cmd == "save" then
        saveSettings()
    elseif cmd == "help" then
        windower.add_to_chat(2, "RUN: Commands:")
        windower.add_to_chat(2, "  RUN start/on         - Enable Rune Fencer automation")
        windower.add_to_chat(2, "  RUN stop/off         - Disable Rune Fencer automation")
        windower.add_to_chat(2, "  RUN set <r1> <r2> <r3> - Set up to three runes (by name or element)")
        windower.add_to_chat(2, "  RUN swipe            - Toggle Swipe loop")
        windower.add_to_chat(2, "  RUN lunge            - Toggle Lunge loop")
        windower.add_to_chat(2, "  RUN swordplay        - Toggle Swordplay loop")
        windower.add_to_chat(2, "  RUN vallation        - Toggle Vallation loop")
        windower.add_to_chat(2, "  RUN pflug            - Toggle Pflug loop")
        windower.add_to_chat(2, "  RUN save             - Save current settings")
        windower.add_to_chat(2, "  RUN help             - Display this help message")
    else
        windower.add_to_chat(123, "RUN: Unknown command: " .. cmd)
    end
end

---------------------------------------------
-- Return the Job Module
---------------------------------------------
return run