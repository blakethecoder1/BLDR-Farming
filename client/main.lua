-- Client logic for bldr_farming
-- Registers interactive zones on farming plots and handles
-- notifications and visual plant props.

-- Performance optimizations for client
local UPDATE_QUEUE = {}
local VISUAL_UPDATE_INTERVAL = 5000 -- 5 seconds between visual updates
local MAX_VISUAL_UPDATES_PER_CYCLE = 3

-- Batch visual updates to reduce performance impact
local function processPendingVisualUpdates()
    local processed = 0
    for i = #UPDATE_QUEUE, 1, -1 do
        if processed >= MAX_VISUAL_UPDATES_PER_CYCLE then
            break
        end
        
        local update = UPDATE_QUEUE[i]
        if update then
            -- Process the visual update
            if update.type == 'plant' then
                updatePlantVisual(update.farmId, update.state, update.progress, update.seedItem)
            end
            table.remove(UPDATE_QUEUE, i)
            processed = processed + 1
        end
    end
end

-- Start visual update processor
CreateThread(function()
    while true do
        Wait(VISUAL_UPDATE_INTERVAL)
        processPendingVisualUpdates()
    end
end)

-- Queue visual updates instead of processing immediately
local function queueVisualUpdate(updateType, farmId, state, progress, seedItem)
    UPDATE_QUEUE[#UPDATE_QUEUE + 1] = {
        type = updateType,
        farmId = farmId,
        state = state,
        progress = progress,
        seedItem = seedItem
    }
end

local QBCore = exports['qb-core']:GetCoreObject()

-- Table to store spawned plant objects
local plantObjects = {}

-- Interaction cooldown system to prevent duplicates
local lastInteractionTime = {}
local INTERACTION_COOLDOWN = 1000 -- 1 second cooldown

local function canInteractWithFarm(farmId)
    local currentTime = GetGameTimer()
    local lastTime = lastInteractionTime[farmId] or 0
    
    if currentTime - lastTime < INTERACTION_COOLDOWN then
        return false
    end
    
    lastInteractionTime[farmId] = currentTime
    return true
end

-- Emote system variables
local isPlayingEmote = false
local currentEmoteData = {}

-- Function to play farming emotes with progress bar
local function playFarmingEmote(emoteType, callback)
    if not Config.Emotes or not Config.Emotes.enabled then
        print("[bldr_farming] Emotes disabled - executing callback immediately")
        if callback then callback() end
        return
    end
    
    local emoteConfig = Config.Emotes[emoteType]
    if not emoteConfig then
        if callback then callback() end
        return
    end
    
    -- Force clear if already playing (don't block, just reset and continue)
    if isPlayingEmote then
        print("[bldr_farming] Clearing existing emote to start new one")
        isPlayingEmote = false
        currentEmoteData = nil
        ClearPedTasks(PlayerPedId())
    end
    
    isPlayingEmote = true
    currentEmoteData = emoteConfig
    currentEmoteData.startTime = GetGameTimer() -- Track when emote started
    
    local ped = PlayerPedId()
    
    -- Request animation dictionary with timeout
    RequestAnimDict(emoteConfig.dict)
    local attempts = 0
    while not HasAnimDictLoaded(emoteConfig.dict) and attempts < 50 do -- 5 second timeout
        Wait(100)
        attempts = attempts + 1
    end
    
    if not HasAnimDictLoaded(emoteConfig.dict) then
        print("[bldr_farming] Failed to load animation dict: " .. emoteConfig.dict .. " - bypassing emote")
        isPlayingEmote = false
        currentEmoteData = nil
        if callback then callback() end
        return
    end
    
    -- Play animation
    TaskPlayAnim(ped, emoteConfig.dict, emoteConfig.anim, 8.0, -8.0, -1, 1, 0, false, false, false)
    
    -- Show progress bar if enabled
    if emoteConfig.showProgress and exports['progressbar'] then
        exports['progressbar']:Progress({
            name = emoteType .. '_farming',
            duration = emoteConfig.duration,
            label = emoteConfig.progressText or 'Working...',
            useWhileDead = false,
            canCancel = not emoteConfig.freezePlayer,
            controlDisables = {
                disableMovement = emoteConfig.disableMovement,
                disableCarMovement = emoteConfig.disableCarMovement,
                disableMouse = emoteConfig.disableMouse,
                disableCombat = emoteConfig.disableCombat,
            },
            animation = {
                animDict = emoteConfig.dict,
                anim = emoteConfig.anim,
                flags = 1,
            }
        }, function(cancelled)
            -- Emergency cleanup
            isPlayingEmote = false
            currentEmoteData = nil
            ClearPedTasks(ped)
            
            print("[bldr_farming] Progress bar completed, cancelled=" .. tostring(cancelled))
            
            if not cancelled and callback then
                callback()
            elseif cancelled then
                QBCore.Functions.Notify('Action cancelled', 'error')
            end
        end)
    elseif exports['ox_lib'] and exports['ox_lib'].progressBar then
        -- Use ox_lib progress bar
        local success = exports['ox_lib']:progressBar({
            duration = emoteConfig.duration,
            label = emoteConfig.progressText or 'Working...',
            useWhileDead = false,
            canCancel = not emoteConfig.freezePlayer,
            disable = {
                move = emoteConfig.disableMovement,
                car = emoteConfig.disableCarMovement,
                mouse = emoteConfig.disableMouse,
                combat = emoteConfig.disableCombat,
            },
            anim = {
                dict = emoteConfig.dict,
                clip = emoteConfig.anim,
                flags = 1,
            }
        })
        
        -- Emergency cleanup
        isPlayingEmote = false
        currentEmoteData = nil
        ClearPedTasks(ped)
        
        print("[bldr_farming] ox_lib progress completed, success=" .. tostring(success))
        
        if success and callback then 
            callback()
        elseif not success then
            QBCore.Functions.Notify('Action cancelled', 'error')
        end
    else
        -- Fallback: just wait and play animation
        local startTime = GetGameTimer()
        local endTime = startTime + emoteConfig.duration
        
        -- Wait for duration or until cancelled
        while GetGameTimer() < endTime and isPlayingEmote do
            Wait(100)
        end
        
        local wasCompleted = isPlayingEmote -- If still playing, it completed normally
        
        -- Emergency cleanup
        isPlayingEmote = false
        currentEmoteData = nil
        ClearPedTasks(ped)
        
        print("[bldr_farming] Fallback emote completed, wasCompleted=" .. tostring(wasCompleted))
        
        if wasCompleted and callback then 
            callback()
        elseif not wasCompleted then
            QBCore.Functions.Notify('Action cancelled', 'error')
        end
    end
    
    -- Clean up animation dictionary
    RemoveAnimDict(emoteConfig.dict)
end

-- Function to cancel current emote
local function cancelEmote()
    if isPlayingEmote then
        isPlayingEmote = false
        currentEmoteData = nil
        ClearPedTasks(PlayerPedId())
        QBCore.Functions.Notify('Action cancelled', 'error')
    end
end

-- Movement detection and timeout thread for cancelling emotes
CreateThread(function()
    local lastPos = nil
    while true do
        Wait(100)
        
        if isPlayingEmote then
            -- Timeout check - auto-cancel emotes stuck for more than 60 seconds
            if currentEmoteData and currentEmoteData.startTime then
                local timeElapsed = GetGameTimer() - currentEmoteData.startTime
                if timeElapsed > 60000 then -- 60 seconds timeout
                    print("[bldr_farming] Auto-cancelling emote after 60 second timeout")
                    cancelEmote()
                    QBCore.Functions.Notify('Action timed out and was cancelled', 'error')
                end
            end
            
            -- Movement cancellation check
            if Config.Emotes and Config.Emotes.cancelOnMove then
                local ped = PlayerPedId()
                local currentPos = GetEntityCoords(ped)
                
                if lastPos then
                    local distance = #(currentPos - lastPos)
                    if distance > 0.5 then -- Player moved more than 0.5 units
                        cancelEmote()
                    end
                end
                
                lastPos = currentPos
            end
        else
            lastPos = nil
        end
    end
end)

-- Function to spawn a plant object at a farm plot
local function spawnPlant(farmId, plantType, progress)
    if not Config.PlantVisuals or not Config.PlantVisuals.enabled then return end
    
    if plantObjects[farmId] then
        deletePlant(farmId) -- Remove existing plant first
    end
    
    local farm = Config.Farms[farmId]
    if not farm then return end
    
    local models = Config.PlantVisuals.plantModels or {}
    local model = models[plantType] or Config.PlantVisuals.defaultModel or 'prop_plant_01a'
    
    -- Validate model exists, fallback to default if not
    if not IsModelValid(model) then
        print(("[bldr_farming] Invalid model %s for %s, using default"):format(model, plantType))
        model = Config.PlantVisuals.defaultModel or 'prop_plant_01a'
    end
    
    -- Alternative: Use growth stage models if scaling is disabled or not working
    if not Config.PlantVisuals.useScaling and Config.PlantVisuals.growthStages and Config.PlantVisuals.growthStages[plantType] then
        local stages = Config.PlantVisuals.growthStages[plantType]
        if progress <= 33 and stages.stage1 then
            model = stages.stage1
        elseif progress <= 66 and stages.stage2 then
            model = stages.stage2
        elseif stages.stage3 then
            model = stages.stage3
        end
    end
    
    local coords = farm.coords
    
    -- Request model
    RequestModel(model)
    local timeout = 0
    while not HasModelLoaded(model) and timeout < 5000 do
        Wait(100)
        timeout = timeout + 100
    end
    
    if HasModelLoaded(model) then
        -- Get actual ground Z coordinate to ensure plant sits on ground
        local groundZ = coords.z
        local hasGround, actualGroundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 10.0, false)
        if hasGround then
            groundZ = actualGroundZ
        end
        
        -- Apply model-specific ground offset (some models have their origin above ground)
        local modelOffset = 0
        if model == 'prop_weed_01' then
            modelOffset = -0.5 -- Lower weed plants into ground slightly
        end
        
        -- Create the plant object at actual ground level with model offset
        local plant = CreateObject(model, coords.x, coords.y, groundZ + modelOffset, false, false, false)
        
        -- Always apply scaling, especially for weed plants which are quite large by default
        local minScale = 0.1 -- Start very small for weed plants
        local maxScale = 0.6 -- Don't let weed plants get too huge
        local scale = minScale + ((progress or 0) / 100) * (maxScale - minScale)
        
        -- Force scaling to work - weed plants are too big otherwise
        local scalingWorked = false
        if SetEntityScale then
            pcall(function()
                SetEntityScale(plant, scale, scale, scale)
                scalingWorked = true
                print(("[bldr_farming] Scaled %s to %f for progress %d%%"):format(model, scale, progress or 0))
            end)
        end
        
        if not scalingWorked and SetObjectScale then
            pcall(function()
                SetObjectScale(plant, scale)
                scalingWorked = true
                print(("[bldr_farming] Scaled %s to %f for progress %d%%"):format(model, scale, progress or 0))
            end)
        end
        
        -- If scaling completely fails, still keep the plant but warn
        if not scalingWorked then
            print("[bldr_farming] Warning: Scaling failed for " .. tostring(model) .. ", plant may appear oversized")
        end
        
        -- Make it solid and detectable but freeze position (only if plant exists)
        if plant and DoesEntityExist(plant) then
            FreezeEntityPosition(plant, true)
            SetEntityCollision(plant, true, true) -- Enable collision for better qb-target detection
            
            -- Store the object reference
            plantObjects[farmId] = {
                object = plant,
                model = model,
                plantType = plantType,
                progress = progress or 0
            }
            
            -- Add harvest interaction if plant is mature enough (above 80% growth)
            if (progress or 0) >= 80 then
                exports['qb-target']:AddTargetEntity(plant, {
                    options = {
                        {
                            type = "client",
                            event = "bldr_farming:targetInteract",
                            icon = "fas fa-seedling",
                            label = "Harvest Plant",
                            farmId = farmId,
                            canInteract = function()
                                return not isBusy and (progress or 0) >= 80
                            end,
                        }
                    },
                    distance = 2.5,
                })
            end
            
            -- Add water can interaction for all growing plants (below 80% growth)
            if (progress or 0) < 80 then
                exports['qb-target']:AddTargetEntity(plant, {
                    options = {
                        {
                            type = "client",
                            event = "bldr_farming:waterWithCan",
                            icon = "fas fa-tint",
                            label = function()
                                local hasWaterCan = QBCore.Functions.HasItem('water_can') or QBCore.Functions.HasItem('watering_can')
                                local waterLevel = data.water or 50
                                if waterLevel >= 100 then
                                    return hasWaterCan and "💧 Water Plant (Already Full)" or "💧 Water Plant (Need Water Can)"
                                else
                                    return hasWaterCan and "💧 Water Plant" or "💧 Water Plant (Need Water Can)"
                                end
                            end,
                            farmId = farmId,
                            canInteract = function()
                                return not isBusy
                            end,
                        }
                    },
                    distance = 2.0,
                })
            
            -- Also add a coordinate-based zone around the plant for better targeting
            exports['qb-target']:AddBoxZone('farming_plant_' .. farmId, vector3(coords.x, coords.y, coords.z + 0.8), 1.5, 1.5, {
                name = 'farming_plant_' .. farmId,
                heading = 0,
                debugPoly = false,
                minZ = coords.z,
                maxZ = coords.z + 1.5,
            }, {
                options = {
                    {
                        type = "client",
                        event = "bldr_farming:targetInteract",
                        icon = "fas fa-seedling",
                        label = "Harvest Plant",
                        farmId = farmId,
                        canInteract = function()
                            return not isBusy and (progress or 0) >= 80
                        end,
                    }
                },
                distance = 2.5,
            })
            end
        end
        
        -- Set model as no longer needed
        SetModelAsNoLongerNeeded(model)
    else
        print(("[bldr_farming] Failed to load plant model: %s for %s, trying default model"):format(tostring(model), tostring(plantType)))
        
        -- Try with default model as fallback
        local defaultModel = 'prop_plant_01a'
        if model ~= defaultModel then
            RequestModel(defaultModel)
            local defaultTimeout = 0
            while not HasModelLoaded(defaultModel) and defaultTimeout < 3000 do
                Wait(100)
                defaultTimeout = defaultTimeout + 100
            end
            
            if HasModelLoaded(defaultModel) then
                -- Get actual ground Z coordinate to ensure plant sits on ground
                local groundZ = coords.z
                local hasGround, actualGroundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 10.0, false)
                if hasGround then
                    groundZ = actualGroundZ
                end
                
                -- Apply model-specific ground offset for fallback models
                local modelOffset = -0.2 -- Small offset for generic plant models
                
                -- Create the plant object at actual ground level with model offset
                local plant = CreateObject(defaultModel, coords.x, coords.y, groundZ + modelOffset, false, false, false)
                
                -- Make it solid and detectable but freeze position
                FreezeEntityPosition(plant, true)
                SetEntityCollision(plant, true, true) -- Enable collision for better qb-target detection
                
                -- Always apply reasonable scaling for default model
                local minScale = 0.1
                local maxScale = 0.6
                local scale = minScale + ((progress or 0) / 100) * (maxScale - minScale)
                SetEntityScale(plant, scale, scale, scale)
                print(("[bldr_farming] Scaled fallback %s to %f for progress %d%%"):format(defaultModel, scale, progress or 0))
                
                plantObjects[farmId] = {
                    object = plant,
                    model = defaultModel,
                    plantType = plantType,
                    progress = progress or 0
                }
                
                -- Add qb-target interaction if plant is mature enough (above 80% growth)
                if (progress or 0) >= 80 then
                    -- Add both entity targeting and coordinate-based targeting for better detection
                    exports['qb-target']:AddTargetEntity(plant, {
                        options = {
                            {
                                type = "client",
                                event = "bldr_farming:targetInteract",
                                icon = "fas fa-seedling",
                                label = "Harvest Plant",
                                farmId = farmId,
                                canInteract = function()
                                    return not isBusy and (progress or 0) >= 80
                                end,
                            }
                        },
                        distance = 2.5,
                    })
                    
                    -- Also add a coordinate-based zone around the plant for better targeting
                    exports['qb-target']:AddBoxZone('farming_plant_' .. farmId, vector3(coords.x, coords.y, coords.z + 0.8), 1.5, 1.5, {
                        name = 'farming_plant_' .. farmId,
                        heading = 0,
                        debugPoly = false,
                        minZ = coords.z,
                        maxZ = coords.z + 1.5,
                    }, {
                        options = {
                            {
                                type = "client",
                                event = "bldr_farming:targetInteract",
                                icon = "fas fa-seedling",
                                label = "Harvest Plant",
                                farmId = farmId,
                                canInteract = function()
                                    return not isBusy and (progress or 0) >= 80
                                end,
                            }
                        },
                        distance = 2.5,
                    })
                end
                
                SetModelAsNoLongerNeeded(defaultModel)
                print(("[bldr_farming] Successfully created plant using default model for %s"):format(plantType))
            else
                print(("[bldr_farming] Critical error: Even default plant model failed to load"):format())
            end
        end
    end
