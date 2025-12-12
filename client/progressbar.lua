-- Custom Progress Bar
-- Simple visual progress bar without dependencies

local isProgressActive = false

function ShowCustomProgress(duration, label, callback)
    if isProgressActive then
        if callback then callback(false) end
        return
    end
    
    isProgressActive = true
    local startTime = GetGameTimer()
    local success = true
    
    CreateThread(function()
        while isProgressActive do
            local currentTime = GetGameTimer()
            local elapsed = currentTime - startTime
            local progress = math.min(1.0, elapsed / duration)
            
            if elapsed >= duration then
                break
            end
            
            Wait(0)
            
            -- Draw background
            DrawRect(0.5, 0.9, 0.25, 0.06, 0, 0, 0, 200)
            
            -- Draw label
            SetTextFont(4)
            SetTextProportional(1)
            SetTextScale(0.35, 0.35)
            SetTextColour(255, 255, 255, 255)
            SetTextCentre(true)
            SetTextEntry("STRING")
            AddTextComponentString(label or "Processing...")
            DrawText(0.5, 0.88)
            
            -- Progress bar background
            DrawRect(0.5, 0.915, 0.22, 0.025, 50, 50, 50, 255)
            
            -- Progress bar fill
            if progress > 0 then
                DrawRect(0.5 - (0.22 / 2) + (0.22 * progress / 2), 0.915, 0.22 * progress, 0.025, 76, 175, 80, 255)
            end
        end
        
        isProgressActive = false
        if callback then
            callback(success)
        end
    end)
end

-- Export the function
exports('ShowCustomProgress', ShowCustomProgress)
