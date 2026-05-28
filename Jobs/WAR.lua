local WAR = {}

local config = require('config')
local coroutine = require('coroutine')

------------------------------------------------------------
-- STATE
------------------------------------------------------------
local active = false
local settings = nil
local abilityDelay = 2

-- Recast IDs for WAR abilities
local ability_recasts = {
    Berserk      = 1,
    Defender     = 3,
    Aggressor    = 4,
    Warcry       = 2,
    Retaliation  = 8,
    Blood_Rage   = 9,
}

------------------------------------------------------------
-- INIT
------------------------------------------------------------
function WAR.init(job_settings)
    settings = job_settings

    -- Ensure settings structure exists
    settings.abilities = settings.abilities or {
        Berserk     = false,
        Defender    = false,
        Aggressor   = false,
        Warcry      = false,
        Retaliation = false,
        Blood_Rage  = false,
    }

    windower.add_to_chat(207, "[AutoBot:WAR] Warrior module initialized.")
end

------------------------------------------------------------
-- START / STOP
------------------------------------------------------------
function WAR.start()
    if active then
        windower.add_to_chat(207, "[AutoBot:WAR] Already running.")
        return
    end

    active = true
    windower.add_to_chat(207, "[AutoBot:WAR] Started.")
    coroutine.schedule(WAR.main_loop, 0)
end

function WAR.stop()
    active = false
    windower.add_to_chat(207, "[AutoBot:WAR] Stopped.")
end

------------------------------------------------------------
-- MAIN LOOP
------------------------------------------------------------
function WAR.main_loop()
    while active do
        local recasts = windower.ffxi.get_ability_recasts()

        for ability, enabled in pairs(settings.abilities) do
            if enabled then
                local recast_id = ability_recasts[ability]

                if recast_id and recasts[recast_id] == 0 then
                    local ja_name = ability:gsub("_", " ")

                    windower.send_command('input /ja "' .. ja_name .. '" <me>')
                    coroutine.sleep(abilityDelay)
                end
            end
        end

        coroutine.sleep(1)
    end
end

------------------------------------------------------------
-- TOGGLE ABILITY
------------------------------------------------------------
local function toggle_ability(ability)
    if settings.abilities[ability] == nil then
        windower.add_to_chat(167, "[AutoBot:WAR] Invalid ability: " .. ability)
        return
    end

    settings.abilities[ability] = not settings.abilities[ability]
    config.save(settings)

    local status = settings.abilities[ability] and "enabled" or "disabled"
    windower.add_to_chat(207, "[AutoBot:WAR] " .. ability:gsub("_", " ") .. " is now " .. status .. ".")
end

------------------------------------------------------------
-- COMMAND HANDLER
------------------------------------------------------------
function WAR.command(cmd, args)
    cmd = cmd and cmd:lower()

    --------------------------------------------------------
    -- //ab job war start
    --------------------------------------------------------
    if cmd == "start" then
        WAR.start()
        return
    end

    --------------------------------------------------------
    -- //ab job war stop
    --------------------------------------------------------
    if cmd == "stop" then
        WAR.stop()
        return
    end

    --------------------------------------------------------
    -- Ability toggles
    --------------------------------------------------------
    if cmd == "berserk" then return toggle_ability("Berserk") end
    if cmd == "defender" then return toggle_ability("Defender") end
    if cmd == "aggressor" then return toggle_ability("Aggressor") end
    if cmd == "warcry" then return toggle_ability("Warcry") end
    if cmd == "retaliation" then return toggle_ability("Retaliation") end
    if cmd == "bloodrage" then return toggle_ability("Blood_Rage") end

    windower.add_to_chat(167, "[AutoBot:WAR] Unknown command: " .. tostring(cmd))
end

return WAR