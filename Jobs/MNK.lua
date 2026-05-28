local MNK = {}

local config = require('config')
local coroutine = require('coroutine')

------------------------------------------------------------
-- STATE
------------------------------------------------------------
local active = false
local settings = nil
local abilityDelay = 2

-- Recast IDs for MNK abilities
local ability_recasts = {
    Focus            = 12,
    Dodge            = 13,
    Chakra           = 14,
    Boost            = 15,
    Counterstance    = 16,
    Footwork         = 110,
    Impetus          = 111,
    Mantra           = 112,
    Perfect_Counter  = 113,
    Formless_Strikes = 17,
    Hundred_Fists    = 0,
    Inner_Strength   = 0,
}

------------------------------------------------------------
-- INIT
------------------------------------------------------------
function MNK.init(job_settings)
    settings = job_settings

    settings.abilities = settings.abilities or {
        Focus            = false,
        Dodge            = false,
        Chakra           = false,
        Boost            = false,
        Counterstance    = false,
        Footwork         = false,
        Impetus          = false,
        Mantra           = false,
        Perfect_Counter  = false,
        Formless_Strikes = false,
        Hundred_Fists    = false,
        Inner_Strength   = false,
    }

    windower.add_to_chat(207, "[AutoBot:MNK] Monk module initialized.")
end

------------------------------------------------------------
-- START / STOP
------------------------------------------------------------
function MNK.start()
    if active then
        windower.add_to_chat(207, "[AutoBot:MNK] Already running.")
        return
    end

    active = true
    windower.add_to_chat(207, "[AutoBot:MNK] Started.")
    coroutine.schedule(MNK.main_loop, 0)
end

function MNK.stop()
    active = false
    windower.add_to_chat(207, "[AutoBot:MNK] Stopped.")
end

------------------------------------------------------------
-- MAIN LOOP
------------------------------------------------------------
function MNK.main_loop()
    while active do
        local recasts = windower.ffxi.get_ability_recasts()
        local player = windower.ffxi.get_player()
        local engaged = (player.status == 1)

        for ability, enabled in pairs(settings.abilities) do
            if enabled then
                local recast_id = ability_recasts[ability]

                if recast_id and recasts[recast_id] == 0 then

                    --------------------------------------------------------
                    -- SMART LOGIC
                    --------------------------------------------------------

                    -- Chakra: only when HP < 60%
                    if ability == "Chakra" then
                        if player.vitals.hpp > 60 then
                            goto continue
                        end
                    end

                    -- Boost: only when engaged
                    if ability == "Boost" and not engaged then
                        goto continue
                    end

                    -- Counterstance: only when engaged
                    if ability == "Counterstance" and not engaged then
                        goto continue
                    end

                    -- Footwork: disabled by user request
                    if ability == "Footwork" then
                        goto continue
                    end

                    -- Impetus: only when engaged
                    if ability == "Impetus" and not engaged then
                        goto continue
                    end

                    -- Mantra: only when in a party
                    if ability == "Mantra" then
                        local party = windower.ffxi.get_party()
                        if not (party and party.party1_count and party.party1_count > 1) then
                            goto continue
                        end
                    end

                    -- Perfect Counter: only when targeted / in danger
                    if ability == "Perfect_Counter" then
                        local mob = windower.ffxi.get_mob_by_target("t")
                        if not mob or mob.hpp <= 0 then
                            goto continue
                        end
                    end

                    --------------------------------------------------------
                    -- EXECUTE JA
                    --------------------------------------------------------
                    local ja_name = ability:gsub("_", " ")
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
        windower.add_to_chat(167, "[AutoBot:MNK] Invalid ability: " .. ability)
        return
    end

    settings.abilities[ability] = not settings.abilities[ability]
    config.save(settings)

    local status = settings.abilities[ability] and "enabled" or "disabled"
    windower.add_to_chat(207, "[AutoBot:MNK] " .. ability:gsub("_", " ") .. " is now " .. status .. ".")
end

------------------------------------------------------------
-- COMMAND HANDLER
------------------------------------------------------------
function MNK.command(cmd, args)
    cmd = cmd and cmd:lower()

    if cmd == "start" then return MNK.start() end
    if cmd == "stop"  then return MNK.stop()  end

    if cmd == "focus"            then return toggle_ability("Focus") end
    if cmd == "dodge"            then return toggle_ability("Dodge") end
    if cmd == "chakra"           then return toggle_ability("Chakra") end
    if cmd == "boost"            then return toggle_ability("Boost") end
    if cmd == "counterstance"    then return toggle_ability("Counterstance") end
	if cmd == "footwork"		 then return toggle_ability("Footwork") end
    if cmd == "impetus"          then return toggle_ability("Impetus") end
    if cmd == "mantra"           then return toggle_ability("Mantra") end
    if cmd == "perfectcounter"   then return toggle_ability("Perfect_Counter") end
    if cmd == "formless"         then return toggle_ability("Formless_Strikes") end
    if cmd == "hundredfists"     then return toggle_ability("Hundred_Fists") end
    if cmd == "innerstrength"    then return toggle_ability("Inner_Strength") end

    windower.add_to_chat(167, "[AutoBot:MNK] Unknown command: " .. tostring(cmd))
end

return MNK