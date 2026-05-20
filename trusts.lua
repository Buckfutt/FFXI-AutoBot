----------------
-- UNFINISHED --
----------------

-- Trust Manager Module
local Trusts = {}

local config = require('config')
local windower = require('windower')

-- These will hold pulling & targeting module references
local pulling_module = nil
local targeting_module = nil

-- Function to receive module references
function Trusts.set_modules(pulling, targeting)
    pulling_module = pulling
    targeting_module = targeting
end

-- Load Trust Settings
Trusts.settings = config.load({
    trust_sets = {},
    trust_cooldowns = {},
    hp_threshold = 25, -- Default: Re-summon if HP < 25%
    mp_threshold = 25, -- Default: Re-summon if MP < 25%
    monitoring_enabled = { hp = true, mp = true } -- Default: Monitor both HP & MP
})

-- Pause Pulling & Targeting Modules
function Trusts.pause_pulling()
    if pulling_module then
        pulling_module.stop()
        windower.add_to_chat(207, "[Trusts] Paused pulling during trust summoning.")
    end
end

function Trusts.resume_pulling()
    if pulling_module then
        pulling_module.start()
        windower.add_to_chat(207, "[Trusts] Resumed pulling after trust summoning.")
    end
end

function Trusts.pause_targeting()
    if targeting_module then
        targeting_module.stop()
        windower.add_to_chat(207, "[Trusts] Paused targeting during trust summoning.")
    end
end

function Trusts.resume_targeting()
    if targeting_module then
        targeting_module.start()
        windower.add_to_chat(207, "[Trusts] Resumed targeting after trust summoning.")
    end
end

-- Save trust set
function Trusts.save_set(set_name, trust_list)
    if not set_name or #trust_list == 0 then
        windower.add_to_chat(123, "Error: Invalid trust set name or empty trust list.")
        return
    end

    Trusts.settings.trust_sets[set_name] = trust_list
    config.save(Trusts.settings)
    windower.add_to_chat(207, "[Trusts] Saved trust set: " .. set_name)
end

-- List trust sets
function Trusts.list_sets()
    if not next(Trusts.settings.trust_sets) then
        windower.add_to_chat(207, "No saved trust sets.")
        return
    end

    windower.add_to_chat(207, "[Trust Sets]:")
    for set_name, trusts in pairs(Trusts.settings.trust_sets) do
        windower.add_to_chat(207, "- " .. set_name .. ": " .. table.concat(trusts, ", "))
    end
end

-- Summon a trust set
function Trusts.summon_set(set_name)
    local trusts = Trusts.settings.trust_sets[set_name]
    if not trusts then
        windower.add_to_chat(123, "Error: Trust set '" .. set_name .. "' not found.")
        return
    end

    windower.add_to_chat(207, "[Trusts] Summoning trust set: " .. set_name)

    -- Stop pulling & targeting
    Trusts.pause_pulling()
    Trusts.pause_targeting()

    local function summon_next(index)
        if index > #trusts then
            windower.add_to_chat(207, "[Trusts] Summoning complete!")
            Trusts.resume_pulling()
            Trusts.resume_targeting()
            return
        end

        local trust = trusts[index]
        local cooldown_remaining = Trusts.settings.trust_cooldowns[trust] or 0
        if os.time() - cooldown_remaining >= 240 then
            windower.send_command('input /trust "' .. trust .. '"')
            Trusts.settings.trust_cooldowns[trust] = os.time() -- Store summon time
            config.save(Trusts.settings)
            windower.add_to_chat(207, "[Trusts] Summoned: " .. trust)
        else
            windower.add_to_chat(123, "Skipping " .. trust .. " (Cooldown active)")
        end
        
        coroutine.schedule(function() summon_next(index + 1) end, 8) -- 8s delay
    end

    summon_next(1)
end

-- Monitor trust HP/MP and resummon if below threshold
function Trusts.monitor(tracking_mode, hp_threshold, mp_threshold)
    if tracking_mode == "hp" then
        Trusts.settings.monitoring_enabled.hp = true
        Trusts.settings.hp_threshold = tonumber(hp_threshold) or 25
        windower.add_to_chat(207, "[Trusts] Monitoring HP below " .. Trusts.settings.hp_threshold .. "%.")
    elseif tracking_mode == "mp" then
        Trusts.settings.monitoring_enabled.mp = true
        Trusts.settings.mp_threshold = tonumber(mp_threshold) or 25
        windower.add_to_chat(207, "[Trusts] Monitoring MP below " .. Trusts.settings.mp_threshold .. "%.")
    elseif tracking_mode == "both" then
        Trusts.settings.monitoring_enabled.hp = true
        Trusts.settings.monitoring_enabled.mp = true
        Trusts.settings.hp_threshold = tonumber(hp_threshold) or 25
        Trusts.settings.mp_threshold = tonumber(mp_threshold) or 25
        windower.add_to_chat(207, "[Trusts] Monitoring both HP < " .. Trusts.settings.hp_threshold .. "% and MP < " .. Trusts.settings.mp_threshold .. "%.")
    else
        windower.add_to_chat(123, "Usage: !trust monitor <hp/mp/both> <threshold>")
        return
    end

    config.save(Trusts.settings)
end

-- Release a trust
function Trusts.release(trust_name)
    if not trust_name then
        windower.add_to_chat(123, "Error: No trust provided for release.")
        return
    end

    windower.send_command('input /release "' .. trust_name .. '"')
    windower.add_to_chat(207, "[Trusts] Released: " .. trust_name)
end

-- Check trust cooldowns
function Trusts.list_cooldowns()
    windower.add_to_chat(207, "[Trust Cooldowns]:")
    for trust, last_summoned in pairs(Trusts.settings.trust_cooldowns) do
        local remaining = math.max(0, 240 - (os.time() - last_summoned))
        windower.add_to_chat(207, "- " .. trust .. ": " .. remaining .. "s remaining")
    end
end

return Trusts