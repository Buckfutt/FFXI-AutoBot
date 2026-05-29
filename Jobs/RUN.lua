local RUN = {}

local res = require('resources')

-- State
local settings = nil
local enabled = false
local acting = false
local lastUsedJA = 0
local cooldownPeriod = 5

local activeRunes = {}
local activeRuneList = {}
local buffs = {}

------------------------------------------------------------
-- INIT
------------------------------------------------------------
function RUN.init(cfg)
    settings = cfg or {
        useSwipe = false,
        useLunge = false,
        useSwordplay = false,
        useVal = false,
        usePflug = false,
        desiredSlots = {}
    }

    settings.desiredSlots = settings.desiredSlots or {}
end

------------------------------------------------------------
-- HELPERS
------------------------------------------------------------
local function safePlayer()
    local p = windower.ffxi.get_player()
    if not p or not p.buffs then return nil end
    return p
end

local function autoJA(name, target)
    acting = true
    windower.send_command(('input /ja "%s" %s'):format(name, target))
    lastUsedJA = os.time()
    coroutine.schedule(function() acting = false end, cooldownPeriod)
end

local runeMap = {
    [523]='ignis', [524]='gelus', [525]='flabra', [526]='tellus',
    [527]='sulpor', [528]='unda', [529]='lux', [530]='tenebrae'
}

local function updateBuffs()
    local p = safePlayer()
    if not p then return end

    activeRunes = {}
    activeRuneList = {}
    buffs = {}

    for _, id in ipairs(p.buffs) do
        local r = runeMap[id]
        if r then
            table.insert(activeRuneList, r)
            activeRunes[r] = (activeRunes[r] or 0) + 1
        else
            local name = res.buffs[id] and res.buffs[id].english:lower()
            if name then buffs[name] = true end
        end
    end
end

local function countRunes()
    local c = 0
    for _, v in pairs(activeRunes) do c = c + v end
    return c
end

------------------------------------------------------------
-- RUNE MAINTENANCE
------------------------------------------------------------
function RUN.setRunes(a, b, c)
    local elementToRune = {
        fire='ignis', ice='gelus', wind='flabra', earth='tellus',
        thunder='sulpor', lightning='sulpor', water='unda',
        light='lux', dark='tenebrae'
    }

    local function convert(arg)
        if not arg then return nil end
        arg = arg:lower()
        if elementToRune[arg] then return elementToRune[arg] end
        if res.job_abilities:with('english', arg) then return arg end
        windower.add_to_chat(2, arg .. ' is not a valid rune.')
        return nil
    end

    settings.desiredSlots = {}

	local runes = { convert(a), convert(b), convert(c) }

	if runes[1] then settings.desiredSlots.slot1 = runes[1] end
	if runes[2] then settings.desiredSlots.slot2 = runes[2] end
	if runes[3] then settings.desiredSlots.slot3 = runes[3] end

    windower.add_to_chat(207, "[AutoBot:RUN] Rune slots updated.")
end

local function maintainRunes()
    if acting then return end
    if os.time() - lastUsedJA < cooldownPeriod then return end

    local p = safePlayer()
    if not p then return end

    if not settings.desiredSlots or next(settings.desiredSlots) == nil then
        return
    end

    local maxSlots = (p.main_job == 'RUN') and 3 or 2

    activeRuneList = activeRuneList or {}

    for slot = 1, maxSlots do
        local desired = settings.desiredSlots["slot" .. slot]

        if desired then
            local current = activeRuneList[slot]

            if current ~= desired then
                autoJA(desired, '<me>')
                return
            end
        end
    end
end

------------------------------------------------------------
-- ABILITY LOGIC
------------------------------------------------------------
local function performAbilities()
    local p = safePlayer()
    if not p then return end
    if p.status ~= 1 then return end

    local recast = windower.ffxi.get_ability_recasts()
    local totalRunes = countRunes()

    if settings.useSwipe and recast[141] == 0 and totalRunes >= 1 then
        windower.send_command('input /ja "Swipe" <t>')
    end

    if settings.useLunge and recast[142] == 0 and totalRunes >= 1 then
        windower.send_command('input /ja "Lunge" <t>')
    end

    if settings.useSwordplay and recast[68] == 0 then
        windower.send_command('input /ja "Swordplay" <me>')
    end

    if settings.useVal and recast[23] == 0 and totalRunes >= 1 then
        windower.send_command('input /ja "Vallation" <me>')
    end

    if settings.usePflug and recast[24] == 0 and totalRunes >= 1 then
        windower.send_command('input /ja "Pflug" <me>')
    end
end

------------------------------------------------------------
-- TICK
------------------------------------------------------------
function RUN.tick()
    if not enabled then return end

    updateBuffs()
    maintainRunes()
    performAbilities()
end

------------------------------------------------------------
-- START / STOP
------------------------------------------------------------
function RUN.start()
    enabled = true
    windower.add_to_chat(207, "[AutoBot:RUN] Module started.")
end

function RUN.stop()
    enabled = false
    acting = false
    windower.add_to_chat(207, "[AutoBot:RUN] Module stopped.")
end

------------------------------------------------------------
-- COMMAND HANDLER
------------------------------------------------------------
function RUN.command(cmd, args)
    if cmd == "set" then
        RUN.setRunes(args[1], args[2], args[3])

    elseif cmd == "swipe" then
        settings.useSwipe = not settings.useSwipe
        windower.add_to_chat(207, "Swipe: " .. tostring(settings.useSwipe))

    elseif cmd == "lunge" then
        settings.useLunge = not settings.useLunge
        windower.add_to_chat(207, "Lunge: " .. tostring(settings.useLunge))

    elseif cmd == "swordplay" then
        settings.useSwordplay = not settings.useSwordplay
        windower.add_to_chat(207, "Swordplay: " .. tostring(settings.useSwordplay))

    elseif cmd == "vallation" then
        settings.useVal = not settings.useVal
        windower.add_to_chat(207, "Vallation: " .. tostring(settings.useVal))

    elseif cmd == "pflug" then
        settings.usePflug = not settings.usePflug
        windower.add_to_chat(207, "Pflug: " .. tostring(settings.usePflug))
    end
end

return RUN
