-- general.lua
local general = {}

-- Our packets reference; will be set externally.
local packets = nil

-------------------------------------------------------------
-- Set the packets reference from the main module.
-------------------------------------------------------------
function general.set_packets(new_packets)
    packets = new_packets
end

-------------------------------------------------------------
-- Existing General Functions
-------------------------------------------------------------
function general.rest()
    windower.send_command('input /heal')
end

function general.join()
    windower.send_command('input /join')
end

function general.leave()
    windower.send_command('input /pcmd leave')
end

function general.disband()
    windower.send_command('input /pcmd breakup')
end

function general.invite(player)
    if player and player ~= "" then
        windower.send_command('input /pcmd add ' .. player)
    else
        windower.add_to_chat(123, "Error: No player name provided for party invite.")
    end
end

function general.passleader(player)
    if player and player ~= "" then
        windower.send_command('input /pcmd leader ' .. player)
    else
        windower.add_to_chat(123, "Error: No player name provided for leadership transfer.")
    end
end

function general.usewarpring()
    windower.send_command('input /equip "ring2" "Warp Ring"')
    coroutine.schedule(function()
        windower.send_command('input /item "Warp Ring" <me>')
    end, 10)
end

function general.warp()
	
end

function general.warpme(sender)
	windower.send_command('input /ma "Warp II" ' .. sender)
end

function general.mountup()
	windower.send_command('input /mount "Crawler"')
end

function general.mount(mountName)
	windower.send_command('input /mount "' .. mountName .. '"')
end

function general.dismount()
	windower.send_command('input /dismount')
end

-------------------------------------------------------------
-- Trading Functions
-------------------------------------------------------------
function general.clear(callback)
    local totalPresses = 5             -- Number of Escape key presses
    local delayBetweenPresses = 0.25   -- Delay in seconds between presses
    local pressReleaseDelay = 0.1      -- Delay between key down and key up

    local function doEscape(count)
        if count > totalPresses then
            if callback then
                callback()
            end
            return
        end
        windower.send_command("setkey escape down;")
        coroutine.schedule(function()
            windower.send_command("setkey escape up;")
            coroutine.schedule(function()
                doEscape(count + 1)
            end, delayBetweenPresses)
        end, pressReleaseDelay)
    end

    doEscape(1)
end

function general.trade(playerName)
    if not playerName or playerName == "" then
        windower.add_to_chat(123, "Error: No player provided for trade sequence.")
        return
    end

    -- Call clear and wait until it's done
    general.clear(function()
        -- Now that the menus have been cleared, execute the trade sequence

        -- Step 1: Immediately target the designated player.
        windower.send_command('input /target ' .. playerName)

        -- Step 2: After 0.5 seconds, press Enter.
        coroutine.schedule(function()
            windower.send_command('setkey enter down;')
            coroutine.schedule(function()
                windower.send_command('setkey enter up;')

                -- Step 3: After 0.25 seconds from Enter, press Up Arrow.
                coroutine.schedule(function()
                    windower.send_command('setkey up down;')
                    coroutine.schedule(function()
                        windower.send_command('setkey up up;')

                        -- Step 4: After 0.25 seconds, press Up Arrow again.
                        coroutine.schedule(function()
                            windower.send_command('setkey up down;')
                            coroutine.schedule(function()
                                windower.send_command('setkey up up;')

                                -- Step 5: After 0.25 seconds, press Enter.
                                coroutine.schedule(function()
                                    windower.send_command('setkey enter down;')
                                    coroutine.schedule(function()
                                        windower.send_command('setkey enter up;')
                                    end, 0.1)
                                end, 0.25)

                            end, 0.1)
                        end, 0.25)

                    end, 0.1)
                end, 0.25)

            end, 0.1)
        end, 0.5)
    end)
end

function general.accept_trade()
    -- Press Up Arrow.
    windower.send_command('setkey up down;')
    coroutine.schedule(function()
        windower.send_command('setkey up up;')
        -- After releasing Up, wait 0.1 seconds then press Down Arrow.
        coroutine.schedule(function()
            windower.send_command('setkey down down;')
            coroutine.schedule(function()
                windower.send_command('setkey down up;')
                -- After releasing Down, wait 0.2 seconds then press Enter.
                coroutine.schedule(function()
                    windower.send_command('setkey enter down;')
                    coroutine.schedule(function()
                        windower.send_command('setkey enter up;')
                    end, 0.1)
                end, 0.2)
            end, 0.1)
        end, 0.1)
    end, 0.1)
