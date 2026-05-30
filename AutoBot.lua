_addon.name = 'AutoBot'
_addon.version = '1.4.3'
_addon.author = 'K0D3R'
_addon.commands = {'autobot', 'ab', 'bot'}

local packets = require('packets')
config = require('config')

-- Store Job Info
local last_main_job = nil
local last_sub_job  = nil
local globalPause = false

-- Define module states and load settings (including a whitelist field)
local settings = config.load({
    modules = {
        general      = true,
        follow       = true,
        targeting    = false,
        pulling      = false,
        combat       = true,
        casting      = true,
		trusts       = true,
        superwarp    = true,
		interaction  = true,
		navigation   = true,
		jobs         = true
    },
    whitelist = L{},  -- default empty whitelist
    target_list = L{}, -- Initialize target list as a Windower list
	jobs = {}   	  -- Initialize job-specific settings as a Windower List
})

-- Convert all whitelist entries to strings to avoid comparing numbers with strings
if settings.whitelist then
    for i, v in ipairs(settings.whitelist) do
        settings.whitelist[i] = tostring(v)
    end
else
    settings.whitelist = {}
end

local scripts = {
    general      = require('general'),
    follow       = require('follow'),
    targeting    = require('targeting'),
    pulling      = require('pulling'),
    combat       = require('combat'),
    casting      = require('casting'),
	interaction  = require('interaction'),
	navigation   = require('navigation'),
	trusts    	 = require('trusts'),
	jobs		 = {}
}

-- Pass packets reference to Modules:
scripts.general.set_packets(packets)
scripts.follow.set_packets(packets)
scripts.targeting.set_packets(packets)
scripts.interaction.set_packets(packets)

-- Pass Settings reference to Modules:
scripts.targeting.set_settings(settings)
scripts.pulling.set_settings(settings)
scripts.combat.set_settings(settings)

-- Pass module references to Trust Manager
scripts.trusts.set_modules(scripts.pulling, scripts.targeting)

-- Global Pause required after adding Job Scripts
scripts.pause = function(seconds)
    globalPause = true
    coroutine.schedule(function()
        globalPause = false
    end, seconds)
end

--------------------------------------------------------------------------------
-- JOB MODULE SYSTEM
--------------------------------------------------------------------------------
local function load_job_module(job)
    job = job:upper()

    local path = windower.addon_path .. 'Jobs/' .. job .. '.lua'

    if not windower.file_exists(path) then
        windower.add_to_chat(123, "[AutoBot] No job module found for: " .. job)
        return
    end

    -- Safe require
    local ok, module = pcall(require, 'Jobs/' .. job)

    if not ok or type(module) ~= "table" then
        windower.add_to_chat(123, "[AutoBot] Failed to load job module: " .. job)
        scripts.jobs[job] = nil
        return
    end

    scripts.jobs[job] = module

    if not settings.jobs[job] then
        settings.jobs[job] = {}
    end

    if type(module.init) == "function" then
        module.init(settings.jobs[job])
    end

    windower.add_to_chat(207, "[AutoBot] Loaded job module: " .. job)
end

local function load_jobs()
    local player = windower.ffxi.get_player()
    if not player then return end

    -- Normalize job names
    local mj = player.main_job and player.main_job:upper()
    local sj = player.sub_job and player.sub_job:upper()

    -- Load main job
    if mj and not scripts.jobs[mj] then
        load_job_module(mj)
    end

    -- Load sub job
    if sj and not scripts.jobs[sj] then
        load_job_module(sj)
    end
end

local function stop_all_jobs()
    for job, module in pairs(scripts.jobs) do
        if module.stop then
            module.stop()
        end
    end
end

local function check_job_change()
    local player = windower.ffxi.get_player()
    if not player then return end

    local mj = player.main_job
    local sj = player.sub_job

    -- First load (addon startup)
    if last_main_job == nil then
        last_main_job = mj
        last_sub_job  = sj
        load_jobs()
        return
    end

    -- Job changed
    if mj ~= last_main_job or sj ~= last_sub_job then
		if debug then
			windower.add_to_chat(207, "[AutoBot] Job change detected: Reloading job modules.")
		end

        stop_all_jobs()
        scripts.jobs = {} -- clear loaded modules
        load_jobs()

        last_main_job = mj
        last_sub_job  = sj
    end
end

windower.register_event('incoming chunk', function(id, data)
    if id == 0x00A then
        -- Zoning start: stop all job modules
        stop_all_jobs()
    end

    if id == 0x01B then
        -- Zoning finish: check if job changed
        coroutine.schedule(check_job_change, 0.5)
    end
end)

-- Auto-load job module on startup
local player = windower.ffxi.get_player()
if player and player.main_job then
    load_jobs()
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- Function to toggle a module state
local function toggle_module(module)
    if settings.modules[module] ~= nil then
        settings.modules[module] = not settings.modules[module]
        config.save(settings)
        windower.add_to_chat(207, "[" .. module .. "] module is now " ..
            (settings.modules[module] and "ENABLED" or "DISABLED"))
    else
        windower.add_to_chat(123, "Error: Invalid module name [" .. module .. "].")
    end
end

-- Function to check if a sender is whitelisted.
local function is_whitelisted(user)
    if not user then return false end
    local player = windower.ffxi.get_player()
    
	if player and user:lower() == player.name:lower() then
        return true
    end
	
    for i, name in ipairs(settings.whitelist) do
        if tostring(name):lower() == user:lower() then
            return true
        end
    end
    return false
