-- Harvest Minigame Client
-- Modern button-mashing minigame with farming theme

local QBCore = exports['qb-core']:GetCoreObject()
local isMinigameActive = false
local minigameThread = nil

-- Show harvest minigame with modern farming-themed UI
function ShowHarvestMinigame(farmId, callback)
    if not Config.HarvestMinigame or not Config.HarvestMinigame.enabled then
        if callback then callback('ok') end
        return
    end
    
    if isMinigameActive then
        if callback then callback('failed') end
        return
    end
    
    isMinigameActive = true
    
    local difficulty = Config.HarvestMinigame.difficulty or 'medium'
    local settings = Config.HarvestMinigame.timing[difficulty] or Config.HarvestMinigame.timing.medium
    
    local startTime = GetGameTimer()
    local duration = 3000 -- 3 seconds
    local requiredPresses = 12
    local pressCount = 0
    local lastPress = 0
    local cooldown = 150
    local result = 'failed'
    
    -- Adjust based on difficulty
    if difficulty == 'easy' then
        requiredPresses = 8
        duration = 4000
    elseif difficulty == 'hard' then
        requiredPresses = 15
        duration = 2500
    end
    
    -- Lock controls during minigame
    local controlsToDisable = {24, 25, 257, 140, 141, 142, 143, 37, 44, 45, 47, 58, 263, 264}
    
    minigameThread = CreateThread(function()
        while isMinigameActive do
            local currentTime = GetGameTimer()
            local elapsed = currentTime - startTime
            
            -- Disable controls
            for _, control in ipairs(controlsToDisable) do
                DisableControlAction(0, control, true)
            end
            
            -- ESC to cancel
            if IsControlJustPressed(0, 322) then
                result = 'cancelled'
                isMinigameActive = false
                break
            end
            
            if elapsed >= duration then
                -- Time's up
                if pressCount >= (requiredPresses * 0.7) then
                    result = 'good'
                else
                    result = 'failed'
                end
                break
            end
            
            Wait(0)
            
            -- Modern UI with farming colors (green theme)
            
            -- Pulsing glow effect
            local pulseAlpha = math.floor(100 + (math.sin(elapsed / 200) * 50))
            
            -- Outer glow layers for depth (green farming theme)
            DrawRect(0.5, 0.88, 0.326, 0.146, 76, 175, 80, pulseAlpha * 0.3) -- Green glow
            DrawRect(0.5, 0.88, 0.323, 0.143, 76, 175, 80, pulseAlpha * 0.5)
            
            -- Main background with gradient simulation
            DrawRect(0.5, 0.88, 0.32, 0.14, 15, 20, 15, 200) -- Dark green-black
            
            -- Animated border glow (green theme)
            DrawRect(0.5, 0.808, 0.32, 0.003, 76, 175, 80, 255) -- Top border
            DrawRect(0.5, 0.808, 0.32, 0.001, 139, 195, 74, pulseAlpha) -- Top glow
            DrawRect(0.5, 0.952, 0.32, 0.003, 76, 175, 80, 255) -- Bottom border
            DrawRect(0.5, 0.952, 0.32, 0.001, 139, 195, 74, pulseAlpha) -- Bottom glow
            
            -- Side accent lines
            DrawRect(0.34, 0.88, 0.002, 0.14, 76, 175, 80, 200) -- Left
            DrawRect(0.66, 0.88, 0.002, 0.14, 76, 175, 80, 200) -- Right
            
            -- Title with intense glow (farming theme)
            SetTextFont(4)
            SetTextProportional(1)
            SetTextScale(0.50, 0.50)
            SetTextColour(139, 195, 74, 255) -- Light green
            SetTextDropshadow(2, 0, 0, 0, 255)
            SetTextEdge(2, 76, 175, 80, 255)
            SetTextCentre(true)
            SetTextEntry("STRING")
            AddTextComponentString("⚡ HARVESTING ⚡")
            DrawText(0.5, 0.82)
            
            -- Instruction text with gradient effect simulation
            SetTextFont(0)
            SetTextScale(0.35, 0.35)
            SetTextColour(200, 255, 200, 255) -- Light green tint
            SetTextDropshadow(1, 0, 0, 0, 200)
            SetTextCentre(true)
            SetTextEntry("STRING")
            AddTextComponentString("Press ~g~E~w~ rapidly to harvest")
            DrawText(0.5, 0.86)
            
            -- Progress bar with multi-layer design
            local progress = math.min(1.0, pressCount / requiredPresses)
            
            -- Progress bar background with depth
            DrawRect(0.5, 0.902, 0.244, 0.044, 0, 0, 0, 180) -- Outer shadow
            DrawRect(0.5, 0.9, 0.242, 0.042, 0, 0, 0, 200) -- Shadow
            DrawRect(0.5, 0.9, 0.24, 0.04, 10, 15, 10, 255) -- Container
            
            -- Progress bar fill with animated gradient (farming colors)
            local barColor = {244, 67, 54} -- Red (low)
            local glowColor = {255, 100, 100}
            if progress >= 0.7 then
                barColor = {76, 175, 80} -- Green (good)
                glowColor = {139, 195, 74}
            elseif progress >= 0.4 then
                barColor = {255, 193, 7} -- Yellow (medium)
                glowColor = {255, 235, 59}
            end
            
            if progress > 0 then
                local barWidth = 0.236 * progress
                local barX = 0.5 - (0.236 / 2) + (barWidth / 2)
                
                -- Multi-layer glow effect
                DrawRect(barX, 0.9, barWidth + 0.004, 0.044, glowColor[1], glowColor[2], glowColor[3], pulseAlpha * 0.4)
                DrawRect(barX, 0.9, barWidth + 0.002, 0.040, glowColor[1], glowColor[2], glowColor[3], pulseAlpha * 0.6)
                DrawRect(barX, 0.9, barWidth, 0.036, barColor[1], barColor[2], barColor[3], 255)
                
                -- Shine effect on top
                DrawRect(barX, 0.891, barWidth * 0.9, 0.012, 255, 255, 255, 80)
                -- Bottom gradient
                DrawRect(barX, 0.909, barWidth, 0.018, barColor[1] * 0.7, barColor[2] * 0.7, barColor[3] * 0.7, 180)
            end
            
            -- Counter text with outline
            SetTextFont(4)
            SetTextScale(0.42, 0.42)
            SetTextColour(255, 255, 255, 255)
            SetTextDropshadow(2, 0, 0, 0, 255)
            SetTextEdge(2, 0, 0, 0, 255)
            SetTextCentre(true)
            SetTextEntry("STRING")
            AddTextComponentString(string.format("%d / %d", pressCount, requiredPresses))
            DrawText(0.5, 0.888)
            
            -- Time bar with sleek design (green theme)
            local timeProgress = 1.0 - (elapsed / duration)
            DrawRect(0.5, 0.937, 0.242, 0.020, 0, 0, 0, 200) -- Shadow
            DrawRect(0.5, 0.935, 0.24, 0.018, 10, 15, 10, 255) -- Container
            
            if timeProgress > 0 then
                local timeColor = timeProgress > 0.5 and {76, 175, 80} or {244, 67, 54}
                local timeGlow = timeProgress > 0.5 and {139, 195, 74} or {255, 100, 100}
                local timeWidth = 0.236 * timeProgress
                local timeX = 0.5 - (0.236 / 2) + (timeWidth / 2)
                
                -- Glowing time bar
                DrawRect(timeX, 0.935, timeWidth + 0.002, 0.022, timeGlow[1], timeGlow[2], timeGlow[3], pulseAlpha * 0.5)
                DrawRect(timeX, 0.935, timeWidth, 0.014, timeColor[1], timeColor[2], timeColor[3], 255)
                DrawRect(timeX, 0.930, timeWidth * 0.9, 0.006, 255, 255, 255, 60) -- Shine
            end
            
            -- Time label with styling
            SetTextFont(0)
            SetTextScale(0.30, 0.30)
            SetTextColour(200, 255, 200, 255) -- Light green
            SetTextDropshadow(1, 0, 0, 0, 200)
            SetTextCentre(true)
            SetTextEntry("STRING")
            local remainingTime = math.ceil((duration - elapsed) / 1000)
            AddTextComponentString(string.format("⏱ %ds  |  Press ~r~ESC~w~ to cancel", remainingTime))
            DrawText(0.5, 0.946)
            
            -- Check for E press
            if IsControlJustPressed(0, 38) then -- E key
                if currentTime - lastPress > cooldown then
                    pressCount = pressCount + 1
                    lastPress = currentTime
                    PlaySoundFrontend(-1, "CLICK_BACK", "WEB_NAVIGATION_SOUNDS_PHONE", true)
                    
                    if pressCount >= requiredPresses then
                        result = 'perfect'
                        break
                    end
                end
            end
        end
        
        isMinigameActive = false
        minigameThread = nil
        
        -- Play result sound
        if result == 'perfect' then
            PlaySoundFrontend(-1, "PICK_UP", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
        elseif result == 'good' then
            PlaySoundFrontend(-1, "CONTINUE", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
        elseif result == 'cancelled' then
            PlaySoundFrontend(-1, "CANCEL", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
        else
            PlaySoundFrontend(-1, "ERROR", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
        end
        
        if callback then 
            callback(result)
        end
    end)
end

-- Emergency cleanup
function StopHarvestMinigame()
    if isMinigameActive then
        isMinigameActive = false
        if minigameThread then
            minigameThread = nil
        end
    end
end

-- Command to test minigame
RegisterCommand('testminigame', function()
    ShowHarvestMinigame(nil, function(result)
        QBCore.Functions.Notify('🌾 Harvest Result: ' .. result:upper(), result == 'perfect' and 'success' or (result == 'good' and 'primary' or 'error'))
    end)
end, false)

-- Export for other scripts
exports('ShowHarvestMinigame', ShowHarvestMinigame)
exports('StopHarvestMinigame', StopHarvestMinigame)
