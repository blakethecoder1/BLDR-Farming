-- Batch Harvesting Client
-- Allows players to harvest multiple plots at once

local selectedPlots = {}
local isBatchMode = false

-- Find nearby ready plots
function FindNearbyReadyPlots(maxDistance)
    if not Config.BatchHarvest or not Config.BatchHarvest.enabled then
        return {}
    end
    
    maxDistance = maxDistance or Config.BatchHarvest.maxDistance or 20.0
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local nearbyPlots = {}
    
    for farmId, farm in ipairs(Config.Farms) do
        local distance = #(playerCoords - farm.coords)
        if distance <= maxDistance then
            -- Request plot state from server
            -- For now, we'll just add the plot ID
            table.insert(nearbyPlots, {
                id = farmId,
                coords = farm.coords,
                distance = distance,
                label = farm.label or ('Plot ' .. farmId)
            })
        end
    end
    
    -- Sort by distance
    table.sort(nearbyPlots, function(a, b) return a.distance < b.distance end)
    
    return nearbyPlots
end

-- Toggle batch mode
function ToggleBatchMode()
    isBatchMode = not isBatchMode
    selectedPlots = {}
    
    if isBatchMode then
        QBCore.Functions.Notify('🌾 Batch Mode: ON - Select plots to harvest', 'primary', 5000)
    else
        QBCore.Functions.Notify('Batch Mode: OFF', 'primary')
    end
end

-- Add plot to selection
function TogglePlotSelection(farmId)
    if not isBatchMode then return false end
    
    local index = nil
    for i, id in ipairs(selectedPlots) do
        if id == farmId then
            index = i
            break
        end
    end
    
    if index then
        table.remove(selectedPlots, index)
        QBCore.Functions.Notify('Plot removed from batch', 'primary')
        return false
    else
        if #selectedPlots >= (Config.BatchHarvest.maxPlots or 5) then
            QBCore.Functions.Notify('Maximum plots selected (' .. Config.BatchHarvest.maxPlots .. ')', 'error')
            return false
        end
        
        table.insert(selectedPlots, farmId)
        QBCore.Functions.Notify('Plot added to batch (' .. #selectedPlots .. '/' .. Config.BatchHarvest.maxPlots .. ')', 'success')
        return true
    end
end

-- Execute batch harvest
function ExecuteBatchHarvest()
    if not isBatchMode or #selectedPlots == 0 then
        QBCore.Functions.Notify('No plots selected for batch harvest', 'error')
        return
    end
    
    -- Show progress bar
    if exports['ox_lib'] and exports['ox_lib'].progressBar then
        local timePerPlot = Config.BatchHarvest.timePerPlot or 3000
        local totalTime = timePerPlot * #selectedPlots
        
        local success = exports['ox_lib']:progressBar({
            duration = totalTime,
            label = 'Batch Harvesting ' .. #selectedPlots .. ' plots...',
            useWhileDead = false,
            canCancel = true,
            disable = {
                move = true,
                car = true,
                combat = true
            },
            anim = {
                dict = 'amb@prop_human_bum_bin@',
                clip = 'bin_weed_01',
                flags = 1
            }
        })
        
        if success then
            TriggerServerEvent('bldr_farming:batchHarvest', selectedPlots)
            selectedPlots = {}
            isBatchMode = false
        else
            QBCore.Functions.Notify('Batch harvest cancelled', 'error')
        end
    else
        -- Fallback without progress bar
        TriggerServerEvent('bldr_farming:batchHarvest', selectedPlots)
        selectedPlots = {}
        isBatchMode = false
    end
end

-- Check if plot is selected
function IsPlotSelected(farmId)
    for _, id in ipairs(selectedPlots) do
        if id == farmId then return true end
    end
    return false
end

-- Commands
RegisterCommand('batchharvest', function()
    ToggleBatchMode()
end, false)

RegisterCommand('executebatch', function()
    ExecuteBatchHarvest()
end, false)

-- Exports
exports('ToggleBatchMode', ToggleBatchMode)
exports('TogglePlotSelection', TogglePlotSelection)
exports('ExecuteBatchHarvest', ExecuteBatchHarvest)
exports('IsPlotSelected', IsPlotSelected)
exports('IsBatchMode', function() return isBatchMode end)
