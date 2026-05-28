local SAM = {}

local config = require('config')
local coroutine = require('coroutine')

------------------------------------------------------------
-- STATE
------------------------------------------------------------
local active = false
local settings = nil
local abilityDelay = 2

-- Recast IDs for SAM abilities
local ability_recasts = {
    Hasso          = 138,
    Seigan         = 139,
    Meditate       = 134,
    Third_Eye      = 133,
    Warding_Circle = 131,
    Sekkanoki      = 140,
    Sengikori      = 141,
    Hamanoha       = 147,
    Hagakure       = 148,
    Meikyo_Shizui  = 0,    -- SP1
    Yaegasumi      = 0,    -- SP2
    Konzen_Ittai   = 149,
}

------------------------------------------------------------
-- INIT
------------------------------------------------------------
function SAM.init(job_settings)
    settings = job_settings

    -- Ensure settings structure exists
    settings.abilities = settings.abilities or {
        Hasso = false,
        Seigan = false,
        Meditate = false,
        Third_Eye = false,
        Warding_Circle = false,
        Sekkanoki = false,
        Sengikori = false,
        Hamanoha = false,
        Hagakure = false,
        Meikyo_Shizui = false,
        Yaegasumi = false,
        Konzen_Ittai = false,
    }

    windower.add_to_chat(207, "[AutoBot:SAM] Samurai module initialized.")
end

------------------------------------------------------------
-- START / STOP
------------------------------------------------------------
function SAM.start()
    if active then
        windower.add_to_chat(207, "[AutoBot:SAM] Already running.")
        return
    end

    active = true
    windower.add_to_chat(207, "[AutoBot:SAM] Started.")
    coroutine.schedule(SAM.main_loop, 0)
end

function SAM.stop()
    active = false
    windower.add_to_chat(207, "[AutoBot:SAM] Stopped.")
end

------------------------------------------------------------
-- MAIN LOOP
------------------------------------------------------------
function SAM.main_loop()
    while active do
        local recasts = windower.ffxi.get_ability_recasts()
        local player = windower.ffxi.get_player()

        for ability, enabled in pairs(settings.abilities) do
            if enabled then
                local recast_id = ability_recasts[ability]

                if recast_id and recasts[recast_id] == 0 then

                    -- Meditate only below 1000 TP
                    if ability == "Meditate" and player and player.vitals.tp >= 1000 then
                        goto continue
                    end

                    local ja_name = ability:gsub("_", " ")

                    if ability == "Meikyo_Shizui" then ja_name = "Meikyo Shisui" end
                    if ability == "Konzen_Ittai" then ja_name = "Konzen-ittai" end

                    windower.send_command('input /ja "' .. ja_name .. '" <me>')
                    coroutine.sleep(abilityDelay)
                end
            end
            ::continue::
        end

        coroutine.sleep(1)
    end
end

------------------------------------------------------------
-- TOGGLE ABILITY
------------------------------------------------------------
local function toggle_ability(ability)
    if settings.abilities[ability] == nil then
        windower.add_to_chat(167, "[AutoBot:SAM] Invalid ability: " .. ability)
        return
    end

    settings.abilities[ability] = not settings.abilities[ability]
    config.save(settings)

    local status = settings.abilities[ability] and "enabled" or "disabled"
    windower.add_to_chat(207, "[AutoBot:SAM] " .. ability:gsub("_", " ") .. " is now " .. status .. ".")
end

------------------------------------------------------------
-- COMMAND HANDLER
------------------------------------------------------------
function SAM.command(cmd, args)
    cmd = cmd and cmd:lower()

    --------------------------------------------------------
    -- //ab job sam start
    --------------------------------------------------------
    if cmd == "start" then
        SAM.start()
        return
    end

    --------------------------------------------------------
    -- //ab job sam stop
    --------------------------------------------------------
    if cmd == "stop" then
        SAM.stop()
        return
    end

    --------------------------------------------------------
    -- Ability toggles
    --------------------------------------------------------
    if cmd == "hasso" then return toggle_ability("Hasso") end
    if cmd == "seigan" then return toggle_ability("Seigan") end
    if cmd == "meditate" then return toggle_ability("Meditate") end
    if cmd == "thirdeye" then return toggle_ability("Third_Eye") end
    if cmd == "wardingcircle" then return toggle_ability("Warding_Circle") end
    if cmd == "sekkanoki" then return toggle_ability("Sekkanoki") end
    if cmd == "sengikori" then return toggle_ability("Sengikori") end
    if cmd == "hamanoha" then return toggle_ability("Hamanoha") end
    if cmd == "hagakure" then return toggle_ability("Hagakure") end
    if cmd == "meikyo" then return toggle_ability("Meikyo_Shizui") end
    if cmd == "yaegasumi" then return toggle_ability("Yaegasumi") end
    if cmd == "konzen" then return toggle_ability("Konzen_Ittai") end

    windower.add_to_chat(167, "[AutoBot:SAM] Unknown command: " .. tostring(cmd))
end

return SAM