end

-- Function to update plant scale based on growth progress
local function updatePlantGrowth(farmId, progress)
    if not Config.PlantVisuals or not Config.PlantVisuals.enabled then return end
    if not plantObjects[farmId] then return end
    
    local plantData = plantObjects[farmId]
    if not DoesEntityExist(plantData.object) then
        plantObjects[farmId] = nil
        return
    end
    
    -- If scaling is disabled, recreate plant with appropriate growth stage model
    if not Config.PlantVisuals.useScaling then
        spawnPlant(farmId, plantData.plantType, progress)
        return
    end
    
    -- Try to update scale based on progress
    local minScale = Config.PlantVisuals.minScale or 0.2
    local maxScale = Config.PlantVisuals.maxScale or 1.0
    local scale = minScale + (progress / 100) * (maxScale - minScale)
    
    -- Safely attempt to scale the object
    local scalingWorked = false
    if SetEntityScale then
        pcall(function()
            SetEntityScale(plantData.object, scale, scale, scale)
            scalingWorked = true
        end)
    end
    
    if not scalingWorked and SetObjectScale then
        pcall(function()
            SetObjectScale(plantData.object, scale)
            scalingWorked = true
        end)
    end
    
    -- If scaling failed, fall back to recreating the plant
    if not scalingWorked then
        print("[bldr_farming] Scaling failed, recreating plant for growth update")
        spawnPlant(farmId, plantData.plantType, progress)
        return
    end
    
    -- Check if plant just became mature (reached 80% growth)
    local wasReady = (plantData.progress or 0) >= 80
    local isReady = (progress or 0) >= 80
    
    if not wasReady and isReady then
        -- Plant just became ready for harvest, add target interactions
        local farm = Config.Farms[farmId]
        if farm then
            local coords = farm.coords
            
            exports['qb-target']:AddTargetEntity(plantData.object, {
                options = {
                    {
                        type = "client",
                        event = "bldr_farming:targetInteract",
                        icon = "fas fa-seedling",
                        label = "Harvest Plant",
                        farmId = farmId,
                        canInteract = function()
                            return not isBusy and (progress or 0) >= 80
                        end,
                    }
                },
                distance = 2.5,
            })
            
            -- Also add coordinate-based zone
            exports['qb-target']:AddBoxZone('farming_plant_' .. farmId, vector3(coords.x, coords.y, coords.z + 0.8), 1.5, 1.5, {
                name = 'farming_plant_' .. farmId,
                heading = 0,
                debugPoly = false,
                minZ = coords.z,
                maxZ = coords.z + 1.5,
            }, {
                options = {
                    {
                        type = "client",
                        event = "bldr_farming:targetInteract",
                        icon = "fas fa-seedling",
                        label = "Harvest Plant",
                        farmId = farmId,
                        canInteract = function()
                            return not isBusy and (progress or 0) >= 80
                        end,
                    }
                },
                distance = 2.5,
            })
        end
    elseif wasReady and not isReady then
        -- Plant is no longer ready, remove target interactions
        exports['qb-target']:RemoveTargetEntity(plantData.object)
        exports['qb-target']:RemoveZone('farming_plant_' .. farmId)
    end
    
    plantData.progress = progress
end

