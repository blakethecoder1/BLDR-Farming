-- Client UI controller for bldr_farming
-- Ensures the farming NUI remains hidden during loading, only opens when triggered,
-- and properly releases focus when closed.  Also provides safety resets.

local QBCore = exports['qb-core']:GetCoreObject()

-- Hide UI and release focus on resource start
CreateThread(function()
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'hide' })
end)

-- Open the NUI with provided payload (state, progress, etc.)
RegisterNetEvent('bldr_farming:openUI', function(payload)
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'open', payload = payload })
end)

-- Close/hide the NUI and relinquish focus
RegisterNetEvent('bldr_farming:closeUI', function()
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'close' })
end)

-- Handle NUI callbacks for plant, water, harvest, and close
RegisterNUICallback('plant', function(data, cb)
    if data and data.farmId then
        TriggerServerEvent('bldr_farming:interact', tonumber(data.farmId))
    end
    TriggerEvent('bldr_farming:closeUI')
    cb('ok')
end)

RegisterNUICallback('water', function(data, cb)
    if data and data.farmId then
        TriggerServerEvent('bldr_farming:water', tonumber(data.farmId))
    end
    TriggerEvent('bldr_farming:closeUI')
    cb('ok')
end)

RegisterNUICallback('harvest', function(data, cb)
    if data and data.farmId then
        TriggerServerEvent('bldr_farming:interact', tonumber(data.farmId))
    end
    TriggerEvent('bldr_farming:closeUI')
    cb('ok')
end)

RegisterNUICallback('close', function(_, cb)
    TriggerEvent('bldr_farming:closeUI')
    cb('ok')
end)

-- Emergency UI reset command
RegisterCommand('uireset_farm', function()
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'hide' })
    QBCore.Functions.Notify('Farming UI reset', 'success')
end)

-- Ensure focus is released on resource stop
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
    end
end)