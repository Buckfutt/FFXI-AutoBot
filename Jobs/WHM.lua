local WHM = {}

local config = require('config')
local coroutine = require('coroutine')

------------------------------------------------------------
-- STATE
------------------------------------------------------------
local active = false
local settings = nil
local cast_delay = 0.5

local mp_rest_threshold = 50   -- Rest when MP is below 50%
local mp_resume_threshold = 100 -- Stand when MP is full
local emergency_hp_threshold = 60 -- Stand if any party member < 60% HP

local resting = false
local rest_cooldown = 0

-- Cure thresholds (HP missing)
local cure_thresholds = {
    Cure      = 150,
    Cure_II   = 350,
    Cure_III  = 650,
    Cure_IV   = 1100,
    Cure_V    = 1600,
    Cure_VI   = 2200,
}

------------------------------------------------------------
-- SPELL DEFINITIONS
------------------------------------------------------------

-- Internal key -> {name, mp, type}
local spells = {
    -- Cure line
    cure      = { name = "Cure",      type = "cure" },
    cure2     = { name = "Cure II",   type = "cure" },
    cure3     = { name = "Cure III",  type = "cure" },
    cure4     = { name = "Cure IV",   type = "cure" },
    cure5     = { name = "Cure V",    type = "cure" },
    cure6     = { name = "Cure VI",   type = "cure" },
	
    -- Status removal
    poisona   = { name = "Poisona",   type = "status" },
    paralyna  = { name = "Paralyna",  type = "status" },
    silena    = { name = "Silena",    type = "status" },
    blindna   = { name = "Blindna",   type = "status" },
    viruna    = { name = "Viruna",    type = "status" },
    stona     = { name = "Stona",     type = "status" },
    cursna    = { name = "Cursna",    type = "status" },
    erase     = { name = "Erase",     type = "status" },

    -- Buffs
    haste     = { name = "Haste",     type = "buff" },
    haste2    = { name = "Haste II",  type = "buff" },
    protectra = { name = "Protectra V", type = "buff" }, -- Fix This Later (Tier toggle)
    shellra   = { name = "Shellra V",   type = "buff" }, -- Fix This Later (Tier toggle)
    auspice   = { name = "Auspice",   type = "buff" },

    regen     = { name = "Regen",     type = "buff" },
    regen2    = { name = "Regen II",  type = "buff" },
    regen3    = { name = "Regen III", type = "buff" },
    regen4    = { name = "Regen IV",  type = "buff" },
    regen5    = { name = "Regen V",   type = "buff" },
	
	divine_seal = { name = "Divine Seal", type = "ja" },
	afflatus_solace = { name = "Afflatus Solace", type = "ja" },
	afflatus_misery = { name = "Afflatus Misery", type = "ja" },
	esuna = { name = "Esuna", type = "status" },
}

local protectra_spells = {
    protectra1 = "Protectra",
    protectra2 = "Protectra II",
    protectra3 = "Protectra III",
    protectra4 = "Protectra IV",
    protectra5 = "Protectra V",
}

local shellra_spells = {
    shellra1 = "Shellra",
    shellra2 = "Shellra II",
    shellra3 = "Shellra III",
    shellra4 = "Shellra IV",
    shellra5 = "Shellra V",
}

-- Debuff ID -> removal spell key
-- (Adjust buff IDs if needed)
local debuff_map = {
    [2]  = "poisona",   -- Poison
    [3]  = "paralyna",  -- Paralysis
    [4]  = "silena",    -- Silence
    [5]  = "blindna",   -- Blind
    [6]  = "viruna",    -- Virus
    [7]  = "stona",     -- Petrify
    [20] = "cursna",    -- Curse
    [21] = "erase",     -- Slow / generic removable
    [22] = "erase",     -- Defense down
    [23] = "erase",     -- Attack down
}

------------------------------------------------------------
-- INIT
------------------------------------------------------------
function WHM.init(job_settings)
    settings = job_settings

    -- Per-spell toggles (all off by default)
    settings.spells = settings.spells or {}
    for key, _ in pairs(spells) do
        if settings.spells[key] == nil then
            settings.spells[key] = false
        end
    end

    -- Global feature toggles
    settings.enable_cure   = (settings.enable_cure   ~= false)
    settings.enable_status = (settings.enable_status ~= false)
    settings.enable_buffs  = (settings.enable_buffs  ~= false)
	settings.spells.divine_seal = settings.spells.divine_seal or false
	settings.spells.afflatus_solace = settings.spells.afflatus_solace or false
	settings.spells.afflatus_misery = settings.spells.afflatus_misery or false
	settings.spells.esuna = settings.spells.esuna or false
	settings.protectra_tier = settings.protectra_tier or "protectra5"
	settings.shellra_tier   = settings.shellra_tier   or "shellra5"

    windower.add_to_chat(207, "[AutoBot:WHM] White Mage module initialized.")