end

function general.cancel_trade()
    -- Step 1: Press Up Arrow.
    windower.send_command('setkey up down;')
    coroutine.schedule(function()
        windower.send_command('setkey up up;')
        
        -- Step 2: After 0.1 seconds, press Down Arrow.
        coroutine.schedule(function()
            windower.send_command('setkey down down;')
            coroutine.schedule(function()
                windower.send_command('setkey down up;')
                
                -- Step 3: After an additional 0.1 seconds, press Down Arrow again.
                coroutine.schedule(function()
                    windower.send_command('setkey down down;')
                    coroutine.schedule(function()
                        windower.send_command('setkey down up;')
                        
                        -- Step 4: After 0.2 seconds, press Enter.
                        coroutine.schedule(function()
                            windower.send_command('setkey enter down;')
                            coroutine.schedule(function()
                                windower.send_command('setkey enter up;')
                                
                                -- Additional Step: Wait 1 second then press Escape a few times.
                                coroutine.schedule(function()
                                    -- First Escape press.
                                    windower.send_command('setkey escape down;')
                                    coroutine.schedule(function()
                                        windower.send_command('setkey escape up;')
                                        
                                        -- Second Escape press after 0.1 sec.
                                        coroutine.schedule(function()
                                            windower.send_command('setkey escape down;')
                                            coroutine.schedule(function()
                                                windower.send_command('setkey escape up;')
                                                
                                                -- Third Escape press after another 0.1 sec.
                                                coroutine.schedule(function()
                                                    windower.send_command('setkey escape down;')
                                                    coroutine.schedule(function()
                                                        windower.send_command('setkey escape up;')
                                                    end, 0.1)
                                                end, 0.1)
                                                
                                            end, 0.1)
                                        end, 0.1)
                                        
                                    end, 0.1)
                                end, 1.0)
                                
                            end, 0.1)
                        end, 0.2)
                        
                    end, 0.1)
                end, 0.1)
                
            end, 0.1)
        end, 0.1)
    end, 0.1)
end

function general.trade_all_gil()
    local leftDelay = 0.025  -- Very fast: 1/100th of a second for left arrow presses.
    local commonDelay = 0.2  -- Common delay for steps after left arrow sequence

    -- Step 1: Press UP key.
    windower.send_command('setkey up down;')
    coroutine.schedule(function()
        windower.send_command('setkey up up;')
        
        -- Step 2: Press ENTER.
        coroutine.schedule(function()
            windower.send_command('setkey enter down;')
            coroutine.schedule(function()
                windower.send_command('setkey enter up;')
                
                -- Step 3: Press LEFT arrow 10 times sequentially using recursion.
                local i = 1
                local function leftArrowSequence()
                    if i <= 10 then
                        windower.send_command('setkey left down;')
                        coroutine.schedule(function()
                            windower.send_command('setkey left up;')
                            i = i + 1
                            coroutine.schedule(leftArrowSequence, leftDelay)
                        end, leftDelay)
                    else
                        -- Step 4: Press ENTER.
                        coroutine.schedule(function()
                            windower.send_command('setkey enter down;')
                            coroutine.schedule(function()
                                windower.send_command('setkey enter up;')
                                
                                -- Step 5: Press DOWN arrow.
                                coroutine.schedule(function()
                                    windower.send_command('setkey down down;')
                                    coroutine.schedule(function()
                                        windower.send_command('setkey down up;')
                                        
                                        -- Step 6: Press ENTER.
                                        coroutine.schedule(function()
                                            windower.send_command('setkey enter down;')
                                            coroutine.schedule(function()
                                                windower.send_command('setkey enter up;')
                                            end, 0.1)
                                        end, commonDelay)
                                        
                                    end, 0.1)
                                end, commonDelay)
                                
                            end, 0.1)
                        end, commonDelay)
                    end
                end
                leftArrowSequence()
                
            end, 0.1)
        end, commonDelay)
        
    end, 0.1)
end

return general