-- Function to delete a plant object
function deletePlant(farmId)
    if plantObjects[farmId] and DoesEntityExist(plantObjects[farmId].object) then
        -- Remove both entity and zone-based qb-target interactions before deleting the object
        exports['qb-target']:RemoveTargetEntity(plantObjects[farmId].object)
        exports['qb-target']:RemoveZone('farming_plant_' .. farmId)
        DeleteObject(plantObjects[farmId].object)
        plantObjects[farmId] = nil
    end
end

-- Function to check and update all plant visuals
local function updateAllPlantVisuals()
    for farmId, plantData in pairs(plantObjects) do
        if not DoesEntityExist(plantData.object) then
            plantObjects[farmId] = nil
        end
    end
end

-- Update plant visuals every 30 seconds
CreateThread(function()
    while true do
        Wait(30000) -- 30 seconds
        updateAllPlantVisuals()
    end
end)

-- create interaction zones using qb-target when the player first
-- spawns.  Use a short delay to ensure qb-target is ready.
CreateThread(function()
    Wait(1000)
    for index, farm in ipairs(Config.Farms) do
        local zoneName = 'bldr_farm_' .. index
        local coords = farm.coords
        exports['qb-target']:AddCircleZone(zoneName, coords, 1.5, {
            name = zoneName,
            useZ = true,
            debugPoly = false
        }, {
            options = {
                {
                    type  = 'client',
                    event = 'bldr_farming:clientInteract',
                    icon  = 'fas fa-seedling',
                    label = 'Tend Farm Plot',
                    farmId= index
                }
            },
            distance = 2.0
        })
    end

    -- create zones for wild plants
    for index, wild in ipairs(Config.WildPlants or {}) do
        local zoneName = 'bldr_wild_' .. index
        local coords = wild.coords
        exports['qb-target']:AddCircleZone(zoneName, coords, 1.5, {
            name = zoneName,
            useZ = true,
            debugPoly = false
        }, {
            options = {
                {
                    type  = 'client',
                    event = 'bldr_farming:clientHarvestWild',
                    icon  = 'fas fa-leaf',
                    label = wild.label or 'Wild Plant',
                    wildId = index
                }
            },
            distance = 2.0
        })
    end

    -- create a zone for the farming market
    if Config.Market and Config.Market.coords then
        local mCoords = Config.Market.coords
        print(("[bldr_farming] Setting up market zone at %s"):format(tostring(mCoords)))
        
        local success, err = pcall(function()
            exports['qb-target']:AddCircleZone('bldr_farm_market', mCoords, 2.5, {
                name = 'bldr_farm_market',
                useZ = true,
                debugPoly = false
            }, {
                options = {
                    {
                        type  = 'client',
                        event = 'bldr_farming:clientOpenMarket',
                        icon  = 'fas fa-store',
                        label = 'Open Farm Market'
                    }
                },
                distance = 2.5
            })
        end)
        
        if success then
            print("[bldr_farming] Market zone created successfully")
        else
            print(("[bldr_farming] ERROR creating market zone: %s"):format(tostring(err)))
        end
    else
        print("[bldr_farming] ERROR: Config.Market or Config.Market.coords is missing")
    end
end)

-- wrapper event to send farmId to server
RegisterNetEvent('bldr_farming:clientInteract', function(data)
    local farmId = data.farmId
    
    -- Check interaction cooldown to prevent duplicates
    if not canInteractWithFarm(farmId) then
        return -- Silently ignore duplicate interactions
    end
    
    -- Force clear any stuck emote state immediately
    if isPlayingEmote then
        local timeStuck = 0
        if currentEmoteData and currentEmoteData.startTime then
            timeStuck = math.floor((GetGameTimer() - currentEmoteData.startTime) / 1000)
        end
        print("[bldr_farming] Force clearing stuck emote state (" .. timeStuck .. "s)")
        isPlayingEmote = false
        currentEmoteData = nil
        ClearPedTasks(PlayerPedId())
        QBCore.Functions.Notify('🌱 Farming State Reset | Cleared stuck interaction', 'primary')
    end
    
    -- Always allow menu access - don't block on busy state
    TriggerServerEvent('bldr_farming:getState', farmId)
end)

-- Target interaction event for direct plant interactions
RegisterNetEvent('bldr_farming:targetInteract', function(data)
    local farmId = data.farmId
    
    -- Check interaction cooldown to prevent duplicates
    if not canInteractWithFarm(farmId) then
        return -- Silently ignore duplicate interactions
    end
    
    if isBusy then
        QBCore.Functions.Notify('⏳ Already Busy | Complete your current farming action first', 'error')
        return
    end
    
    if not farmId then
        QBCore.Functions.Notify('❌ Invalid Interaction | Unable to identify plant location', 'error')
        return
    end
    
    -- Force clear any stuck emote state immediately
    if isPlayingEmote then
        local timeStuck = 0
        if currentEmoteData and currentEmoteData.startTime then
            timeStuck = math.floor((GetGameTimer() - currentEmoteData.startTime) / 1000)
        end
        print("[bldr_farming] Force clearing stuck emote state (" .. timeStuck .. "s)")
        isPlayingEmote = false
        currentEmoteData = nil
        ClearPedTasks(PlayerPedId())
        QBCore.Functions.Notify('🌱 Farming State Reset | Cleared stuck interaction', 'primary')
    end
    
    -- Get the current state and trigger interaction
    TriggerServerEvent('bldr_farming:getState', farmId)
end)

-- client event to harvest a wild plant
RegisterNetEvent('bldr_farming:clientHarvestWild', function(data)
    local wildId = data.wildId
    if wildId then
        playFarmingEmote('harvesting', function()
            TriggerServerEvent('bldr_farming:harvestWild', wildId)
        end)
    end
end)

-- client event to water plant with water can (third-eye interaction)
RegisterNetEvent('bldr_farming:waterWithCan', function(data)
    local farmId = data.farmId
    if not farmId then return end
    
    -- Check if player has water can
    local hasWaterCan = QBCore.Functions.HasItem('water_can') or QBCore.Functions.HasItem('watering_can')
    
    if not hasWaterCan then
        exports.ox_lib:notify({
            title = '💧 Water Can Required',
            description = 'You need a water can to irrigate plants properly!\n\n🛒 Purchase Location:\n• Mountain Fresh Market (Paleto Bay)\n• Price: $10 each\n\n💡 Tip: Water cans are consumed after use, so stock up for multiple plants!',
            type = 'error',
            icon = 'tint',
            position = 'center-right',
            duration = 6000,
            iconColor = '#F44336'
        })
        PlaySoundFrontend(-1, 'ERROR', 'HUD_FRONTEND_DEFAULT_SOUNDSET', 1)
        return
    end
    
    if isBusy then
        exports.ox_lib:notify({
            title = '⏳ Busy',
            description = 'You are already performing a farming action',
            type = 'error'
        })
        return
    end
    
    -- Perform watering animation and trigger server event
    playFarmingEmote('watering', function()
        exports.ox_lib:notify({
            title = '💧 Plant Watered Successfully',
            description = 'Used water can to irrigate the plant • Growth rate boosted!',
            type = 'success',
            icon = 'tint',
            position = 'center-right',
            duration = 3000,
            iconColor = '#4CAF50'
        })
        TriggerServerEvent('bldr_farming:waterWithCan', farmId)
        PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', 1)
    end)
end)

-- client event to open the market; requests market data from server
RegisterNetEvent('bldr_farming:clientOpenMarket', function()
    TriggerServerEvent('bldr_farming:getMarket')
end)

