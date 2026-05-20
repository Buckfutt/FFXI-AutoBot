local pulling = {}
local packets = require('packets')
local coroutine = require('coroutine')
local res = require('resources')
local settings = nil  -- local settings reference

pulling.running = false
local last_pull_time = 0
local pull_attempt_interval = 1  -- Minimum interval (in seconds) between pull attempts

-- Setup your settings, expecting settings.pull_method and settings.target_list.
function pulling.set_settings(cfg)
    settings = cfg
    if settings.pull_method then
        windower.add_to_chat(207, "[Pulling] Settings loaded.")
    else
        windower.add_to_chat(123, "[Pulling] No pull_method setting found!")
    end
end

-- The pulling module **only** monitors the currently targeted mob and checks if it exists in `settings.target_list`.
function pulling.start()
    pulling.running = true
    windower.add_to_chat(207, "[Pulling] Started!")
    
    coroutine.schedule(function()
        while pulling.running do
            local player = windower.ffxi.get_player()
            local target = windower.ffxi.get_mob_by_target('t')

            if player and target and settings.target_list then
                local current_time = os.time()

                -- Ensure the current target exists in the target list.
                local target_name = target.name and target.name:lower()
                if target_name and settings.target_list:contains(target_name) then
                    -- Only pull if the target is unclaimed (status == 0).
                    if player.status == 1 and target.status == 0 then
                        -- Enforce a cooldown between pull attempts.
                        if (current_time - last_pull_time) >= pull_attempt_interval then
                            local pull_type = settings.pull_method.type
                            local pull_action = settings.pull_method.action

                            if pull_type == "spell" then
                                local recasts = windower.ffxi.get_spell_recasts()
                                local spell = res.spells:with('english', pull_action)
                                local recast = (spell and recasts[spell.id]) or 0
                                if recast <= 1 then
                                    windower.send_command('input /ma "' .. pull_action .. '" <t>')
                                    last_pull_time = current_time
                                end
                            elseif pull_type == "ability" then
                                local recasts = windower.ffxi.get_ability_recasts()
                                local ja = res.job_abilities:with('english', pull_action)
                                local recast = (ja and recasts[ja.id]) or 0
                                if recast <= 0 then
                                    windower.send_command('input /ja "' .. pull_action .. '" <t>')
                                    last_pull_time = current_time
                                end
                            elseif pull_type == "ranged" then
                                windower.send_command('input /ra <t>')
                                last_pull_time = current_time
                            end
                        end
                    end
                end
            end
            coroutine.sleep(1)
        end
    end, 0)
end

function pulling.stop()
    pulling.running = false
    windower.add_to_chat(207, "[Pulling] Stopped!")
    last_pull_time = 0
end

return pulling