end

-- Add string:split function if not already defined
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

--------------------------------------------------------------------------------
-- Chat Message Event Handler (processing only party chat mode)
--------------------------------------------------------------------------------
windower.register_event('chat message', function(message, sender, mode, is_gm)
    if mode ~= 3 and mode ~= 4 then return end

    -- Ensure only the sender is whitelisted
    if not is_whitelisted(sender) then return end

    local args = message:split(' ')
    local command = nil
    if args[1]:lower() == "bot" then
        command = args[2] and args[2]:lower() or nil
        table.remove(args, 1)
    elseif args[1]:sub(1,1) == '!' then
        command = args[1]:sub(2):lower()
    else
        return
    end

    -- Forward sender's name correctly for followme
    if command == "followme" then
		if debug then
			windower.add_to_chat(207, "[DEBUG] Forwarding followme command for sender: " .. sender)
		end
		
        windower.send_command('input //autobot followme ' .. sender)

    elseif command == "follow" then
        local target = args[1] or sender -- Follow target player, defaults to sender if not specified

        if debug then
			windower.add_to_chat(207, "[AutoBot:Follow] Sender " .. sender .. " is whitelisted -> Following: " .. target)
		end
		
        windower.send_command('input //autobot follow ' .. target)

	elseif command == "trademe" then
        if debug then
			windower.add_to_chat(207, "[DEBUG] Forwarding trademe command for sender: " .. sender)
		end
		
        windower.send_command('input //autobot trademe ' .. sender)
	
	elseif command == "mount" then
		local selected_mount = args[1] or "Raptor" -- Default to "Raptor" if none is specified

		if debug then
			windower.add_to_chat(207, "[AutoBot:Mount] Sender " .. sender .. " requests mount: " .. selected_mount)
		end
		
		windower.send_command('input //autobot mount ' .. selected_mount)

    else
        windower.send_command('input //autobot ' .. command .. ' ' .. table.concat(args, " ", 2))
    end
end)

--------------------------------------------------------------------------------
-- Pre-Renderer Loop
--------------------------------------------------------------------------------
windower.register_event('prerender', function()
    local info = windower.ffxi.get_info()
    if info.loading then return end
	if globalPause then return end
	
    -- JOB MODULE TICK
    local player = windower.ffxi.get_player()
	if player then
		local mj = player.main_job
		local sj = player.sub_job

		if mj and type(scripts.jobs[mj]) == "table" and type(scripts.jobs[mj].tick) == "function" then
			scripts.jobs[mj].tick()
		end

		if sj and type(scripts.jobs[sj]) == "table" and type(scripts.jobs[sj].tick) == "function" then
			scripts.jobs[sj].tick()
		end
	end
	
	-- NAVIGATION MODULE TICK
	scripts.navigation.tick()
end)

function pause_all(seconds)
    globalPause = true
    coroutine.schedule(function() globalPause = false end, seconds)
end

