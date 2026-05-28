-----------------
-- Trusts Module
-----------------

local Trusts = {}

local config  = require('config')
local packets = require('packets')
local res     = require('resources')

-- External module references (set from AutoBot)
local pulling_module   = nil
local targeting_module = nil

-------------------------------------------------------------
-- Module wiring
-------------------------------------------------------------
function Trusts.set_modules(pulling, targeting)
    pulling_module   = pulling
    targeting_module = targeting
end

-------------------------------------------------------------
-- Settings
-------------------------------------------------------------
Trusts.settings = config.load({
    trust_sets        = {},   -- [set_name] = { "Kupipi", "Shantotto", ... }
    trust_cooldowns   = {},   -- [trust_name] = last_summon_time
    hp_threshold      = 25,
    mp_threshold      = 25,
    monitoring_enabled = {
        hp = true,
        mp = true,
    },
})

local function save_settings()
    config.save(Trusts.settings)
end

-------------------------------------------------------------
-- Pulling / Targeting control
-------------------------------------------------------------
function Trusts.pause_pulling()
    if pulling_module and pulling_module.stop then
        pulling_module.stop()
        windower.add_to_chat(207, "[Trusts] Paused pulling during trust summoning.")
    end
end

function Trusts.resume_pulling()
    if pulling_module and pulling_module.start then
        pulling_module.start()
        windower.add_to_chat(207, "[Trusts] Resumed pulling after trust summoning.")
    end
end

function Trusts.pause_targeting()
    if targeting_module and targeting_module.stop then
        targeting_module.stop()
        windower.add_to_chat(207, "[Trusts] Paused targeting during trust summoning.")
    end
end

function Trusts.resume_targeting()
    if targeting_module and targeting_module.start then
        targeting_module.start()
        windower.add_to_chat(207, "[Trusts] Resumed targeting after trust summoning.")
    end
end

-------------------------------------------------------------
-- Detect currently active trusts
-------------------------------------------------------------
local function get_active_trusts()
    local party = windower.ffxi.get_party()
    local active = {}

    for i = 0, 5 do
        local member = party['p' .. i]
        if member and member.mob then
            local m = member.mob
            if m.spawn_type == 14 then
                table.insert(active, m.name)
            end
        end
    end

    return active
end

-------------------------------------------------------------
-- Save trust set (active trusts only)
-------------------------------------------------------------
function Trusts.save_set(set_name)
    if not set_name or set_name == "" then
        windower.add_to_chat(123, "[Trusts] Error: No set name provided.")
        return
    end

    local active = get_active_trusts()

    if #active == 0 then
        windower.add_to_chat(123, "[Trusts] No active trusts to save.")
        return
    end

    Trusts.settings.trust_sets[set_name] = active
    save_settings()

    windower.add_to_chat(207, "[Trusts] Saved trust set '" .. set_name .. "' → " .. table.concat(active, ", "))
end

-------------------------------------------------------------
-- List trust sets
-------------------------------------------------------------
function Trusts.list_sets()
    if not next(Trusts.settings.trust_sets) then
        windower.add_to_chat(207, "[Trusts] No saved trust sets.")
        return
    end

    windower.add_to_chat(207, "[Trusts] Saved sets:")
    for set_name, trusts in pairs(Trusts.settings.trust_sets) do
        windower.add_to_chat(207, "- " .. set_name .. ": " .. table.concat(trusts, ", "))
    end
end

-------------------------------------------------------------
-- Summoning logic
-------------------------------------------------------------
local TRUST_RECAST = 240 -- seconds

function Trusts.summon_set(set_name)
    local trusts = Trusts.settings.trust_sets[set_name]
    if not trusts then
        windower.add_to_chat(123, "[Trusts] Error: Trust set '" .. tostring(set_name) .. "' not found.")
        return
    end

    if #trusts == 0 then
        windower.add_to_chat(123, "[Trusts] Trust set '" .. tostring(set_name) .. "' is empty.")
        return
    end

    windower.add_to_chat(207, "[Trusts] Summoning trust set: " .. set_name)

    Trusts.pause_pulling()
    Trusts.pause_targeting()

    local function summon_next(index)
        if index > #trusts then
            windower.add_to_chat(207, "[Trusts] Summoning complete.")
            Trusts.resume_pulling()
            Trusts.resume_targeting()
            return
        end

        local trust = trusts[index]
        local last = Trusts.settings.trust_cooldowns[trust] or 0
        local elapsed = os.time() - last

        if elapsed >= TRUST_RECAST then
            windower.send_command('input /trust "' .. trust .. '"')
            Trusts.settings.trust_cooldowns[trust] = os.time()
            save_settings()
            windower.add_to_chat(207, "[Trusts] Summoned: " .. trust)
        else
            local remaining = TRUST_RECAST - elapsed
            windower.add_to_chat(123, "[Trusts] Skipping " .. trust .. " (Cooldown " .. remaining .. "s)")
        end

        coroutine.schedule(function()
            summon_next(index + 1)
        end, 8)
    end

    summon_next(1)
end

-------------------------------------------------------------
-- Monitoring configuration (no loop yet)
-------------------------------------------------------------
function Trusts.monitor(mode, hp_threshold, mp_threshold)
    mode = mode and mode:lower() or nil

    if mode == "hp" then
        Trusts.settings.monitoring_enabled.hp = true
        Trusts.settings.monitoring_enabled.mp = false
        Trusts.settings.hp_threshold = tonumber(hp_threshold) or Trusts.settings.hp_threshold
        windower.add_to_chat(207, "[Trusts] Monitoring HP < " .. Trusts.settings.hp_threshold .. "%.")
    elseif mode == "mp" then
        Trusts.settings.monitoring_enabled.hp = false
        Trusts.settings.monitoring_enabled.mp = true
        Trusts.settings.mp_threshold = tonumber(mp_threshold) or Trusts.settings.mp_threshold
        windower.add_to_chat(207, "[Trusts] Monitoring MP < " .. Trusts.settings.mp_threshold .. "%.")
    elseif mode == "both" then
        Trusts.settings.monitoring_enabled.hp = true
        Trusts.settings.monitoring_enabled.mp = true
        Trusts.settings.hp_threshold = tonumber(hp_threshold) or Trusts.settings.hp_threshold
        Trusts.settings.mp_threshold = tonumber(mp_threshold) or Trusts.settings.mp_threshold
        windower.add_to_chat(
            207,
            "[Trusts] Monitoring HP < " .. Trusts.settings.hp_threshold ..
            "% and MP < " .. Trusts.settings.mp_threshold .. "%."
        )
    else
        windower.add_to_chat(123, "[Trusts] Usage: !trust monitor <hp/mp/both> <threshold>")
        return
    end

    save_settings()
end

-------------------------------------------------------------
-- Release / cooldown info
-------------------------------------------------------------
function Trusts.release(trust_name)
    if not trust_name or trust_name == "" then
        windower.add_to_chat(123, "[Trusts] Error: No trust provided for release.")
        return
    end

    windower.send_command('input /release "' .. trust_name .. '"')
    windower.add_to_chat(207, "[Trusts] Released: " .. trust_name)
end

function Trusts.list_cooldowns()
    windower.add_to_chat(207, "[Trusts] Cooldowns:")
    for trust, last in pairs(Trusts.settings.trust_cooldowns) do
        local remaining = math.max(0, TRUST_RECAST - (os.time() - last))
        windower.add_to_chat(207, "- " .. trust .. ": " .. remaining .. "s remaining")
    end
end

return Trusts