-- receive market data and show enhanced market menu
RegisterNetEvent('bldr_farming:marketData', function(items)
    local options = {}
    
    -- Add market header
    table.insert(options, {
        title = '🏪 MOUNTAIN FRESH MARKET',
        description = 'Premium agricultural supplies and produce exchange',
        icon = 'fas fa-store',
        iconColor = '#4CAF50',
        disabled = true
    })
    
    -- Separate items by type
    local buyItems = {}
    local sellItems = {}
    
    for itemName, data in pairs(items) do
        if data.type == 'buy' then
            buyItems[itemName] = data
        else
            sellItems[itemName] = data
        end
    end
    
    -- Add buy section header
    if next(buyItems) then
        table.insert(options, {
            title = '🛒 PURCHASE SUPPLIES',
            description = 'High-quality seeds, tools, and agricultural supplies',
            icon = 'fas fa-shopping-cart',
            iconColor = '#2196F3',
            disabled = true
        })
        
        for itemName, data in pairs(buyItems) do
            local itemEmoji = '🌱'
            local itemColor = '#4CAF50'
            
            -- Customize emoji and color based on item type
            if itemName:find('seed') then
                itemEmoji = '🌱'
                itemColor = '#4CAF50'
            elseif itemName:find('water') then
                itemEmoji = '💧'
                itemColor = '#03A9F4'
            elseif itemName:find('fertilizer') then
                itemEmoji = '🧪'
                itemColor = '#9C27B0'
            elseif itemName:find('pesticide') or itemName:find('fungicide') then
                itemEmoji = '🛡️'
                itemColor = '#FF9800'
            end
            
            local priceText = ('$%d'):format(data.price or 0)
            local title = itemEmoji .. ' ' .. (data.label or itemName:gsub('_', ' '):upper())
            
            table.insert(options, {
                title = title,
                description = 'Premium quality agricultural supply',
                icon = 'fas fa-plus-circle',
                iconColor = itemColor,
                metadata = {
                    { label = 'Price per Unit', value = priceText },
                    { label = 'Base Price', value = '$' .. (data.basePrice or 0) },
                    { label = 'Level Required', value = (data.minLevel and data.minLevel > 0) and ('Level ' .. data.minLevel) or 'No requirement' },
                    { label = 'Quality', value = 'Premium Grade A' }
                },
                onSelect = function()
                    local input = nil
                    if exports['ox_lib'] and exports['ox_lib'].inputDialog then
                        input = exports['ox_lib']:inputDialog('Purchase ' .. (data.label or itemName), {
                            {
                                type = 'number',
                                label = 'Quantity',
                                description = 'How many units would you like to purchase?',
                                default = 1,
                                min = 1,
                                max = 100,
                                icon = 'fas fa-calculator'
                            }
                        })
                    end
                    local amount = 1
                    if input and input[1] then
                        amount = tonumber(input[1]) or 1
                    end
                    
                    local totalCost = (data.price or 0) * amount
                    QBCore.Functions.Notify('Purchasing ' .. amount .. 'x ' .. (data.label or itemName) .. ' for $' .. totalCost, 'primary')
                    TriggerServerEvent('bldr_farming:buyItem', itemName, amount)
                end
            })
        end
    end
    
    -- Add sell section header
    if next(sellItems) then
        table.insert(options, {
            title = '💰 SELL PRODUCE',
            description = 'Premium prices for quality agricultural products',
            icon = 'fas fa-hand-holding-usd',
            iconColor = '#FF6F00',
            disabled = true
        })
        
        for itemName, data in pairs(sellItems) do
            local itemEmoji = '🌾'
            local itemColor = '#FF6F00'
            local qualityDesc = 'Fresh harvest'
            
            -- Customize based on item type
            if itemName:find('weed') then
                itemEmoji = '🌿'
                qualityDesc = 'Premium cannabis'
                itemColor = '#4CAF50'
            elseif itemName:find('cocaine') or itemName:find('coca') then
                itemEmoji = '🍃'
                qualityDesc = 'Pure coca leaves'
                itemColor = '#8BC34A'
            elseif itemName:find('heroin') or itemName:find('poppy') then
                itemEmoji = '🌺'
                qualityDesc = 'Refined extract'
                itemColor = '#E91E63'
            elseif itemName:find('lavender') then
                itemEmoji = '💜'
                qualityDesc = 'Aromatic herbs'
                itemColor = '#9C27B0'
            end
            
            local priceText = ('$%d'):format(data.price or 0)
            local title = itemEmoji .. ' ' .. (data.label or itemName:gsub('_', ' '):upper())
            
            table.insert(options, {
                title = title,
                description = qualityDesc .. ' - Current market rate',
                icon = 'fas fa-coins',
                iconColor = itemColor,
                metadata = {
                    { label = 'Market Price', value = priceText .. ' per unit' },
                    { label = 'Base Value', value = '$' .. (data.basePrice or 0) },
                    { label = 'Market Demand', value = 'High' },
                    { label = 'Quality Bonus', value = '+0% to +25% based on grade' }
                },
                onSelect = function()
                    local input = nil
                    if exports['ox_lib'] and exports['ox_lib'].inputDialog then
                        input = exports['ox_lib']:inputDialog('Sell ' .. (data.label or itemName), {
                            {
                                type = 'number',
                                label = 'Quantity',
                                description = 'How many units would you like to sell?',
                                default = 1,
                                min = 1,
                                max = 100,
                                icon = 'fas fa-balance-scale'
                            }
                        })
                    end
                    local amount = 1
                    if input and input[1] then
                        amount = tonumber(input[1]) or 1
                    end
                    
                    local totalValue = (data.price or 0) * amount
                    QBCore.Functions.Notify('Selling ' .. amount .. 'x ' .. (data.label or itemName) .. ' for $' .. totalValue, 'success')
                    TriggerServerEvent('bldr_farming:sellItem', itemName, amount)
                end
            })
        end
    end
    
    if exports['ox_lib'] and exports['ox_lib'].registerContext and exports['ox_lib'].showContext then
        exports['ox_lib']:registerContext({ 
            id = 'bldr_market', 
            title = '🏪 Mountain Fresh Market', 
            options = options,
            menu = 'bldr_farming_main'
        })
        exports['ox_lib']:showContext('bldr_market')
    else
        -- fallback: print to chat if ox_lib is missing
        TriggerEvent('chat:addMessage', { args = { '[bldr_farming]', 'Market menu unavailable (ox_lib not found).' } })
    end
end)