--------------------------------------------------------------------------------
-- Addon Command Handler
--------------------------------------------------------------------------------
windower.register_event('addon command', function(command, ...)
    local args = {...}

    if command == 'save' then
        config.save(settings)
		
		-- Save job settings
        for job, module in pairs(scripts.jobs) do
            if module.save then module.save() end
        end
		
        windower.add_to_chat(207, "[AutoBot] Settings saved successfully.")

    elseif command == 'load' then
        settings = config.load()
		
        -- Convert whitelist values to strings after loading.
        if settings.whitelist then
            for i, v in ipairs(settings.whitelist) do
                settings.whitelist[i] = tostring(v)
            end
        else
            settings.whitelist = {}
        end
        windower.add_to_chat(207, "[AutoBot] Settings loaded successfully.")

    elseif command == 'help' or command == nil or command == '' then
        windower.add_to_chat(207, "[AutoBot] Available Commands:")
		
		windower.add_to_chat(207, "------ ADDON ------")
		windower.add_to_chat(207, "//autobot set                    - (Addon) toggle a module")
		
        windower.add_to_chat(207, "------ GENERAL ------")
        windower.add_to_chat(207, "//autobot rest                   - (General) Rest command")
        windower.add_to_chat(207, "//autobot heal                   - (General) Heal command")
        windower.add_to_chat(207, "//autobot join                   - (General) Join command")
		windower.add_to_chat(207, "//autobot leave                  - (General) Leave command")
        windower.add_to_chat(207, "//autobot disband                - (General) Disband command")
        windower.add_to_chat(207, "//autobot passleader <name>      - (General) Transfer leadership")
        windower.add_to_chat(207, "//autobot invite <name>          - (General) Invite a party member")
		windower.add_to_chat(207, "//autobot warpring               - (General) Equips & Uses Warp Ring")
		windower.add_to_chat(207, "//autobot trade <name>           - (General) Opens a Trade Window")
		windower.add_to_chat(207, "//autobot accepttrade            - (General) Accepts the Trade")
		windower.add_to_chat(207, "//autobot mount  <name>          - (General) Mounts Specified Mount")
		windower.add_to_chat(207, "//autobot mountup                - (General) Mounts Default (Crawler)")
        
        windower.add_to_chat(207, "------ FOLLOW ------")
        windower.add_to_chat(207, "//autobot followme				- (Follow) Start following the player")
        windower.add_to_chat(207, "//autobot follow <target>        - (Follow) Start following specified player")
        windower.add_to_chat(207, "//autobot stopfollow             - (Follow) Stop following")
        
        windower.add_to_chat(207, "------ SUPERWARP ------")
        windower.add_to_chat(207, "//autobot warp/warpto <warp type> <warp location> [index] - (Superwarp) Warp command")
		
        windower.add_to_chat(207, "------ TARGETING ------")
        windower.add_to_chat(207, "//autobot target add <monster>   - (Targeting) Add a monster to the target list")
        windower.add_to_chat(207, "//autobot target remove <monster> - (Targeting) Remove a monster from the target list")
        windower.add_to_chat(207, "//autobot target list            - (Targeting) Display current targets")
		
		windower.add_to_chat(207, "------ NAVIGATION ------")
		windower.add_to_chat(207, "//autobot nav record <Name>      - (Nav) Begin recording a new path")
		windower.add_to_chat(207, "//autobot nav stop               - (Nav) Stop recording or stop navigation")
		windower.add_to_chat(207, "//autobot nav start <Name>       - (Nav) Start navigating a saved path")
		windower.add_to_chat(207, "//autobot nav loop               - (Nav) Toggle looping the path (restart at end)")
		windower.add_to_chat(207, "//autobot nav reverse            - (Nav) Toggle reverse mode (run path backwards once)")
		windower.add_to_chat(207, "//autobot nav bounce             - (Nav) Toggle bounce mode (run back and forth endlessly)")

		
		windower.add_to_chat(207, "------ PULLING ------")
		windower.add_to_chat(207, "//autobot pull start             - (Pulling) Start pulling targets")
		windower.add_to_chat(207, "//autobot pull stop              - (Pulling) Stop pulling targets")
		windower.add_to_chat(207, "//autobot pull method [spell/ranged/ability] \"action_name\"  - (Pulling) Set the pull method")
		
        windower.add_to_chat(207, "------ COMBAT ------")
        windower.add_to_chat(207, "//autobot attack                 - (Combat) Execute an attack")
        windower.add_to_chat(207, "//autobot assist [target]        - (Combat) Assist (defaults to player)")
        windower.add_to_chat(207, "//autobot disengage              - (Combat) Disengage from combat")
        windower.add_to_chat(207, "//autobot turn                   - (Combat) Execute a turn command")
        
		windower.add_to_chat(207, "------ JOB MODULES ------")
        windower.add_to_chat(207, "//ab job <job> start        		- Start job module")
        windower.add_to_chat(207, "//ab job <job> stop			    - Stop job module")
        windower.add_to_chat(207, "//ab job <job> <cmd>     		- Set job commands (//ab job sam hasso)")
		
        windower.add_to_chat(207, "------ CASTING ------")
        windower.add_to_chat(207, "//autobot cast \"spell\" [target]  - (Casting) Cast a spell")
        windower.add_to_chat(207, "//autobot stopcasting            - (Casting) Stop casting")
		
        windower.add_to_chat(207, "------ SETTINGS ------")
        windower.add_to_chat(207, "//autobot settings               - Show current module states")
        windower.add_to_chat(207, "//autobot toggle <module>        - Toggle a module (general, follow, combat, casting, superwarp)")
        windower.add_to_chat(207, "//autobot set <module>           - Toggle a module (if on, turn it off; if off, turn it on)")
        windower.add_to_chat(207, "//autobot whitelist add <user>   - Add a user to the whitelist")
        windower.add_to_chat(207, "//autobot whitelist remove <user>- Remove a user from the whitelist")
        windower.add_to_chat(207, "//autobot whitelist list         - List whitelisted users")
        windower.add_to_chat(207, "//autobot help                   - Displays this help message")

    elseif command == 'settings' then
        windower.add_to_chat(207, "[AutoBot] Current Module States:")
        for module, state in pairs(settings.modules) do
            windower.add_to_chat(207, "[" .. module .. "] is " .. (state and "ENABLED" or "DISABLED"))
        end

    elseif command == 'toggle' then
        if args[1] then
            toggle_module(args[1])
        else
            windower.add_to_chat(123, "Error: No module provided to toggle!")
        end

    elseif command == 'set' then
        if args[1] then
            toggle_module(args[1])
        else
            windower.add_to_chat(123, "Error: No module specified. Usage: //autobot set <module>")
        end

	------------------------
    -- Whitelist commands --
	------------------------
    elseif command == 'whitelist' then
		local subcmd = args[1] and args[1]:lower() or ""
		if subcmd == "add" then
			if args[2] then
				local user = tostring(args[2])  -- Convert input to string
				if not settings.whitelist:contains(user:lower()) then
					settings.whitelist:append(user:lower())  -- Ensure case consistency
					config.save(settings)
					windower.add_to_chat(207, "User " .. user .. " has been added to the whitelist.")
				else
					windower.add_to_chat(123, "User " .. user .. " is already whitelisted.")
				end
			else
				windower.add_to_chat(123, "Usage: //autobot whitelist add <username>")
			end
		elseif subcmd == "remove" then
			if args[2] then
				local user = tostring(args[2]):lower()  -- Convert input to lowercase string
				local index = nil

				-- Manually search for the index of the user in the whitelist
				for i, name in ipairs(settings.whitelist) do
					if name:lower() == user then
						index = i
						break
					end
				end

				-- If user is found, remove them from the whitelist
				if index then
					settings.whitelist:remove(index)  -- Remove by index instead of value
					config.save(settings)
					windower.add_to_chat(207, "User " .. user .. " has been removed from the whitelist.")
				else
					windower.add_to_chat(123, "User " .. user .. " is not in the whitelist.")
				end
			else
				windower.add_to_chat(123, "Usage: //autobot whitelist remove <username>")
			end
		elseif subcmd == "list" then
			if #settings.whitelist > 0 then
				windower.add_to_chat(207, "Whitelisted Users:")
				for i, user in ipairs(settings.whitelist) do
					windower.add_to_chat(207, "- " .. user)
				end
			else
				windower.add_to_chat(207, "No users whitelisted.")
			end
		else
			windower.add_to_chat(123, "Usage: //autobot whitelist [add/remove/list] <username>")
		end

	-----------------------------
    -- General module commands --
	-----------------------------
    elseif command == 'rest' or command == 'heal' then
        if settings.modules.general then
            local sender = windower.ffxi.get_mob_by_target('me').name
            if is_whitelisted(sender) then
                scripts.general.rest()
            else
                windower.add_to_chat(123, "Error: You are not whitelisted to use rest/heal!")
            end
        else
            windower.add_to_chat(123, "General module is disabled!")
        end
	
	----------------------------
	-- Interaction Commands   --
	----------------------------
	elseif command == 'tnpc' then
    if settings.modules.interaction then
        local sender = windower.ffxi.get_mob_by_target('me').name
        if is_whitelisted(sender) then
            if args and args[1] then
                local npc_name = table.concat(args, " "):gsub("^%s+", ""):gsub("%s+$", "")
                windower.add_to_chat(207, "[Interaction] Searching for NPC: " .. npc_name)
                scripts.interaction.target_npc(npc_name)
            else
                windower.add_to_chat(123, "Usage: //ab tnpc <npc_name>")
            end
        else
            windower.add_to_chat(123, "Error: You are not whitelisted to use tnpc!")
        end
    else
        windower.add_to_chat(123, "Interaction module is disabled!")
    end


	elseif command == 'key' then
		if settings.modules.interaction then
			local sender = windower.ffxi.get_mob_by_target('me').name
			if is_whitelisted(sender) then
				if args and args[1] then
					scripts.interaction.press_key(args[1])
				else
					windower.add_to_chat(123, "Usage: //ab key <key>")
				end
			else
				windower.add_to_chat(123, "Error: You are not whitelisted to use key!")
			end
		else
			windower.add_to_chat(123, "Interaction module is disabled!")
		end
	
	--------------------------------------------------------------------------------
	-- Job Commands
	--------------------------------------------------------------------------------
	elseif command == 'job' then
		local job = args[1] and args[1]:upper()
		local subcmd = args[2] and args[2]:lower()

		job = job:upper()
		
		if not job or not scripts.jobs[job] then
			windower.add_to_chat(123, "[AutoBot] No job module loaded for: " .. tostring(job))
			return
		end

		-- //ab job <job> start
		if subcmd == 'start' then
			scripts.jobs[job].start()
			return
		end

		-- //ab job <job> stop
		if subcmd == 'stop' then
			scripts.jobs[job].stop()
			return
		end

		-- //ab job <job> <cmd> <args...>
		if scripts.jobs[job].command then
			-- Forward everything after <job> <subcmd>
			local forwarded_args = { select(3, unpack(args)) }
			scripts.jobs[job].command(subcmd, forwarded_args)
			config.save(settings)
		else
			windower.add_to_chat(123, "[AutoBot] Job module has no command handler.")
		end

	-------------------------
	-- Navigation Control --
	-------------------------
	elseif command == 'nav' then
		if settings.modules.navigation then
			local sender = windower.ffxi.get_mob_by_target('me').name

			if is_whitelisted(sender) then
				local sub = args[1] and args[1]:lower()

				if sub == 'record' then
					if args[2] and args[2] ~= "" then
						scripts.navigation.start_record(args[2])
					else
						windower.add_to_chat(123, "[Nav] Error: You must provide a path name to record!")
					end

				elseif sub == 'stop' then
					if scripts.navigation.is_recording() then
						scripts.navigation.stop_record()
					else
						scripts.navigation.stop_playback()
					end

				elseif sub == 'start' then
					if args[2] and args[2] ~= "" then
						scripts.navigation.start_playback(args[2])
					else
						windower.add_to_chat(123, "[Nav] Error: You must provide a path name to start!")
					end

				elseif sub == 'loop' then
					scripts.navigation.toggle_loop()

				elseif sub == 'reverse' then
					scripts.navigation.toggle_reverse()

				elseif sub == 'bounce' then
					scripts.navigation.toggle_bounce()

				else
					windower.add_to_chat(123, "[Nav] Usage:")
					windower.add_to_chat(207, "//autobot nav record <Name>   - Begin recording a new path")
					windower.add_to_chat(207, "//autobot nav stop            - Stop recording or navigation")
					windower.add_to_chat(207, "//autobot nav start <Name>    - Start navigating a saved path")
					windower.add_to_chat(207, "//autobot nav loop            - Toggle loop mode")
					windower.add_to_chat(207, "//autobot nav reverse         - Toggle reverse mode (run backwards once)")
					windower.add_to_chat(207, "//autobot nav bounce          - Toggle bounce mode (run back and forth endlessly)")
				end

			else
				windower.add_to_chat(123, "Error: You are not whitelisted to use navigation commands!")
			end

		else
			windower.add_to_chat(123, "Navigation module is disabled!")
		end
	
	-------------------
	-- Mount Control --
	-------------------
	elseif command == 'mount' then
		if settings.modules.general then
			local sender = windower.ffxi.get_mob_by_target('me').name
			if is_whitelisted(sender) then

				if args[1] and args[1] ~= "" then
					scripts.general.mount(args[1])	-- User specified a mount name
				else
					scripts.general.mountup()	-- No mount specified → default behavior
				end

			else
				windower.add_to_chat(123, "Error: You are not whitelisted to mount!")
			end
		else
			windower.add_to_chat(123, "General module is disabled!")
		end

	elseif command == "mountup" then
		if settings.modules.general then
			local sender = windower.ffxi.get_mob_by_target('me').name
			if is_whitelisted(sender) then
				scripts.general.mountup()
			else
				windower.add_to_chat(123, "Error: You are not whitelisted to mount!")
			end
		else
			windower.add_to_chat(123, "General module is disabled!")
		end
	
	elseif command == "dismount" then
		if settings.modules.general then
			local sender = windower.ffxi.get_mob_by_target('me').name
			if is_whitelisted(sender) then
				scripts.general.dismount()
			else
				windower.add_to_chat(123, "Error: You are not whitelisted to dismount!")
			end
        else
            windower.add_to_chat(123, "General module is disabled!")
        end


	--------------------
	-- Party commands --
	--------------------
    elseif command == 'join' then
        if settings.modules.general then
            local sender = windower.ffxi.get_mob_by_target('me').name
            if is_whitelisted(sender) then
                scripts.general.join()
            else
                windower.add_to_chat(123, "Error: You are not whitelisted to use join!")
            end
        else
            windower.add_to_chat(123, "General module is disabled!")
        end

    elseif command == 'leave' then
        if settings.modules.general then
            local sender = windower.ffxi.get_mob_by_target('me').name
            if is_whitelisted(sender) then
                scripts.general.leave()
            else
                windower.add_to_chat(123, "Error: You are not whitelisted to use leave!")
            end
        else
            windower.add_to_chat(123, "General module is disabled!")
        end

    elseif command == 'disband' then
        if settings.modules.general then
            local sender = windower.ffxi.get_mob_by_target('me').name
            if is_whitelisted(sender) then
                scripts.general.disband()
            else
                windower.add_to_chat(123, "Error: You are not whitelisted to use disband!")
            end
        else
            windower.add_to_chat(123, "General module is disabled!")
        end

    elseif command == 'passleader' then
        if settings.modules.general then
            if args[1] and args[1] ~= "" then
                local sender = windower.ffxi.get_mob_by_target('me').name
                if is_whitelisted(sender) then
                    scripts.general.passleader(args[1])
                else
                    windower.add_to_chat(123, "Error: You are not whitelisted to pass leadership!")
                end
            else
                windower.add_to_chat(123, "Error: No player name provided for leadership transfer.")
            end
        else
            windower.add_to_chat(123, "General module is disabled!")
        end

    elseif command == 'invite' then
        if settings.modules.general then
            if args[1] and args[1] ~= "" then
                local sender = windower.ffxi.get_mob_by_target('me').name
                if is_whitelisted(sender) then
                    scripts.general.invite(args[1])
                else
                    windower.add_to_chat(123, "Error: You are not whitelisted to send party invites!")
                end
            else
                windower.add_to_chat(123, "Error: No player name provided for party invite.")
            end
        else
            windower.add_to_chat(123, "General module is disabled!")
        end
	
	elseif command == 'command' then
        if settings.modules.general then
            local sender = windower.ffxi.get_mob_by_target('me').name
            if is_whitelisted(sender) then
                if #args > 0 then
                    local raw_command = table.concat(args, " ")
                    windower.add_to_chat(207, "[Command] Executing raw command: " .. raw_command)
                    windower.send_command('input ' .. raw_command)
                else
                    windower.add_to_chat(123, "Error: No command provided. Usage: !command <raw command>")
                end
            else
                windower.add_to_chat(123, "Error: You are not whitelisted to execute raw commands!")
            end
        else
            windower.add_to_chat(123, "General module is disabled!")
        end
	
	elseif command == "warpring" then
		if settings.modules.general then
			local sender = windower.ffxi.get_mob_by_target('me').name
			if is_whitelisted(sender) then
				windower.add_to_chat(207, "Using Warp Ring!")

				-- ⭐ Pause all job logic so nothing interrupts the item use
				scripts.pause(3)

				scripts.general.usewarpring()
			else
				windower.add_to_chat(123, "Error: You are not whitelisted to use the Warp Ring command!")
			end
		end

    elseif command == "trademe" then
        if settings.modules.general then
            if args[1] and args[1] ~= "" then
                local target = args[1]
                if is_whitelisted(target) then
                    windower.add_to_chat(207, "Trading with: " .. target .. "!")
                    scripts.general.trade(target)
                else
                    windower.add_to_chat(123, "Error: Sender " .. target .. " is not whitelisted for trademe!")
                end
            else
                windower.add_to_chat(123, "Error: No sender provided for trademe!")
            end
        else
            windower.add_to_chat(123, "General module is disabled!")
        end

    elseif command == 'trade' then
        -- trade: the target name if provided; we use the local player's name as sender.
        if settings.modules.general then
            if args[1] and args[1] ~= "" then
                local sender = windower.ffxi.get_player().name
                if is_whitelisted(sender) then
                    scripts.general.trade(args[1])
                else
                    windower.add_to_chat(123, "Error: You (" .. sender .. ") are not whitelisted to initiate trades!")
                end
            else
                windower.add_to_chat(123, "Error: No player name provided for trade.")
            end
        else
            windower.add_to_chat(123, "General module is disabled!")
        end

    elseif command == 'accepttrade' then
        if settings.modules.general then
            local sender = windower.ffxi.get_player().name
            if is_whitelisted(sender) then
                scripts.general.accept_trade()
            else
                windower.add_to_chat(123, "Error: " .. sender .. " is not whitelisted to accept trades!")
            end
        else
            windower.add_to_chat(123, "General module is disabled!")
        end

    elseif command == 'canceltrade' then
        if settings.modules.general then
            local sender = windower.ffxi.get_player().name
            if is_whitelisted(sender) then
                scripts.general.cancel_trade()
            else
                windower.add_to_chat(123, "Error: " .. sender .. " is not whitelisted to cancel trades!")
            end
        else
            windower.add_to_chat(123, "General module is disabled!")
        end

    elseif command == 'tradeallgil' then
        if settings.modules.general then
            local sender = windower.ffxi.get_player().name
            if is_whitelisted(sender) then
                scripts.general.trade_all_gil()
            else
                windower.add_to_chat(123, "Error: " .. sender .. " is not whitelisted for tradeallgil!")
            end
        else
            windower.add_to_chat(123, "General module is disabled!")
        end

    elseif command == 'clear' then
        -- clear: only allowed for whitelisted users.
        local sender = windower.ffxi.get_player().name
        if is_whitelisted(sender) then
            scripts.general.clear()
        else
            windower.add_to_chat(123, "Error: " .. sender .. " is not whitelisted for clear!")
        end
	
	----------------------------
	-- Follow module commands --
	----------------------------
	elseif command == 'followme' then
		if settings.modules.follow then
			if args[1] and args[1] ~= "" then
				local sender = args[1]
				if is_whitelisted(sender) then
					windower.add_to_chat(207, "Following: " .. sender .. "!")
					scripts.follow.start_follow(sender)
				else
					windower.add_to_chat(123, "Error: Sender " .. sender .. " is not whitelisted for followme!")
				end
			else
				windower.add_to_chat(123, "Error: No sender provided for followme!")
			end
		else
			windower.add_to_chat(123, "Follow module is disabled!")
		end

	elseif command == 'follow' and args[1] then
		if settings.modules.follow then
			local target = args[1]
			if is_whitelisted(target) then
				windower.add_to_chat(207, "Following: " .. target)
				scripts.follow.start_follow(target)
			else
				windower.add_to_chat(123, "Error: Target " .. target .. " is not whitelisted for follow!")
			end
		else
			windower.add_to_chat(123, "Follow module is disabled!")
		end

	elseif command == 'stopfollow' then
		if settings.modules.follow then
			local player_name = windower.ffxi.get_mob_by_target('me').name
			if is_whitelisted(player_name) then
				windower.add_to_chat(207, "Stopping follow!")
				scripts.follow.stop_follow()
			else
				windower.add_to_chat(123, "Error: You are not whitelisted to stop follow!")
			end
		else
			windower.add_to_chat(123, "Follow module is disabled!")
		end

--	elseif command == 'setfollowdistance' and args[1] then
--		if settings.modules.follow then
--			local new_distance = tonumber(args[1])
--			if new_distance then
--				scripts.follow.set_follow_distance(new_distance)
--			else
--				windower.add_to_chat(123, "Error: Invalid follow distance!")
--			end
--		else
--			windower.add_to_chat(123, "Follow module is disabled!")
--		end

	---------------------------
	-- Trust Module Commands --
	---------------------------
	elseif command == 'trust' or command == 'trusts' then
		local subcmd = args[1] and args[1]:lower() or ""

		-- SAVE CURRENT TRUSTS
		if subcmd == "save" then
			local set_name = args[2]
			if not set_name then
				windower.add_to_chat(123, "[Trusts] Usage: trust save <setname>")
				return
			end
			scripts.trusts.save_set(set_name)
			return

		-- LIST SETS
		elseif subcmd == "list" then
			scripts.trusts.list_sets()
			return

		-- SUMMON / USE SET
		elseif subcmd == "summon" or subcmd == "use" then
			local set_name = args[2]
			if not set_name then
				windower.add_to_chat(123, "[Trusts] Usage: trust summon <setname>")
				return
			end
			scripts.trusts.summon_set(set_name)
			return

		-- MONITOR HP/MP
		elseif subcmd == "monitor" then
			local mode = args[2] and args[2]:lower() or ""
			local threshold1 = tonumber(args[3]) or 25
			local threshold2 = tonumber(args[4]) or 25

			if mode == "hp" or mode == "mp" or mode == "both" then
				scripts.trusts.monitor(mode, threshold1, threshold2)
			else
				windower.add_to_chat(123, "Usage: trust monitor <hp/mp/both> <threshold>")
			end
			return

		-- RELEASE TRUST
		elseif subcmd == "release" then
			local trust_name = args[2]
			if not trust_name then
				windower.add_to_chat(123, "[Trusts] Usage: trust release <trustname>")
				return
			end
			scripts.trusts.release(trust_name)
			return

		-- COOLDOWNS
		elseif subcmd == "cooldowns" then
			scripts.trusts.list_cooldowns()
			return

		else
			windower.add_to_chat(123, "Usage: trust <save / list / summon / use / monitor / release / cooldowns>")
			return
		end

	------------------------------
	-- Superwarp Module Commands --
	------------------------------
	elseif command == 'warp' or command == 'warpto' then
		if settings.modules.superwarp then
			if #args < 2 then
				windower.add_to_chat(123, "Error: Usage: !warpto <warp type> <warp location> [index]")
				return
			end

			local warp_type = args[1]
			local warp_location = ""
			local index = "1"

			if args[2]:sub(1,1) == '"' then
				local loc_tokens = {}
				local closing_quote_found = false
				local end_index = 2
				for i = 2, #args do
					table.insert(loc_tokens, args[i])
					if args[i]:sub(-1) == '"' then
						closing_quote_found = true
						end_index = i
						break
					end
				end
				if not closing_quote_found then
					windower.add_to_chat(123, "Error: Closing quote for warp location not found.")
					return
				end
				warp_location = table.concat(loc_tokens, " "):sub(2, -2)
				if end_index < #args then
					index = args[end_index + 1]
				end
			else
				local tokens = {}
				for i = 2, #args do
					table.insert(tokens, args[i])
				end
				local potential_index = tokens[#tokens]
				if tonumber(potential_index) then
					index = potential_index
					table.remove(tokens, #tokens)
				end
				warp_location = table.concat(tokens, " ")
			end

			local cmd = 'input //sw ' .. warp_type .. ' "' .. warp_location .. '" ' .. index
			windower.send_command(cmd)

			local party_msg = 'input /p [Superwarp] ' .. warp_type .. ' "' .. warp_location .. '" @ [' .. index .. ']'
			coroutine.schedule(function()
				windower.send_command(party_msg)
			end, 0.15)
		else
			windower.add_to_chat(123, "Superwarp module is disabled!")
		end

	-------------------------------
	-- Targeting Module Commands --
	-------------------------------
    elseif command == 'target' then
        local subcmd = args[1]
        local monster = table.concat(args, " ", 2) -- Capture full monster name

        -- Ensure settings.target_list is a proper Windower list.
        if type(settings.target_list) ~= "table" or not settings.target_list.contains then
            settings.target_list = L(settings.target_list or {})
        end
        -- Add an equals() method if missing.
        if not settings.target_list.equals then
            settings.target_list.equals = function(self, other)
                if #self ~= #other then return false end
                for i = 1, #self do
                    if self[i] ~= other[i] then return false end
                end
                return true
            end
        end

        if subcmd == 'add' and monster ~= "" then
            local normalized_name = monster:lower():gsub("^%s*(.-)%s*$", "%1")
            if not settings.target_list:contains(normalized_name) then
                settings.target_list:append(normalized_name)
                config.save(settings)
                windower.add_to_chat(settings.add_to_chat_mode, "[Targeting] Added: " .. normalized_name)
            else
                windower.add_to_chat(settings.add_to_chat_mode, "[Targeting] Target already in list: " .. normalized_name)
            end

        elseif subcmd == 'remove' and monster ~= "" then
            local normalized_name = monster:lower():gsub("^%s*(.-)%s*$", "%1")
            if settings.target_list:contains(normalized_name) then
                settings.target_list:remove(normalized_name)
                config.save(settings)
                windower.add_to_chat(settings.add_to_chat_mode, "[Targeting] Removed: " .. normalized_name)
            else
                windower.add_to_chat(settings.add_to_chat_mode, "[Targeting] Target not found: " .. normalized_name)
            end

        elseif subcmd == 'list' then
            if #settings.target_list > 0 then
                windower.add_to_chat(settings.add_to_chat_mode, "Target List: " .. table.concat(settings.target_list, ", "))
            else
                windower.add_to_chat(settings.add_to_chat_mode, "No targets currently saved.")
            end
		
		elseif subcmd == 'start' or subcmd == 'on' then
			scripts.targeting.start()
		elseif subcmd == 'stop' or subcmd == 'off' then
			scripts.targeting.stop()

        else
            windower.add_to_chat(settings.add_to_chat_mode, "Usage: //autobot target [add / remove / list] <monster>")
        end

	-----------------------------
	-- Pulling Module Commands --
	-----------------------------
    elseif command == 'pull' then
        if args[1] == 'start' or args[1] == 'on' then
            scripts.pulling.start()
        elseif args[1] == 'stop' or args[1] == 'off' then
            scripts.pulling.stop()
        elseif args[1] == 'method' then
            local method_type = args[2] and args[2]:lower()
            local action_name = table.concat(args, " ", 3)
            if method_type == 'spell' and action_name ~= "" then
                settings.pull_method = { type = 'spell', action = action_name }
                windower.add_to_chat(207, '[AutoBot:Pulling] Set method to: Spell - ' .. action_name)
            elseif method_type == 'ranged' then
                settings.pull_method = { type = 'ranged' }
                windower.add_to_chat(207, '[AutoBot:Pulling] Set method to: Ranged Attack')
            elseif method_type == 'ability' and action_name ~= "" then
                settings.pull_method = { type = 'ability', action = action_name }
                windower.add_to_chat(207, '[AutoBot:Pulling] Set method to: Job Ability - ' .. action_name)
            else
                windower.add_to_chat(123, "Usage: //autobot pull method [spell/ranged/ability] \"action_name\"")
            end
        else
            windower.add_to_chat(123, "Usage: //autobot pull start | stop | method [spell/ranged/ability] \"action_name\"")
        end

	----------------------------
    -- Combat module commands --
	----------------------------
    elseif command == 'attack' then
        if settings.modules.combat then
            local sender = windower.ffxi.get_mob_by_target('me').name
            if is_whitelisted(sender) then
                windower.add_to_chat(207, "[AutoBot:Combat] Executing attack!")
                scripts.combat.attack()
            else
                windower.add_to_chat(123, "Error: You are not whitelisted to attack!")
            end
        else
            windower.add_to_chat(123, "Combat module is disabled!")
        end

    elseif command == 'assist' then
        if settings.modules.combat then
            local sender = windower.ffxi.get_mob_by_target('me').name
            if is_whitelisted(sender) then
                local target = args[1] or windower.ffxi.get_player().name
                windower.add_to_chat(207, "[AutoBot:Combat] Assisting: " .. target .. "!")
                scripts.combat.assist(target)
            else
                windower.add_to_chat(123, "Error: You are not whitelisted to assist!")
            end
        else
            windower.add_to_chat(123, "Combat module is disabled!")
        end

    elseif command == 'disengage' then
        if settings.modules.combat then
            local sender = windower.ffxi.get_mob_by_target('me').name
            if is_whitelisted(sender) then
                windower.add_to_chat(207, "[AutoBot:Combat] Disengaging!")
                scripts.combat.disengage()
            else
                windower.add_to_chat(123, "Error: You are not whitelisted to disengage!")
            end
        else
            windower.add_to_chat(123, "Combat module is disabled!")
        end

    elseif command == 'turn' then
        if settings.modules.combat then
            local sender = windower.ffxi.get_mob_by_target('me').name
            if is_whitelisted(sender) then
				if debug then
					windower.add_to_chat(207, "[AutoBot:Combat] Turning!")
				end
                scripts.combat.turn()
            else
                windower.add_to_chat(123, "Error: You are not whitelisted to turn!")
            end
        else
            windower.add_to_chat(123, "Combat module is disabled!")
        end
	
	elseif command == 'approach' then
		if settings.modules.combat then
			local sender = windower.ffxi.get_mob_by_target('me').name
			if is_whitelisted(sender) then

				-- Ensure the key exists
				if settings.combat.approach == nil then
					settings.combat.approach = false
				end

				-- Toggle
				settings.combat.approach = not settings.combat.approach

				if settings.combat.approach then
					windower.add_to_chat(207, "[AutoBot:Combat] Approach Mode ENABLED!")
				else
					windower.add_to_chat(123, "[AutoBot:Combat] Approach Mode DISABLED.")
				end

				config.save(settings)

			else
				windower.add_to_chat(123, "Error: You are not whitelisted to toggle approach mode!")
			end
		else
			windower.add_to_chat(123, "Combat module is disabled!")
		end

	-----------------------------------------
	-- Remote Job Module Commands (!job)   --
	-----------------------------------------
	elseif command == 'job' then
		local sender = windower.ffxi.get_player().name

		if not is_whitelisted(sender) then
			windower.add_to_chat(123, "Error: Sender " .. sender .. " is not whitelisted for !job!")
			return
		end

		local job = args[1] and args[1]:upper()
		if not job then
			windower.add_to_chat(123, "Error: No job provided for !job command!")
			return
		end

		if not scripts.jobs[job] then
			windower.add_to_chat(123, "Error: No job module loaded for: " .. job)
			return
		end

		local subcmd = args[2]
		if not subcmd then
			windower.add_to_chat(123, "Error: No subcommand provided for !job " .. job .. "!")
			return
		end

		-- Build argument list for job module
		local job_args = {}
		for i = 3, #args do
			table.insert(job_args, args[i])
		end

		windower.add_to_chat(
			207,
			"[AutoBot:" .. job .. "] Remote command from " .. sender ..
			": " .. subcmd .. " " .. table.concat(job_args, " ")
		)

		-- Forward to job module
		scripts.jobs[job].command(subcmd, job_args)
		config.save(settings)

	-----------------------------
	-- Casting module commands --
	-----------------------------
	elseif command == 'cast' then
    if settings.modules.casting then
        local sender = windower.ffxi.get_mob_by_target('me').name
        if is_whitelisted(sender) then
            local spell = args[1] -- Correctly take the spell from args[1]
            local target = args[2] or "<me>" -- Default to <me> if no target is given

            if debug then
				windower.add_to_chat(207, "[DEBUG] Extracted spell: " .. tostring(spell))
				windower.add_to_chat(207, "[DEBUG] Extracted target: " .. tostring(target))
			end

            if spell and spell ~= "" then
                windower.add_to_chat(207, "[AutoBot:Casting] Executing spell: " .. spell .. " on target: " .. target)
                scripts.casting.cast_spell(spell, target)
            else
                windower.add_to_chat(123, "Error: No spell provided. Usage: !cast \"spellname\" [target]")
            end
        else
            windower.add_to_chat(123, "Error: You are not whitelisted to cast spells!")
        end
    else
        windower.add_to_chat(123, "Casting module is disabled!")
    end

    elseif command == 'stopcasting' then
        if settings.modules.casting then
            local sender = windower.ffxi.get_mob_by_target('me').name
            if is_whitelisted(sender) then
                windower.add_to_chat(207, "[AutoBot:Casting] Stopping casting!")
                scripts.casting.stop_casting()
            else
                windower.add_to_chat(123, "Error: You are not whitelisted to stop casting!")
            end
        else
            windower.add_to_chat(123, "Casting module is disabled!")
        end
	end
end)