end

------------------------------------------------------------
-- START / STOP
------------------------------------------------------------
function WHM.start()
    if active then
        windower.add_to_chat(207, "[AutoBot:WHM] Already running.")
        return
    end

    active = true
    windower.add_to_chat(207, "[AutoBot:WHM] Started.")
    coroutine.schedule(WHM.main_loop, 0)
end

function WHM.stop()
    active = false
    windower.add_to_chat(207, "[AutoBot:WHM] Stopped.")
end

------------------------------------------------------------
-- UTILS
------------------------------------------------------------
local function can_cast()
    local player = windower.ffxi.get_player()
    if not player then return false end
    if player.status == 4 then return false end -- dead
    -- You can add silence / amnesia checks here if you track buffs
    return true
end

local function cast_spell(spell_name, target)
    if not can_cast() then return end
    windower.send_command('input /ma "' .. spell_name .. '" ' .. target)
    coroutine.sleep(cast_delay)
end

local function should_emergency_heal()
    local party = windower.ffxi.get_party()
    if not party then return false end

    for i = 0, 5 do
        local member = party["p" .. i]
        if member and member.hpp and member.hpp > 0 and member.hpp < emergency_hp_threshold then
            return true
        end
    end

    return false
end

local function ja_ready(name)
    local recasts = windower.ffxi.get_ability_recasts()
    local id = ja_recasts[name]
    return id and recasts[id] == 0
end

------------------------------------------------------------
-- CURE LOGIC
------------------------------------------------------------
local function choose_cure_spell(missing_hp)
    -- Highest tier first, but only if enabled
    if settings.spells.cure6 and missing_hp >= cure_thresholds.Cure_VI then
        return "Cure VI"
    end
    if settings.spells.cure5 and missing_hp >= cure_thresholds.Cure_V then
        return "Cure V"
    end
    if settings.spells.cure4 and missing_hp >= cure_thresholds.Cure_IV then
        return "Cure IV"
    end
    if settings.spells.cure3 and missing_hp >= cure_thresholds.Cure_III then
        return "Cure III"
    end
    if settings.spells.cure2 and missing_hp >= cure_thresholds.Cure_II then
        return "Cure II"
    end
    if settings.spells.cure and missing_hp >= cure_thresholds.Cure then
        return "Cure"
    end
    return nil
end

local function handle_cures()
    if not settings.enable_cure then return end

    local party = windower.ffxi.get_party()
    if not party then return end

    local best_target = nil
    local best_missing = 0
    local best_name = nil

    for i = 0, 5 do
        local member = party["p" .. i]
        if member and member.hpp and member.hpp > 0 and member.hpp < 100 then
            local missing = member.max_hp - member.hp
            if missing > best_missing then
                best_missing = missing
                best_target = member
                best_name = (i == 0) and "<me>" or member.name
            end
        end
    end

    if best_target and best_missing > 0 then
        local spell_name = choose_cure_spell(best_missing)
        if spell_name then
            cast_spell(spell_name, best_name)
        end
    end
end

------------------------------------------------------------
-- STATUS REMOVAL
------------------------------------------------------------
local function handle_status_removal()
    if not settings.enable_status then return end

    local party = windower.ffxi.get_party()
    if not party then return end

    -- DOOM PRIORITY
    for i = 0, 5 do
        local member = party["p" .. i]
        if member and member.buffs then
            for _, buff_id in ipairs(member.buffs) do
                if buff_id == 15 and settings.spells.cursna then -- Doom
                    local target = (i == 0) and "<me>" or member.name

                    -- Divine Seal + Cursna combo
                    if settings.spells.divine_seal and ja_ready("Divine Seal") then
                        windower.send_command('input /ja "Divine Seal" <me>')
                        coroutine.sleep(0.5)
                    end

                    cast_spell("Cursna", target)
                    return
                end
            end
        end
    end

    -- ESUNA LOGIC (AoE status removal)
    if settings.spells.esuna then
        for i = 0, 5 do
            local member = party["p" .. i]
            if member and member.buffs then
                for _, buff_id in ipairs(member.buffs) do
                    if debuff_map[buff_id] and buff_id ~= 15 then -- not doom
                        cast_spell("Esuna", "<me>")
                        return
                    end
                end
            end
        end
    end

    -- NORMAL STATUS REMOVAL
    for i = 0, 5 do
        local member = party["p" .. i]
        if member and member.buffs then
            for _, buff_id in ipairs(member.buffs) do
                local key = debuff_map[buff_id]
                if key and settings.spells[key] then
                    local spell = spells[key]
                    local target = (i == 0) and "<me>" or member.name
                    cast_spell(spell.name, target)
                    return
                end
            end
        end
    end