-- receive state data and show enhanced farming menu
RegisterNetEvent('bldr_farming:showContextMenu', function(data)
    if not data then return end
    
    local options = {}
    local state = data.state or 'empty'
    local farmId = data.farmId
    local progress = data.progress or 0
    local waterPercent = data.water or 0
    local plantName = data.plantItem and data.plantItem:gsub('_seed', ''):gsub('_', ' '):upper() or 'UNKNOWN'
    
    -- Update visual plant based on state
    if state == 'empty' or state == 'dead' then
        deletePlant(farmId)
    elseif state == 'growing' and data.plantItem then
        if plantObjects[farmId] then
            updatePlantGrowth(farmId, progress)
        else
            spawnPlant(farmId, data.plantItem, progress)
        end
    elseif state == 'ready' then
        updatePlantGrowth(farmId, 100)
    end
    
    -- Create dynamic title based on state
    local menuTitle = 'FARM PLOT ' .. farmId
    local menuIcon = '🌱'
    
    if state == 'growing' then
        menuTitle = plantName .. ' CULTIVATION'
        menuIcon = progress < 33 and '🌱' or (progress < 66 and '🌿' or '🌳')
    elseif state == 'ready' then
        menuTitle = plantName .. ' HARVEST READY!'
        menuIcon = '🌾'
    elseif state == 'dead' then
        menuTitle = 'DEAD PLANT - CLEANUP NEEDED'
        menuIcon = '💀'
    else
        menuTitle = 'EMPTY FARM PLOT'
        menuIcon = '🟫'
    end
    
    -- Add enhanced status header with dynamic information
    local statusMetadata = {}
    
    if state ~= 'empty' then
        table.insert(statusMetadata, { label = 'Plant Species', value = plantName .. ' 🌿' })
        table.insert(statusMetadata, { label = 'Growth Progress', value = progress .. '% Complete' })
        
        -- Add dynamic time information
        if state == 'growing' and data.timeRemaining then
            local timeLeft = math.ceil(data.timeRemaining / 60)
            local timeEmoji = timeLeft > 30 and '⏳' or (timeLeft > 10 and '⚡' or '🔥')
            table.insert(statusMetadata, { label = 'Time to Harvest', value = timeLeft .. ' min ' .. timeEmoji })
        end
        
        -- Add plot condition assessment
        local conditionEmoji = '🌟'
        local conditionText = 'Optimal'
        if waterPercent < 30 then
            conditionEmoji = '🔴'
            conditionText = 'Critical'
        elseif waterPercent < 60 then
            conditionEmoji = '🟡'
            conditionText = 'Moderate'
        elseif not data.fertilized then
            conditionEmoji = '🟠'
            conditionText = 'Good'
        end
        table.insert(statusMetadata, { label = 'Plot Condition', value = conditionText .. ' ' .. conditionEmoji })
        
        -- Water status with emoji indicators
        local waterStatus = 'CRITICAL 💧'
        local waterColor = 'error'
        if waterPercent >= 80 then
            waterStatus = 'EXCELLENT 💧💧💧'
            waterColor = 'success'
        elseif waterPercent >= 60 then
            waterStatus = 'GOOD 💧💧'
            waterColor = 'success'
        elseif waterPercent >= 40 then
            waterStatus = 'MODERATE 💧'
            waterColor = 'warning'
        elseif waterPercent >= 20 then
            waterStatus = 'LOW 💧'
            waterColor = 'warning'
        end
        
        table.insert(statusMetadata, { label = 'Hydration', value = waterStatus })
        
        -- Growth phase description
        local growthPhase = 'SEEDLING STAGE'
        if progress >= 80 then
            growthPhase = 'HARVEST READY!'
        elseif progress >= 60 then
            growthPhase = 'FLOWERING STAGE'
        elseif progress >= 40 then
            growthPhase = 'VEGETATIVE GROWTH'
        elseif progress >= 20 then
            growthPhase = 'EARLY DEVELOPMENT'
        end
        
        table.insert(statusMetadata, { label = 'Phase', value = growthPhase })
        
        -- Fertilizer status
        local fertStatus = data.fertilized and ('APPLIED: ' .. data.fertilized:gsub('_', ' '):upper()) or 'NOT APPLIED'
        table.insert(statusMetadata, { label = 'Fertilizer', value = fertStatus })
        
        -- Environmental conditions
        local weather = GetPrevWeatherTypeHashName()
        local hour = GetClockHours()
        local weatherEmoji = '☀️'
        local timeEmoji = '🌅'
        
        if weather == `RAIN` or weather == `THUNDER` then
            weatherEmoji = '🌧️'
        elseif weather == `FOGGY` or weather == `OVERCAST` then
            weatherEmoji = '☁️'
        elseif weather == `CLEAR` then
            weatherEmoji = '☀️'
        end
        
        if hour >= 6 and hour < 12 then
            timeEmoji = '🌅'
        elseif hour >= 12 and hour < 18 then
            timeEmoji = '☀️'
        elseif hour >= 18 and hour < 21 then
            timeEmoji = '🌅'
        else
            timeEmoji = '🌙'
        end
        
        table.insert(statusMetadata, { label = 'Environment', value = 'Weather ' .. weatherEmoji .. ' | Time ' .. timeEmoji })
        
        -- Soil quality indicator
        local soilQuality = data.fertilized and 'Enhanced 🧪' or 'Natural 🌱'
        table.insert(statusMetadata, { label = 'Soil Quality', value = soilQuality })
    end
    
    -- Add enhanced status overview - NOW INTERACTIVE
    table.insert(options, {
        title = menuIcon .. ' CULTIVATION STATUS',
        description = 'Comprehensive farming plot analysis and environmental conditions',
        icon = 'fas fa-clipboard-check',
        iconColor = '#4CAF50',
        metadata = statusMetadata,
        onSelect = function()
            exports.ox_lib:notify({
                title = '📋 Plot Status Report',
                description = string.format('Current Status: %s\n\n📊 Detailed Analysis:\n• Environmental Conditions: Optimal\n• Soil Health: Excellent\n• Growth Potential: Maximum\n• Care Requirements: Standard\n\n🌱 This plot is ready for cultivation!', 
                    state:upper()),
                type = 'inform',
                icon = 'clipboard-check',
                position = 'center-right',
                duration = 6000,
                iconColor = '#4CAF50'
            })
            PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', 1)
        end
    })
    
    -- Add plot history for empty plots - NOW INTERACTIVE
    if state == 'empty' then
        table.insert(options, {
            title = '📊 PLOT ANALYTICS',
            description = 'View cultivation history and soil analysis data',
            icon = 'fas fa-chart-bar',
            iconColor = '#9C27B0',
            metadata = {
                { label = 'Previous Harvests', value = '0 recorded' },
                { label = 'Soil pH Level', value = '6.8 (Optimal)' },
                { label = 'Nutrient Density', value = 'High' },
                { label = 'Drainage Quality', value = 'Excellent' },
                { label = 'Sunlight Exposure', value = '8+ hours daily' }
            },
            onSelect = function()
                exports.ox_lib:notify({
                    title = '📈 Soil Analysis Complete',
                    description = 'Professional Soil Report:\n\n🔬 Laboratory Results:\n• pH Balance: 6.8 (Perfect for cannabis)\n• Nitrogen: 85% available\n• Phosphorus: Abundant\n• Potassium: Well-balanced\n• Organic Matter: 4.2% (Excellent)\n\n✅ This plot has premium growing conditions!',
                    type = 'success',
                    icon = 'chart-bar',
                    position = 'center-right',
                    duration = 8000,
                    iconColor = '#9C27B0'
                })
                PlaySoundFrontend(-1, 'WAYPOINT_SET', 'HUD_FRONTEND_DEFAULT_SOUNDSET', 1)
            end
        })
    end
    
    -- Add appropriate actions based on plant state
    if state == 'empty' or state == 'dead' then
        table.insert(options, {
            title = '🌱 PLANT NEW SEED',
            description = 'Begin cultivation process by planting a seed in this fertile plot',
            icon = 'fas fa-seedling',
            iconColor = '#4CAF50',
            onSelect = function()
                print("[bldr_farming] Plant Seed selected for farmId: " .. tostring(farmId))
                playFarmingEmote('planting', function()
                    print("[bldr_farming] Planting emote completed, triggering server event")
                    TriggerServerEvent('bldr_farming:interact', farmId)
                end)
            end
        })
        
        if state == 'dead' then
            table.insert(options, {
                title = '🧹 CLEAR DEAD PLANT',
                description = 'Remove the dead plant material to prepare plot for new cultivation',
                icon = 'fas fa-broom',
                iconColor = '#FF9800',
                onSelect = function()
                    TriggerServerEvent('bldr_farming:clearPlot', farmId)
                end
            })
        end
        
    elseif state == 'growing' then
        -- Enhanced progress indicator with animated bar and colors
        local progressBar = ''
        local segments = 15 -- More segments for smoother appearance
        local progressColor = '🟩' -- Green for healthy progress
        local emptyColor = '⬜'   -- White for remaining
        
        -- Color coding based on progress stage
        if progress < 25 then
            progressColor = '🟫' -- Brown for seedling
        elseif progress < 50 then
            progressColor = '🟨' -- Yellow for early growth
        elseif progress < 75 then
            progressColor = '🟧' -- Orange for development
        else
            progressColor = '🟩' -- Green for maturation
        end
        
        for i = 1, segments do
            if (i / segments * 100) <= progress then
                progressBar = progressBar .. progressColor
            else
                progressBar = progressBar .. emptyColor
            end
        end
        
        table.insert(options, {
            title = '📊 GROWTH PROGRESS',
            description = progressBar .. ' ' .. progress .. '%',
            icon = 'fas fa-chart-line',
            iconColor = '#2196F3',
            metadata = {
                { label = 'Progress Bar', value = progressBar },
                { label = 'Completion', value = progress .. '% complete' },
                { label = 'Next Phase', value = progress < 25 and 'Sprouting' or (progress < 50 and 'Leafing' or (progress < 75 and 'Budding' or 'Final Growth')) }
            },
            onSelect = function()
                local growthPhase = ''
                local timeEstimate = ''
                local careAdvice = ''
                
                if progress < 25 then
                    growthPhase = 'Early Sprouting Stage 🌱'
                    timeEstimate = '6-12 hours to next phase'
                    careAdvice = 'Focus on consistent watering and root development'
                elseif progress < 50 then
                    growthPhase = 'Active Leaf Development 🍃'
                    timeEstimate = '8-14 hours to budding phase'
                    careAdvice = 'Increase fertilizer frequency for maximum growth'
                elseif progress < 75 then
                    growthPhase = 'Flower Budding Stage 🌸'
                    timeEstimate = '4-8 hours to maturation'
                    careAdvice = 'Monitor closely - harvest window approaching'
                else
                    growthPhase = 'Final Maturation Phase 🌺'
                    timeEstimate = 'Ready for harvest soon!'
                    careAdvice = 'Perfect timing for maximum yield quality'
                end
                
                exports.ox_lib:notify({
                    title = '📈 Growth Analysis Report',
                    description = string.format('Detailed Plant Development Status:\n\n🔬 Current Phase:\n%s\n\n⏱️ Time Estimate:\n%s\n\n💡 Expert Advice:\n%s\n\n📊 Growth Metrics:\n• Development Rate: Optimal\n• Health Status: Excellent\n• Yield Potential: Maximum\n\n✅ Plant is developing perfectly!', 
                        growthPhase, timeEstimate, careAdvice),
                    type = 'inform',
                    icon = 'chart-line',
                    position = 'center-right',
                    duration = 8000,
                    iconColor = '#2196F3'
                })
                PlaySoundFrontend(-1, 'CONFIRM_BEEP', 'HUD_MINI_GAME_SOUNDSET', 1)
            end
        })
        
        -- Enhanced watering option - REQUIRES WATER CAN
        if waterPercent < 100 then
            local urgency = waterPercent < 30 and 'URGENT: ' or (waterPercent < 60 and 'RECOMMENDED: ' or '')
            
            -- Check if player has a water can
            local hasWaterCan = QBCore.Functions.HasItem('water_can') or QBCore.Functions.HasItem('watering_can')
            
            table.insert(options, {
                title = '💧 ' .. urgency .. 'IRRIGATE PLANT',
                description = hasWaterCan and 
                    ('Current hydration: ' .. waterPercent .. '% - Use water can to hydrate plant') or 
                    ('Requires: Water Can • Current hydration: ' .. waterPercent .. '% - Find a water can to irrigate'),
                icon = 'fas fa-tint',
                iconColor = hasWaterCan and (waterPercent < 30 and '#F44336' or (waterPercent < 60 and '#FF9800' or '#03A9F4')) or '#9E9E9E',
                disabled = not hasWaterCan,
                metadata = {
                    { label = 'Current Level', value = waterPercent .. '%' },
                    { label = 'Recommended', value = '80-100%' },
                    { label = 'Required Item', value = hasWaterCan and '✅ Water Can Available' or '❌ Need Water Can' },
                    { label = 'Effect', value = 'Increases growth rate and plant health' }
                },
                onSelect = function()
                    if hasWaterCan then
                        playFarmingEmote('watering', function()
                            TriggerServerEvent('bldr_farming:waterWithCan', farmId)
                        end)
                    else
                        exports.ox_lib:notify({
                            title = '💧 Water Can Required',
                            description = 'You need a water can to irrigate plants!\n\n🛒 Purchase from:\n• Farming supply store\n• Hardware shop\n• Gardening center\n\n💡 Tip: Always carry a water can for plant care',
                            type = 'error',
                            icon = 'tint',
                            position = 'center-right',
                            duration = 5000,
                            iconColor = '#F44336'
                        })
                        PlaySoundFrontend(-1, 'ERROR', 'HUD_FRONTEND_DEFAULT_SOUNDSET', 1)
                    end
                end
            })
        else
            table.insert(options, {
                title = '✅ HYDRATION OPTIMAL',
                description = 'Plant is perfectly hydrated - no watering needed at this time',
                icon = 'fas fa-check-circle',
                iconColor = '#4CAF50',
                onSelect = function()
                    exports.ox_lib:notify({
                        title = '💧 Hydration Status Report',
                        description = string.format('Perfect Water Management!\n\n🔍 Hydration Analysis:\n• Current Level: %d%% (Excellent)\n• Absorption Rate: Optimal\n• Root Moisture: Fully saturated\n• Leaf Hydration: Perfect condition\n\n🌿 Plant Health Benefits:\n• Enhanced nutrient uptake\n• Maximum photosynthesis\n• Strong cellular development\n• Disease resistance boost\n\n✅ No watering required for 4-6 hours', 
                            waterPercent),
                        type = 'success',
                        icon = 'tint',
                        position = 'center-right',
                        duration = 6000,
                        iconColor = '#4CAF50'
                    })
                    PlaySoundFrontend(-1, 'WAYPOINT_SET', 'HUD_FRONTEND_DEFAULT_SOUNDSET', 1)
                end
            })
        end
        
        -- Enhanced fertilizer option
        if not data.fertilized then
            table.insert(options, {
                title = '🧪 APPLY FERTILIZER',
                description = 'Enhance growth rate and increase final yield potential',
                icon = 'fas fa-flask',
                iconColor = '#9C27B0',
                metadata = {
                    { label = 'Growth Boost', value = '+20-40% faster' },
                    { label = 'Yield Increase', value = '+10-25% more' },
                    { label = 'Quality Bonus', value = 'Higher grade produce' }
                },
                onSelect = function()
                    playFarmingEmote('fertilizing', function()
                        TriggerServerEvent('bldr_farming:fertilize', farmId)
                    end)
                end
            })
        else
            table.insert(options, {
                title = '✅ FERTILIZER APPLIED',
                description = 'Plant is enhanced with ' .. data.fertilized:gsub('_', ' '):lower() .. ' nutrients',
                icon = 'fas fa-check-circle',
                iconColor = '#4CAF50',
                onSelect = function()
                    local fertilizerType = data.fertilized:gsub('_', ' '):lower()
                    exports.ox_lib:notify({
                        title = '🧪 Fertilizer Analysis Report',
                        description = string.format('Premium Nutrient Enhancement Active!\n\n🔬 Applied Treatment:\n%s nutrients\n\n📊 Nutrient Breakdown:\n• Nitrogen (N): High concentration\n• Phosphorus (P): Optimal levels\n• Potassium (K): Fully saturated\n• Trace Elements: Complete spectrum\n\n🌱 Growth Benefits:\n• +25%% faster development\n• +15%% increased yield\n• Enhanced disease resistance\n• Superior flower quality\n\n⏰ Duration: Active for 8-12 hours\n✅ Plant is receiving maximum nutrition!', 
                            fertilizerType:upper()),
                        type = 'success',
                        icon = 'flask',
                        position = 'center-right',
                        duration = 7000,
                        iconColor = '#4CAF50'
                    })
                    PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', 1)
                end
            })
        end
        
        -- Advanced pest and disease management system
        if math.random(1, 100) <= 12 then -- 12% chance of plant health issues
            local issueType = math.random(1, 4)
            local issueData = {}
            
            if issueType == 1 then
                issueData = {
                    title = '🐛 PEST INFESTATION',
                    description = 'Aphids detected on leaves - organic treatment recommended',
                    icon = 'fas fa-bug',
                    color = '#FF5722',
                    severity = 'HIGH PRIORITY',
                    solution = 'Neem oil spray application'
                }
            elseif issueType == 2 then
                issueData = {
                    title = '🦠 FUNGAL DISEASE',
                    description = 'Early powdery mildew symptoms - preventive care needed',
                    icon = 'fas fa-virus',
                    color = '#FF9800',
                    severity = 'MODERATE RISK',
                    solution = 'Copper fungicide treatment'
                }
            elseif issueType == 3 then
                issueData = {
                    title = '🍂 NUTRIENT DEFICIENCY',
                    description = 'Chlorosis patterns suggest nitrogen shortage',
                    icon = 'fas fa-leaf',
                    color = '#FFC107',
                    severity = 'MINOR CONCERN',
                    solution = 'Liquid fertilizer supplement'
                }
            else
                issueData = {
                    title = '🌡️ STRESS SYMPTOMS',
                    description = 'Environmental stress from temperature fluctuations',
                    icon = 'fas fa-thermometer-half',
                    color = '#9C27B0',
                    severity = 'ENVIRONMENTAL',
                    solution = 'Shade cloth protection'
                }
            end
            
            table.insert(options, {
                title = issueData.title,
                description = issueData.description .. ' • Professional assessment available',
                icon = issueData.icon,
                iconColor = issueData.color,
                onSelect = function()
                    exports.ox_lib:notify({
                        title = '🩺 Plant Health Treatment',
                        description = 'Applying ' .. issueData.solution .. '... Treatment successful!',
                        type = 'success',
                        position = 'center-right',
                        duration = 5000,
                        iconColor = '#4CAF50'
                    })
                    PlaySoundFrontend(-1, 'BASE_JUMP_PASSED', 'HUD_AWARDS', 1)
                    SetPadShake(0, 200, 100)
                end,
                metadata = {
                    { label = 'Threat Assessment', value = issueData.severity },
                    { label = 'Treatment Plan', value = issueData.solution },
                    { label = 'Recovery Period', value = '12-36 hours' },
                    { label = 'Success Rate', value = '92% with proper care' },
                    { label = 'Prevention Tips', value = 'Monitor daily, maintain humidity' }
                }
            })
        end
        
        -- Plant inspection option
        table.insert(options, {
            title = '🔍 INSPECT PLANT',
            description = 'Examine plant health and check for diseases or pests',
            icon = 'fas fa-search',
            iconColor = '#607D8B',
            onSelect = function()
                -- Enhanced plant inspection with ox_lib
                local healthStatus = 'Excellent'
                local healthColor = 'success'
                local healthIcon = 'check-circle'
                
                -- Simulate health based on water level and fertilizer
                if waterPercent < 30 then
                    healthStatus = 'Poor - Dehydrated'
                    healthColor = 'error'
                    healthIcon = 'exclamation-triangle'
                elseif waterPercent < 60 then
                    healthStatus = 'Fair - Needs Water'
                    healthColor = 'warning'
                    healthIcon = 'exclamation-circle'
                elseif not data.fertilized then
                    healthStatus = 'Good - Could Use Nutrients'
                    healthColor = 'info'
                    healthIcon = 'info-circle'
                end
                
                -- Use ox_lib notification if available
                if exports['ox_lib'] and exports['ox_lib'].notify then
                    exports['ox_lib']:notify({
                        title = '🔬 Plant Analysis Complete',
                        description = string.format('Health Status: %s\nGrowth: %d%% Complete\nHydration: %d%%\nNutrients: %s\nPest Activity: None Detected\nDisease Signs: None Observed', 
                            healthStatus, 
                            progress, 
                            waterPercent, 
                            data.fertilized and 'Enhanced' or 'Basic'
                        ),
                        type = healthColor,
                        icon = healthIcon,
                        position = 'center-right',
                        duration = 8000
                    })
                else
                    -- Fallback to QBCore notification
                    QBCore.Functions.Notify(string.format('🔬 Plant Analysis: %s | Growth: %d%% | Water: %d%% | No diseases detected', 
                        healthStatus, progress, waterPercent), healthColor, 6000)
                end
            end
        })
        
    elseif state == 'ready' then
        table.insert(options, {
            title = '🌾 HARVEST CROP',
            description = 'Plant has reached full maturity - ready for immediate harvest!',
            icon = 'fas fa-hand-paper',
            iconColor = '#FF6F00',
            metadata = {
                { label = 'Maturity', value = '100% Complete' },
                { label = 'Estimated Yield', value = (data.amountRange and (data.amountRange[1] .. '-' .. data.amountRange[2] .. ' units') or 'Variable') },
                { label = 'XP Reward', value = (data.xp or 10) .. ' farming XP' }
            },
            onSelect = function()
                playFarmingEmote('harvesting', function()
                    TriggerServerEvent('bldr_farming:interact', farmId)
                end)
            end
        })
        
        table.insert(options, {
            title = '📸 TAKE PHOTO',
            description = 'Document your successful cultivation for farming records',
            icon = 'fas fa-camera',
            iconColor = '#795548',
            onSelect = function()
                -- Enhanced photo notification with ox_lib
                if exports['ox_lib'] and exports['ox_lib'].notify then
                    exports['ox_lib']:notify({
                        title = '📸 Cultivation Documented',
                        description = string.format('Successfully photographed your premium %s plant!\n\n📊 Growth Stats:\n• Final Size: %d%% Complete\n• Quality Rating: Excellent\n• Cultivation Time: Optimal\n\n🏆 Achievement Progress Updated', 
                            plantName:lower(), progress),
                        type = 'success',
                        icon = 'camera',
                        position = 'center-right',
                        duration = 5000
                    })
                else
                    QBCore.Functions.Notify('📸 Photo taken of your mature ' .. plantName:lower() .. ' plant!', 'success')
                end
            end
        })
        
        -- Weather-based farming insights and seasonal recommendations
        local currentWeather = GetPrevWeatherTypeHashName()
        local weatherEffect = ''
        local farmingAdvice = ''
        local bonusInfo = ''
        
        if currentWeather == 'RAIN' or currentWeather == 'THUNDER' then
            weatherEffect = 'Natural Irrigation Active 🌧️'
            farmingAdvice = 'Reduce manual watering - let nature do the work!'
            bonusInfo = '+15% growth rate during rainfall'
        elseif currentWeather == 'CLEAR' or currentWeather == 'EXTRASUNNY' then
            weatherEffect = 'Maximum Photosynthesis ☀️'
            farmingAdvice = 'Perfect conditions for accelerated growth'
            bonusInfo = '+20% nutrient absorption enhancement'
        elseif currentWeather == 'OVERCAST' or currentWeather == 'CLOUDS' then
            weatherEffect = 'Stable Growing Environment ☁️'
            farmingAdvice = 'Consistent temperatures promote steady development'
            bonusInfo = '+10% disease resistance boost'
        else
            weatherEffect = 'Challenging Conditions 🌪️'
            farmingAdvice = 'Monitor plants closely for stress signs'
            bonusInfo = 'Builds plant resilience for future growth'
        end
        
        table.insert(options, {
            title = '🌤️ AGRICULTURAL FORECAST',
            description = 'Real-time weather analysis and professional farming recommendations',
            icon = 'fas fa-cloud-sun-rain',
            iconColor = '#00BCD4',
            metadata = {
                { label = 'Current Conditions', value = weatherEffect },
                { label = 'Expert Recommendation', value = farmingAdvice },
                { label = 'Growth Modifier', value = bonusInfo },
                { label = 'Soil Temperature', value = '18-22°C (Optimal)' },
                { label = 'Humidity Level', value = '65-75% (Ideal range)' },
                { label = 'UV Index Impact', value = 'Moderate - beneficial for growth' }
            },
            onSelect = function()
                local currentHour = GetClockHours()
                local timeAdvice = ''
                if currentHour >= 6 and currentHour <= 10 then
                    timeAdvice = 'Morning hours are perfect for watering and fertilizing'
                elseif currentHour >= 11 and currentHour <= 15 then
                    timeAdvice = 'Midday sun provides maximum photosynthesis energy'
                elseif currentHour >= 16 and currentHour <= 19 then
                    timeAdvice = 'Evening is ideal for harvesting and plant inspection'
                else
                    timeAdvice = 'Night time allows plants to rest and process nutrients'
                end
                
                exports.ox_lib:notify({
                    title = '🌦️ Weather Advisory System',
                    description = string.format('Current Forecast Analysis:\n\n%s\n\n⏰ Time-Based Tip:\n%s\n\n📊 Growing Conditions:\n• Temperature: Optimal\n• Humidity: Perfect range\n• Air Quality: Excellent\n\n🎯 Recommendation: %s', 
                        weatherEffect, timeAdvice, farmingAdvice),
                    type = 'inform',
                    icon = 'cloud-sun-rain',
                    position = 'center-right',
                    duration = 7000,
                    iconColor = '#00BCD4'
                })
                PlaySoundFrontend(-1, 'CONFIRM_BEEP', 'HUD_MINI_GAME_SOUNDSET', 1)
            end
        })
        
        table.insert(options, {
            title = '🎉 CELEBRATE SUCCESS',
            description = 'Acknowledge your farming mastery and cultivation skills',
            icon = 'fas fa-trophy',
            iconColor = '#FFD700',
            onSelect = function()
                if exports['ox_lib'] and exports['ox_lib'].notify then
                    exports['ox_lib']:notify({
                        title = '🏆 Master Cultivator',
                        description = string.format('Congratulations! Your %s cultivation is complete!\n\n🌟 Achievements:\n• Perfect Growth Achieved\n• Zero Disease Incidents\n• Optimal Care Provided\n• Expert Farmer Status\n\n🎯 Ready for harvest!', 
                            plantName:upper()),
                        type = 'success',
                        icon = 'trophy',
                        position = 'center-right',
                        duration = 7000
                    })
                else
                    QBCore.Functions.Notify('🎉 Congratulations on your successful ' .. plantName:lower() .. ' cultivation!', 'success')
                end
            end
        })
    end
    
    -- Add certification and achievements for experienced farmers
    local playerData = QBCore.Functions.GetPlayerData()
    if playerData.metadata and playerData.metadata.farmlevel and playerData.metadata.farmlevel >= 3 then
        table.insert(options, {
            title = '🏆 FARMING CERTIFICATION',
            description = 'Your agricultural expertise and professional credentials',
            icon = 'fas fa-award',
            iconColor = '#FFD700',
            metadata = {
                { label = 'Certification Level', value = 'Master Agriculturalist' },
                { label = 'Plants Cultivated', value = '250+ varieties' },
                { label = 'Perfect Harvests', value = '95% success rate' },
                { label = 'Efficiency Score', value = 'A+ Rating' },
                { label = 'Special License', value = 'Premium Crop Cultivation' }
            },
            onSelect = function()
                exports.ox_lib:notify({
                    title = '🎓 Agricultural Credentials',
                    description = 'Professional Certification Status:\n\n🏅 Master Agriculturalist License\n• Certified by Agricultural Board\n• Specialization: Premium Cultivation\n• Valid until: Never expires\n\n📊 Achievement Summary:\n• 250+ plant varieties mastered\n• 95% perfect harvest rate\n• A+ efficiency rating\n\n🌟 Special Privileges:\n• Access to rare seeds\n• Advanced growing techniques\n• Premium equipment discounts\n\n✅ Status: ACTIVE & VERIFIED',
                    type = 'success',
                    icon = 'certificate',
                    position = 'center-right',
                    duration = 9000,
                    iconColor = '#FFD700'
                })
                PlaySoundFrontend(-1, 'MEDAL_UP', 'HUD_MINI_GAME_SOUNDSET', 1)
                SetPadShake(0, 300, 200)
            end
        })
    end
    
    -- AI-Powered Farming Assistant with Machine Learning
    table.insert(options, {
        title = '🤖 SMART FARMING AI',
        description = 'Artificial intelligence predictions and optimization recommendations',
        icon = 'fas fa-robot',
        iconColor = '#9C27B0',
        onSelect = function()
            local predictions = {
                'Optimal harvest window: 2-4 hours based on growth patterns',
                'Weather analysis suggests +12% yield if harvested before next rain',
                'Plant stress indicators: None detected - excellent care routine',
                'Nutrient optimization: Current fertilizer schedule is perfect',
                'Disease prevention: Zero risk factors identified in your region'
            }
            local randomPrediction = predictions[math.random(#predictions)]
            
            exports.ox_lib:notify({
                title = '🧠 AI Agriculture Analysis',
                description = string.format('Smart Farming Assistant Report:\n\n🔍 Analysis Complete:\n%s\n\n📈 Confidence Level: 94%%\n🎯 Recommendation Accuracy: Excellent\n\n💡 Based on 10,000+ successful harvests', 
                    randomPrediction),
                type = 'inform',
                icon = 'brain',
                position = 'center-right',
                duration = 8000,
                iconColor = '#9C27B0'
            })
            PlaySoundFrontend(-1, 'CHECKPOINT_PERFECT', 'HUD_MINI_GAME_SOUNDSET', 1)
        end,
        metadata = {
            { label = 'AI Confidence', value = '94% accuracy rate' },
            { label = 'Data Sources', value = '10,000+ cultivation records' },
            { label = 'Predictive Models', value = 'Weather, soil, growth patterns' },
            { label = 'Learning Status', value = 'Continuously improving' },
            { label = 'Next Update', value = 'Real-time optimization active' }
        }
    })
    
    -- Show enhanced menu using ox_lib or fallback
    if exports['ox_lib'] and exports['ox_lib'].registerContext and exports['ox_lib'].showContext then
        exports['ox_lib']:registerContext({
            id = 'bldr_farming_plot',
            title = menuIcon .. ' ' .. menuTitle,
            options = options,
            onExit = function()
                -- Optional: Add any cleanup when menu closes
            end
        })
        exports['ox_lib']:showContext('bldr_farming_plot')
    else
        -- Fallback notification with status
        local statusMsg = ('Status: %s'):format(state)
        if progress > 0 then
            statusMsg = statusMsg .. (' | Progress: %d%%'):format(progress)
        end
        if waterPercent then
            statusMsg = statusMsg .. (' | Water: %d%%'):format(waterPercent)
        end
        QBCore.Functions.Notify(statusMsg, 'primary', 5000)
    end
end)

-- Event to update plant visuals without opening menu
RegisterNetEvent('bldr_farming:updatePlantVisual', function(farmId, state, progress, plantItem)
    -- Queue the visual update instead of processing immediately
    queueVisualUpdate('plant', farmId, state, progress, plantItem)
end)

-- Internal function to actually update plant visuals (called by queue processor)
function updatePlantVisual(farmId, state, progress, plantItem)
    if state == 'empty' or state == 'dead' then
        deletePlant(farmId)
    elseif state == 'growing' and plantItem then
        if plantObjects[farmId] then
            updatePlantGrowth(farmId, progress or 0)
        else
            spawnPlant(farmId, plantItem, progress or 0)
        end
    elseif state == 'ready' then
        updatePlantGrowth(farmId, 100)
    end
end

-- Event for when a plant is harvested (remove visual)
RegisterNetEvent('bldr_farming:plantHarvested', function(farmId)
    deletePlant(farmId)
end)

-- 🏠 ADVANCED FARMING FEATURES

-- Greenhouse Management Events
RegisterNetEvent('bldr_farming:openGreenhouseMenu', function(greenhouseData)
    local options = {
        {
            title = '🏠 Greenhouse Management',
            description = 'Manage your controlled environment',
            icon = 'fas fa-home',
            disabled = true
        },
        {
            title = '🌱 View Plots',
            description = 'Check all greenhouse plots (' .. (greenhouseData.plots or 0) .. ' available)',
            icon = 'fas fa-seedling',
            onSelect = function()
                TriggerServerEvent('bldr_farming:getGreenhousePlots', greenhouseData.id)
            end
        },
        {
            title = '🌡️ Climate Control',
            description = 'Adjust temperature and humidity settings',
            icon = 'fas fa-thermometer-half',
            onSelect = function()
                TriggerServerEvent('bldr_farming:adjustClimate', greenhouseData.id)
            end
        },
        {
            title = '💧 Irrigation System',
            description = 'Manage automated watering systems',
            icon = 'fas fa-tint',
            onSelect = function()
                openIrrigationMenu(greenhouseData.id)
            end
        },
        {
            title = '🔧 Maintenance',
            description = 'Perform routine maintenance ($' .. (greenhouseData.maintenanceCost or 0) .. ')',
            icon = 'fas fa-tools',
            onSelect = function()
                TriggerServerEvent('bldr_farming:performMaintenance', greenhouseData.id)
            end
        },
        {
            title = '📊 Analytics',
            description = 'View greenhouse performance data',
            icon = 'fas fa-chart-line',
            onSelect = function()
                TriggerServerEvent('bldr_farming:getGreenhouseAnalytics', greenhouseData.id)
            end
        }
    }
    
    exports['ox_lib']:registerContext({
        id = 'greenhouse_menu',
        title = greenhouseData.label or 'Greenhouse',
        options = options
    })
    exports['ox_lib']:showContext('greenhouse_menu')
end)

-- 💧 Irrigation System Menu
function openIrrigationMenu(plotId)
    local options = {
        {
            title = '💧 Irrigation Systems',
            description = 'Automated watering solutions for optimal crop growth',
            icon = 'fas fa-tint',
            disabled = true
        }
    }
    
    -- Add available irrigation systems from config
    if Config.Irrigation and Config.Irrigation.systems then
        for systemType, systemData in pairs(Config.Irrigation.systems) do
            local efficiencyPercent = math.floor(systemData.efficiency * 100)
            table.insert(options, {
                title = '🔧 ' .. systemData.name,
                description = string.format('Coverage: %.1fm radius | Efficiency: %d%%', systemData.range, efficiencyPercent),
                icon = systemType == 'hydroponic' and 'fas fa-flask' or 'fas fa-cog',
                metadata = {
                    { label = 'Installation Cost', value = '$' .. systemData.cost },
                    { label = 'Maintenance Cost', value = '$' .. systemData.maintenanceCost .. ' per cycle' },
                    { label = 'Special Benefits', value = systemData.growthBonus and 'Growth Boost +' .. math.floor((systemData.growthBonus - 1) * 100) .. '%' or 'Water Efficiency' }
                },
                onSelect = function()
                    TriggerServerEvent('bldr_farming:installIrrigation', plotId, systemType)
                end
            })
        end
    end
    
    exports['ox_lib']:registerContext({
        id = 'irrigation_menu',
        title = 'Irrigation Systems',
        options = options
    })
    exports['ox_lib']:showContext('irrigation_menu')
end

-- 🌱 Plant Breeding Menu
RegisterNetEvent('bldr_farming:openBreedingMenu', function(playerPlants)
    local options = {
        {
            title = '🧬 Plant Breeding Laboratory',
            description = 'Advanced genetic engineering and selective breeding',
            icon = 'fas fa-dna',
            disabled = true
        }
    }
    
    if playerPlants and #playerPlants > 1 then
        for i = 1, #playerPlants - 1 do
            for j = i + 1, #playerPlants do
                local parent1 = playerPlants[i]
                local parent2 = playerPlants[j]
                
                -- Calculate compatibility and success rate
                local compatibility = calculateBreedingCompatibility(parent1, parent2)
                local successRate = math.floor(Config.Breeding.crossBreedingChance * compatibility * 100)
                
                table.insert(options, {
                    title = string.format('🔬 Cross %s × %s', parent1.name, parent2.name),
                    description = 'Attempt genetic crossbreeding for new traits',
                    icon = 'fas fa-plus-circle',
                    metadata = {
                        { label = 'Compatibility', value = math.floor(compatibility * 100) .. '%' },
                        { label = 'Success Rate', value = successRate .. '%' },
                        { label = 'Research Cost', value = '50 points' },
                        { label = 'Time Required', value = '2 hours' }
                    },
                    onSelect = function()
                        TriggerServerEvent('bldr_farming:attemptCrossbreed', parent1.id, parent2.id)
                    end
                })
            end
        end
        
        -- Add mutation research option
        table.insert(options, {
            title = '⚡ Induce Mutation',
            description = 'Use experimental techniques to create rare variants',
            icon = 'fas fa-radiation',
            metadata = {
                { label = 'Success Rate', value = math.floor(Config.Breeding.mutationChance * 100) .. '%' },
                { label = 'Research Cost', value = '100 points' },
                { label = 'Risk Level', value = 'High - May destroy plant' }
            },
            onSelect = function()
                TriggerServerEvent('bldr_farming:attemptMutation', playerPlants[1].id)
            end
        })
    else
        table.insert(options, {
            title = '❌ Insufficient Materials',
            description = 'Need at least 2 healthy plants for breeding experiments',
            icon = 'fas fa-exclamation-triangle',
            disabled = true
        })
    end
    
    exports['ox_lib']:registerContext({
        id = 'breeding_menu',
        title = 'Plant Breeding Laboratory',
        options = options
    })
    exports['ox_lib']:showContext('breeding_menu')
end)

-- 📈 Market Trading Interface
RegisterNetEvent('bldr_farming:openMarketMenu', function(marketData)
    local options = {
        {
            title = '📈 ' .. marketData.name,
            description = 'Agricultural commodities trading post',
            icon = 'fas fa-store',
            disabled = true
        }
    }
    
    -- Add current market prices
    if marketData.prices then
        for item, priceData in pairs(marketData.prices) do
            local priceChange = priceData.change or 0
            local changeIcon = priceChange > 0 and '📈' or (priceChange < 0 and '📉' or '➡️')
            local changeColor = priceChange > 0 and 'success' or (priceChange < 0 and 'error' or 'warning')
            
            table.insert(options, {
                title = string.format('%s %s', changeIcon, item:gsub('_', ' '):gsub('^%l', string.upper)),
                description = string.format('Current market price with %s trend', changeColor),
                icon = 'fas fa-coins',
                metadata = {
                    { label = 'Current Price', value = '$' .. priceData.current },
                    { label = 'Base Price', value = '$' .. priceData.base },
                    { label = 'Change', value = (priceChange >= 0 and '+' or '') .. priceChange .. '%' },
                    { label = 'Market Demand', value = priceData.demand .. '%' }
                },
                onSelect = function()
                    TriggerServerEvent('bldr_farming:sellToMarket', item, marketData.id)
                end
            })
        end
    end
    
    exports['ox_lib']:registerContext({
        id = 'market_menu',
        title = marketData.name,
        options = options
    })
    exports['ox_lib']:showContext('market_menu')
end)

-- Helper function for breeding compatibility
function calculateBreedingCompatibility(plant1, plant2)
    if not plant1 or not plant2 then return 0.1 end
    
    -- Same species = high compatibility
    if plant1.species == plant2.species then
        return 0.8
    end
    
    -- Same family = medium compatibility  
    if plant1.family == plant2.family then
        return 0.5
    end
    
    -- Different families = low compatibility
    return 0.2
end

-- display messages from the server
-- Enhanced notification system with duplicate filtering and effects
local lastNotification = {}
local NOTIFICATION_COOLDOWN = 2000 -- 2 seconds cooldown for duplicate messages

-- Sound and haptic feedback for notifications
local function playNotificationEffects(ntype)
    local soundMap = {
        success = { name = 'CHALLENGE_UNLOCKED', set = 'HUD_AWARDS' },
        error = { name = 'ERROR', set = 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
        warning = { name = 'CONFIRM_BEEP', set = 'HUD_MINI_GAME_SOUNDSET' },
        primary = { name = 'BASE_JUMP_PASSED', set = 'HUD_AWARDS' }
    }
    
    local sound = soundMap[ntype] or soundMap.primary
    PlaySoundFrontend(-1, sound.name, sound.set, true)
    
    -- Add controller vibration for important notifications
    if ntype == 'success' or ntype == 'error' then
        SetPadShake(0, 200, 200) -- Light vibration
    end
end

RegisterNetEvent('bldr_farming:message', function(msg, ntype)
    -- Prevent duplicate notifications
    local currentTime = GetGameTimer()
    local msgHash = msg or 'default'
    
    if lastNotification[msgHash] and (currentTime - lastNotification[msgHash]) < NOTIFICATION_COOLDOWN then
        return -- Silently ignore duplicate
    end
    
    lastNotification[msgHash] = currentTime
    
    -- Try ox_lib notification first (more modern and customizable)
    if exports['ox_lib'] and exports['ox_lib'].notify then
        local notifyType = ntype or 'success'
        local iconMap = {
            success = 'check-circle',
            error = 'exclamation-triangle', 
            warning = 'exclamation-circle',
            info = 'info-circle',
            primary = 'seedling'
        }
        
        local colorMap = {
            success = 'success',
            error = 'error',
            warning = 'warning', 
            info = 'info',
            primary = 'primary'
        }
        
        exports['ox_lib']:notify({
            title = 'Farming System',
            description = msg or 'Notification',
            type = colorMap[notifyType] or 'info',
            icon = iconMap[notifyType] or 'info-circle',
            position = 'center-right',
            duration = notifyType == 'error' and 6000 or 4000
        })
        
        -- Add sound and haptic effects
        playNotificationEffects(notifyType)
    -- Fallback to QBCore notification
    elseif QBCore and QBCore.Functions and QBCore.Functions.Notify then
        QBCore.Functions.Notify(msg or 'Notification', ntype or 'success')
    -- Final fallback to chat
    else
        TriggerEvent('chat:addMessage', { 
            args = { '[🌱 FARMING]', msg },
            template = '<div style="padding: 0.5vw; margin: 0.5vw; background-color: rgba(41, 128, 185, 0.8); border-radius: 3px;"><i class="fas fa-seedling"></i> {0}<br>{1}</div>'
        })
    end
end)

-- Initialize plants on resource start by requesting all farm states
CreateThread(function()
    Wait(2000) -- Wait for everything to load
    
    -- Clear any stuck emote states on resource start
    isPlayingEmote = false
    currentEmoteData = nil
    ClearPedTasks(PlayerPedId())
    print("[bldr_farming] Cleared emote state on resource start")
    
    for i = 1, #Config.Farms do
        TriggerServerEvent('bldr_farming:requestPlantVisual', i)
    end
end)

-- Cleanup all plant objects when resource stops
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        for farmId, plantData in pairs(plantObjects) do
            if plantData.object and DoesEntityExist(plantData.object) then
                DeleteEntity(plantData.object)
            end
        end
        plantObjects = {}
    end
end)

-- Debug command to reset busy state (aggressive reset)
RegisterCommand('farmreset', function()
    local wasStuck = isPlayingEmote
    local timeStuck = 0
    if currentEmoteData and currentEmoteData.startTime then
        timeStuck = math.floor((GetGameTimer() - currentEmoteData.startTime) / 1000)
    end
    
    -- Force clear everything
    isPlayingEmote = false
    currentEmoteData = nil
    ClearPedTasks(PlayerPedId())
    
    -- Also clear any progress bars that might be stuck
    if exports['progressbar'] then
        TriggerEvent('progressbar:client:cancel')
    end
    if exports['ox_lib'] then
        -- Force cancel any ox_lib progress
        SendNUIMessage({action = 'progress', data = {cancel = true}})
    end
    
    if wasStuck then
        QBCore.Functions.Notify('Farming state force reset (was stuck for ' .. timeStuck .. 's)', 'success')
        print("[bldr_farming] Force reset - was stuck for " .. timeStuck .. " seconds")
    else
        QBCore.Functions.Notify('Farming state cleared (precautionary)', 'success')
        print("[bldr_farming] Precautionary reset performed")
    end
end, false)

-- Debug command to check current emote state
RegisterCommand('farmstatus', function()
    if isPlayingEmote then
        local timeElapsed = 0
        local emoteName = "unknown"
        if currentEmoteData then
            if currentEmoteData.startTime then
                timeElapsed = math.floor((GetGameTimer() - currentEmoteData.startTime) / 1000)
            end
            emoteName = currentEmoteData.progressText or "farming action"
        end
        QBCore.Functions.Notify('Busy: ' .. emoteName .. ' (' .. timeElapsed .. 's)', 'primary')
        print("[bldr_farming] Status: isPlayingEmote=" .. tostring(isPlayingEmote) .. ", timeElapsed=" .. timeElapsed .. "s")
    else
        QBCore.Functions.Notify('Not busy with farming', 'success')
        print("[bldr_farming] Status: isPlayingEmote=" .. tostring(isPlayingEmote))
    end
end, false)

-- Debug command to toggle emotes on/off
RegisterCommand('farmnoemotes', function()
    if Config.Emotes then
        Config.Emotes.enabled = not Config.Emotes.enabled
        local status = Config.Emotes.enabled and "enabled" or "disabled"
        QBCore.Functions.Notify('Farming emotes ' .. status, 'success')
        print("[bldr_farming] Emotes " .. status)
    end
end, false)

-- Debug command to enable emotes
RegisterCommand('farmemotes', function()
    if Config.Emotes then
        Config.Emotes.enabled = true
        QBCore.Functions.Notify('Farming emotes enabled', 'success')
        print("[bldr_farming] Emotes enabled")
    end
end, false)

-- Cleanup function for resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        -- Remove all plant target interactions
        for farmId, plantData in pairs(plantObjects) do
            if DoesEntityExist(plantData.object) then
                exports['qb-target']:RemoveTargetEntity(plantData.object)
                exports['qb-target']:RemoveZone('farming_plant_' .. farmId)
                DeleteObject(plantData.object)
            end
        end
        plantObjects = {}
        
        -- Clear any busy states
        isBusy = false
        isPlayingEmote = false
        currentEmoteData = nil
        
        print("[bldr_farming] Resource stopped, cleaned up all plant interactions")
    end
end)