end

------------------------------------------------------------
-- BUFF LOGIC
------------------------------------------------------------
local function has_buff(member, buff_id)
    if not member or not member.buffs then return false end
    for _, b in ipairs(member.buffs) do
        if b == buff_id then return true end
    end
    return false
end

-- Buff IDs (adjust if needed)
local BUFF_HASTE   = 33
local BUFF_PROTECT = 40
local BUFF_SHELL   = 41
local BUFF_REGEN   = 42
local BUFF_AUSPICE = 476

local function handle_buffs()
    if not settings.enable_buffs then return end

    local party = windower.ffxi.get_party()
    if not party then return end

    for i = 0, 5 do
        local member = party["p" .. i]
        if member and member.hpp and member.hpp > 0 then
            local target = (i == 0) and "<me>" or member.name

            -- Haste / Haste II
            if settings.spells.haste2 or settings.spells.haste then
                if not has_buff(member, BUFF_HASTE) then
                    if settings.spells.haste2 then
                        cast_spell("Haste II", target)
                        return
                    elseif settings.spells.haste then
                        cast_spell("Haste", target)
                        return
                    end
                end
            end

            -- Protectra (self only)
			if settings.spells.protectra then
				local spell_name = protectra_spells[settings.protectra_tier]
				if spell_name and not has_buff(member, BUFF_PROTECT) then
					cast_spell(spell_name, "<me>")
					return
				end
			end

			-- Shellra (self only)
			if settings.spells.shellra then
				local spell_name = shellra_spells[settings.shellra_tier]
				if spell_name and not has_buff(member, BUFF_SHELL) then
					cast_spell(spell_name, "<me>")
					return
				end
			end

            -- Regen line
            if settings.spells.regen5 or settings.spells.regen4 or settings.spells.regen3 or settings.spells.regen2 or settings.spells.regen then
                if member.hpp < 95 and not has_buff(member, BUFF_REGEN) then
                    if settings.spells.regen5 then
                        cast_spell("Regen V", target)
                        return
                    elseif settings.spells.regen4 then
                        cast_spell("Regen IV", target)
                        return
                    elseif settings.spells.regen3 then
                        cast_spell("Regen III", target)
                        return
                    elseif settings.spells.regen2 then
                        cast_spell("Regen II", target)
                        return
                    elseif settings.spells.regen then
                        cast_spell("Regen", target)
                        return
                    end
                end
            end

			-- Divine Seal + Cure VI/V combo
			if settings.spells.divine_seal and ja_ready("Divine Seal") then
				if spell_name == "Cure VI" or spell_name == "Cure V" then
					windower.send_command('input /ja "Divine Seal" <me>')
					coroutine.sleep(0.5)
				end
			end
			
            -- Auspice
            if settings.spells.auspice and not has_buff(member, BUFF_AUSPICE) then
                cast_spell("Auspice", target)
                return
            end
			
			-- Afflatus Solace
			if settings.spells.afflatus_solace and ja_ready("Afflatus Solace") then
				cast_spell("Afflatus Solace", "<me>")
				return
			end
			-- Afflatus Misery
			if settings.spells.afflatus_misery and ja_ready("Afflatus Misery") then
				cast_spell("Afflatus Misery", "<me>")
				return
			end
        end
    end
end

------------------------------------------------------------
-- MAIN LOOP
------------------------------------------------------------
local function handle_mp_management()
    local player = windower.ffxi.get_player()
    if not player then return end

    local mp_percent = (player.vitals.mp / player.vitals.max_mp) * 100

    -- Cooldown to prevent sit/stand spam
    if rest_cooldown > 0 then
        rest_cooldown = rest_cooldown - 1
    end

    -- If resting but someone needs healing → stand up immediately
    if resting then
        if should_emergency_heal() then
            windower.send_command('input /heal off')
            resting = false
            rest_cooldown = 3
            return
        end

        -- Stand up when MP is recovered
        if mp_percent >= mp_resume_threshold and rest_cooldown == 0 then
            windower.send_command('input /heal off')
            resting = false
            rest_cooldown = 3
        end

        return -- Skip healing logic while resting
    end

    -- If NOT resting → check if we should sit
    if mp_percent < mp_rest_threshold and not should_emergency_heal() and rest_cooldown == 0 then
        windower.send_command('input /heal on')
        resting = true
        rest_cooldown = 3
        return
    end
end


function WHM.main_loop()
    while active do

        -- MP management first
        handle_mp_management()

        -- Skip healing logic if resting
        if not resting then
            handle_status_removal()
            handle_cures()
            handle_buffs()
        end

        coroutine.sleep(0.5)
    end
end

------------------------------------------------------------
-- TOGGLES
------------------------------------------------------------
local function toggle_spell(key)
    if not spells[key] then
        windower.add_to_chat(167, "[AutoBot:WHM] Invalid spell key: " .. tostring(key))
        return
    end
    settings.spells[key] = not settings.spells[key]
    config.save(settings)

    local status = settings.spells[key] and "enabled" or "disabled"
    windower.add_to_chat(207, "[AutoBot:WHM] " .. spells[key].name .. " is now " .. status .. ".")
end

------------------------------------------------------------
-- COMMAND HANDLER
------------------------------------------------------------
function WHM.command(cmd, args)
    cmd = cmd and cmd:lower()

    if cmd == "start" then return WHM.start() end
    if cmd == "stop"  then return WHM.stop()  end

    -- Global toggles
    if cmd == "cure"   then settings.enable_cure   = not settings.enable_cure;   windower.add_to_chat(207, "[AutoBot:WHM] Cure logic: "   .. tostring(settings.enable_cure));   return end
    if cmd == "status" then settings.enable_status = not settings.enable_status; windower.add_to_chat(207, "[AutoBot:WHM] Status logic: " .. tostring(settings.enable_status)); return end
    if cmd == "buffs"  then settings.enable_buffs  = not settings.enable_buffs;  windower.add_to_chat(207, "[AutoBot:WHM] Buff logic: "   .. tostring(settings.enable_buffs));  return end
	if cmd == "esuna" then return toggle_spell("esuna") end
	if cmd == "divineseal" then return toggle_spell("divine_seal") end
	if cmd == "solace" then return toggle_spell("afflatus_solace") end
	if cmd == "misery" then return toggle_spell("afflatus_misery") end

	-- Protectra tier selection
	if cmd == "protectra1" then settings.protectra_tier = "protectra1"; windower.add_to_chat(207, "[AutoBot:WHM] Protectra I selected."); return end
	if cmd == "protectra2" then settings.protectra_tier = "protectra2"; windower.add_to_chat(207, "[AutoBot:WHM] Protectra II selected."); return end
	if cmd == "protectra3" then settings.protectra_tier = "protectra3"; windower.add_to_chat(207, "[AutoBot:WHM] Protectra III selected."); return end
	if cmd == "protectra4" then settings.protectra_tier = "protectra4"; windower.add_to_chat(207, "[AutoBot:WHM] Protectra IV selected."); return end
	if cmd == "protectra5" then settings.protectra_tier = "protectra5"; windower.add_to_chat(207, "[AutoBot:WHM] Protectra V selected."); return end

	-- Shellra tier selection
	if cmd == "shellra1" then settings.shellra_tier = "shellra1"; windower.add_to_chat(207, "[AutoBot:WHM] Shellra I selected."); return end
	if cmd == "shellra2" then settings.shellra_tier = "shellra2"; windower.add_to_chat(207, "[AutoBot:WHM] Shellra II selected."); return end
	if cmd == "shellra3" then settings.shellra_tier = "shellra3"; windower.add_to_chat(207, "[AutoBot:WHM] Shellra III selected."); return end
	if cmd == "shellra4" then settings.shellra_tier = "shellra4"; windower.add_to_chat(207, "[AutoBot:WHM] Shellra IV selected."); return end
	if cmd == "shellra5" then settings.shellra_tier = "shellra5"; windower.add_to_chat(207, "[AutoBot:WHM] Shellra V selected."); return end


    -- Per-spell toggles (keys match table above)
    if spells[cmd] then
        return toggle_spell(cmd)
    end

    windower.add_to_chat(167, "[AutoBot:WHM] Unknown command: " .. tostring(cmd))
end

return WHM