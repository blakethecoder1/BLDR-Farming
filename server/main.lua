-- Server logic for bldr_farming
-- Tracks the state of each farming plot and coordinates planting and
-- harvesting.  Awards XP via the bldr_core (bldr_drugs_core) export.

local QBCore = exports['qb-core']:GetCoreObject()

-- Detect which inventory system is available
local InventorySystem = nil
if GetResourceState('ox_inventory') == 'started' then
    InventorySystem = 'ox_inventory'
    print("[bldr_farming] Using ox_inventory")
elseif GetResourceState('qb-inventory') == 'started' then
    InventorySystem = 'qb-inventory'
    print("[bldr_farming] Using qb-inventory")
else
    InventorySystem = 'qbcore'
    print("[bldr_farming] Using QBCore default inventory")
end

-- Inventory wrapper functions
local function GetItem(src, itemName)
    if InventorySystem == 'ox_inventory' then
        local item = exports.ox_inventory:GetItem(src, itemName, nil, true)
        return item and { name = itemName, amount = item, label = itemName } or nil
    else
        local Player = QBCore.Functions.GetPlayer(src)
        if Player then
            return Player.Functions.GetItemByName(itemName)
        end
    end
    return nil
end

local function AddItem(src, itemName, amount, metadata)
    if InventorySystem == 'ox_inventory' then
        return exports.ox_inventory:AddItem(src, itemName, amount, metadata)
    else
        local Player = QBCore.Functions.GetPlayer(src)
        if Player then
            return Player.Functions.AddItem(itemName, amount, false, metadata)
        end
    end
    return false
end

local function RemoveItem(src, itemName, amount)
    if InventorySystem == 'ox_inventory' then
        return exports.ox_inventory:RemoveItem(src, itemName, amount)
    else
        local Player = QBCore.Functions.GetPlayer(src)
        if Player then
            return Player.Functions.RemoveItem(itemName, amount)
        end
    end
    return false
end

-- Helper function to get table keys
local function getTableKeys(t)
    if not t or type(t) ~= 'table' then return {} end
    local keys = {}
    for k, _ in pairs(t) do
        table.insert(keys, tostring(k))
    end
    return keys
end

-- Ensure Config is loaded
if not Config then
    print("[ERROR] bldr_farming: Config not loaded! Check config.lua")
    return
end

-- Performance optimizations
local POLICE_JOBS = { police = true, sheriff = true, state = true }
local UPDATE_INTERVAL = 300000 -- 5 minutes instead of 2
local WATER_DECAY_INTERVAL = 180000 -- 3 minutes instead of 2
local MAX_PLANTS_PER_UPDATE = 5 -- Limit updates per cycle

-- Cache core exports to avoid repeated lookups
local coreExports = {
    xp = nil,
    level = nil,
    money = nil
}

-- Initialize core export cache
CreateThread(function()
    Wait(1000) -- Wait for other resources to load
    if exports['bldr-core'] then
        coreExports.xp = exports['bldr-core'].AddXP
        coreExports.level = exports['bldr-core'].GetLevel
        coreExports.money = exports['bldr-core'].AddMoney
    elseif exports['bldr-drugs-core'] then
        coreExports.xp = exports['bldr-drugs-core'].AddXP
        coreExports.level = exports['bldr-drugs-core'].GetLevel
        coreExports.money = exports['bldr-drugs-core'].AddMoney
    end
end)

-- Centralized water decay system
local function processWaterDecay()
    if not Config or not Config.Water or not Config.Water.enabled then
        return -- Skip if water system is disabled or config not loaded
    end
    
    if not farmStates then
        return -- Skip if farmStates not initialized yet
    end
    
    local processed = 0
    for farmId, farm in pairs(farmStates) do
        if farm.state == 'growing' then
            processed = processed + 1
            if processed > MAX_PLANTS_PER_UPDATE then
                break -- Process remaining in next cycle
            end
            
            farm.water = (farm.water or Config.Water.maxWater) - Config.Water.decayAmount
            if farm.water <= 0 then
                farm.water = 0
                farm.state = 'dead'
                -- Note: Could be improved with ownership tracking for better notifications
            end
        end
    end
end

-- Start centralized water decay timer
CreateThread(function()
    Wait(5000) -- Wait for config to fully load
    if Config and Config.Water and Config.Water.enabled then
        print("[BLDR Farming] Water decay system started")
        while true do
            Wait(WATER_DECAY_INTERVAL)
            processWaterDecay()
        end
    else
        print("[BLDR Farming] Water system disabled or config not loaded")
    end
end)

-- 🏠 Advanced Farming Systems
local greenhouseOwners = {} -- playerId -> greenhouse data
local greenhousePlots = {}  -- special greenhouse plot tracking
local irrigationSystems = {} -- plotId -> irrigation system data
local cropRotationHistory = {} -- plotId -> crop history for rotation
local weatherEffects = {} -- current weather multipliers

-- Load advanced farming data
CreateThread(function()
    Wait(5000) -- Ensure database and config are ready
    
    -- Validate config is loaded
    if not Config then
        print("[ERROR] bldr_farming: Config is nil! Check config.lua for syntax errors")
        return
    end
    
    -- Initialize weather effects
    weatherEffects = {
        growth = 1.0,
        disease = 0.1,
        water_loss = 1.0
    }
    
    print('[BLDR Farming] Advanced systems initialized successfully')
end)

-- internal table to store the state of each plot
-- possible states: 'empty', 'growing', 'ready'
-- track the state of each farm plot.  Each entry contains a state
-- ('empty','growing','ready','dead'), the time at which the crop will be
-- ready (readyTime), the current water level (water) and a flag
-- indicating whether this plot is a wild plant (wild).  For regular
-- plots water will be used to compute quality; for wild plants it is
-- unused.
local farmStates = {}

-- track the state of each wild plant defined in Config.WildPlants.
-- Each entry will be true if the plant has been harvested.  If nil or
-- false the plant is still available.
local wildStates = {}
--[[
    Local admin permission check for farming

    Determines if a player has permission to use admin commands.
    Falls back to core export if available; otherwise performs
    its own check based on QBCore groups, ACE permissions and
    Config.AdminWhitelist in bldr_core.
]]
local function isBLDRAdmin(src)
    -- console always allowed
    if src <= 0 then return true end
    -- runtime bypass for testing (setr bldr_admin_bypass 1 in server.cfg)
    if GetConvarInt('bldr_admin_bypass', 0) == 1 then return true end
    -- QBCore group checks
    if QBCore and QBCore.Functions and QBCore.Functions.HasPermission then
        if QBCore.Functions.HasPermission(src, 'god') or QBCore.Functions.HasPermission(src, 'admin') then
            return true
        end
    end
    -- ACE permissions
    if IsPlayerAceAllowed(src, 'bldr.admin') or IsPlayerAceAllowed(src, 'command') then
        return true
    end
    -- static whitelist via core config (if loaded)
    if Config and Config.AdminWhitelist then
        local lic
        for _, id in ipairs(GetPlayerIdentifiers(src)) do
            if id:sub(1,8) == 'license:' then lic = id break end
        end
        if lic and Config.AdminWhitelist[lic] then
            return true
        end
    end
    return false
end

-- internal pricing state for the market.  We copy the configured
-- price from Config.Market.items so we can adjust it at runtime.
local MarketState = {}

-- Initialize market prices from config
CreateThread(function()
    Wait(2000) -- Wait for config to load
    print("[BLDR Farming] Initializing market system...")
    
    if not Config then
        print("[BLDR Farming] ERROR: Config is nil!")
        return
    end
    
    if not Config.Market then
        print("[BLDR Farming] ERROR: Config.Market is nil!")
        return
    end
    
    if not Config.Market.items then
        print("[BLDR Farming] ERROR: Config.Market.items is nil!")
        print("[BLDR Farming] Config.Market keys:", json.encode(getTableKeys(Config.Market)))
        return
    end
    
    local itemCount = 0
    for item, cfg in pairs(Config.Market.items) do
        MarketState[item] = cfg.price
        itemCount = itemCount + 1
    end
    print(("[BLDR Farming] Market prices initialized - %d items loaded"):format(itemCount))
end)

-- initialize states on resource start
CreateThread(function()
    Wait(3000) -- Wait for config to fully load
    if not Config or not Config.Farms then
        print("[ERROR] bldr_farming: Config.Farms not found!")
        return
    end
    
    for index, farm in ipairs(Config.Farms) do
        farmStates[index] = {
            state     = 'empty',
            readyTime = 0,
            water     = 0,
            wild      = false
        }
    end

    -- initialize wild plant states
    if Config.WildPlants then
        for i=1,#Config.WildPlants do
            wildStates[i] = false
        end
    end
end)

-- Enhanced notification system with server-side duplicate prevention
local playerNotificationCache = {}
local NOTIFICATION_COOLDOWN = 2000 -- 2 seconds

local function notify(src, msg, type)
    -- Initialize cache for player if needed
    if not playerNotificationCache[src] then
        playerNotificationCache[src] = {}
    end
    
    local currentTime = GetGameTimer()
    local msgHash = msg or 'default'
    
    -- Check if this exact message was sent recently to this player
    if playerNotificationCache[src][msgHash] and 
       (currentTime - playerNotificationCache[src][msgHash]) < NOTIFICATION_COOLDOWN then
        return -- Silently ignore duplicate
    end
    
    -- Update cache and send notification
    playerNotificationCache[src][msgHash] = currentTime
    TriggerClientEvent('bldr_farming:message', src, msg, type)
end

-- Clean up notification cache when player disconnects
AddEventHandler('playerDropped', function()
    local src = source
    if playerNotificationCache[src] then
        playerNotificationCache[src] = nil
    end
end)

--[[
    alertPolice

    Sends a notification to all players with the police job that
    suspicious farming activity has occurred.  The chance of an
    alert is configured per harvest item in Config.PoliceAlert.  If
    the random roll succeeds, each online police player will receive
    a notification and optionally a dispatch message containing the
    approximate location.  You can adapt this function to trigger
    your own dispatch or alert system.

    @param itemName string: the harvested item name (e.g. 'weed', 'cocaine')
    @param coords   vector3: world coordinates of the plot
]]
-- Optimized police alert function - cache police players
local policePlayers = {}
local lastPoliceUpdate = 0

local function updatePoliceCache()
    local now = GetGameTimer()
    if now - lastPoliceUpdate < 30000 then return end -- Update every 30 seconds max
    
    policePlayers = {}
    for _, id in pairs(QBCore.Functions.GetPlayers()) do
        local ply = QBCore.Functions.GetPlayer(id)
        if ply and ply.PlayerData and ply.PlayerData.job and POLICE_JOBS[ply.PlayerData.job.name] then
            policePlayers[#policePlayers + 1] = id
        end
    end
    lastPoliceUpdate = now
end

local function alertPolice(itemName, coords)
    if not Config.PoliceAlert then return end
    local chance = Config.PoliceAlert[itemName]
    if not chance or chance <= 0 then return end
    if math.random() >= chance then return end
    
    updatePoliceCache()
    
    local message = 'Suspicious farming activity detected in the area.'
    for i = 1, #policePlayers do
        TriggerClientEvent('QBCore:Notify', policePlayers[i], message, 'error')
    end
end

--[[
    checkBlueprintRewards

    Rewards blueprint items to players based on their farming level.
    When a player reaches a certain level threshold they will
    automatically receive the corresponding blueprint if they do not
    already have it.  This function should be called after XP is
    awarded (for example at the end of a harvest).

    Level thresholds:
      - Level 2+: weed_joint_bp
      - Level 4+: cocaine_bag_bp

    @param src number: the player source id
]]
local function checkBlueprintRewards(src)
    -- obtain player object
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    -- determine current level from core exports
    local lvl = 0
    local coreExport = nil
    if exports['bldr-core'] and exports['bldr-core'].GetLevel then
        coreExport = exports['bldr-core']
    elseif exports['bldr-drugs-core'] and exports['bldr-drugs-core'].GetLevel then
        coreExport = exports['bldr-drugs-core']
    end
    if coreExport then
        lvl = coreExport:GetLevel(src) or 0
    end
    -- reward weed joint blueprint at level >=2
    if lvl >= 2 then
        local item = GetItem(src, 'weed_joint_bp')
        if not item or item.amount < 1 then
            AddItem(src, 'weed_joint_bp', 1)
            notify(src, 'You have unlocked a new blueprint: Joint', 'success')
        end
    end
    -- reward cocaine bag blueprint at level >=4
    if lvl >= 4 then
        local item = GetItem(src, 'cocaine_bag_bp')
        if not item or item.amount < 1 then
            AddItem(src, 'cocaine_bag_bp', 1)
            notify(src, 'You have unlocked a new blueprint: Cocaine Bag', 'success')
        end
    end
end

-- handle player interaction with a farm plot
RegisterNetEvent('bldr_farming:interact', function(farmId)
    local src = source
    print("[bldr_farming] Server received interact event from player " .. src .. " for farmId: " .. tostring(farmId))
    farmId = tonumber(farmId)
    if not farmId or not Config.Farms[farmId] then 
        print("[bldr_farming] Invalid farmId: " .. tostring(farmId))
        return 
    end
    local stateInfo = farmStates[farmId]
    local state = stateInfo.state
    local farm = Config.Farms[farmId]
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    -- treat dead plots as empty for replanting
    if state == 'dead' then
        state = 'empty'
    end

    if state == 'empty' then
        -- planting: require proper level and seed item
        local seedItem = farm.plantItem
        local levelReq = Config.LevelUnlocks[seedItem] or 0
        local lvl = 0
        local coreExport = nil
        if exports['bldr-core'] and exports['bldr-core'].GetLevel then
            coreExport = exports['bldr-core']
        elseif exports['bldr-drugs-core'] and exports['bldr-drugs-core'].GetLevel then
            coreExport = exports['bldr-drugs-core']
        end
        if coreExport then
            lvl = coreExport:GetLevel(src) or 0
        end
        print("[bldr_farming] Player level: " .. lvl .. ", required level: " .. levelReq)
        
        if lvl < levelReq then
            notify(src, ('🔒 Level Required | You need farming level %d to cultivate %s'):format(levelReq, seedItem:gsub('_', ' ')), 'error')
            print("[bldr_farming] Level requirement not met: " .. lvl .. " < " .. levelReq)
            return
        end
        local invItem = GetItem(src, seedItem)
        print("[bldr_farming] Checking for seed item: " .. seedItem)
        print("[bldr_farming] Player has item: " .. tostring(invItem and invItem.amount or 0))
        
        if not invItem or invItem.amount < 1 then
            notify(src, ('🌱 Missing Seeds | You need at least one %s to begin cultivation'):format(seedItem:gsub('_', ' ')), 'error')
            print("[bldr_farming] Player missing seed item: " .. seedItem)
            return
        end
        RemoveItem(src, seedItem, 1)
        stateInfo.state       = 'growing'
        -- record the seed and harvest item for this plot so we
        -- can reference it later (e.g. for police alerts)
        stateInfo.plantItem   = seedItem
        stateInfo.harvestItem = farm.harvestItem
        local readyTime       = GetGameTimer() + farm.growTime
        stateInfo.readyTime   = readyTime
        -- initialize water level if watering is enabled
        if Config.Water.enabled then
            stateInfo.water = Config.Water.maxWater
        end
        notify(src, ('🌱 Cultivation Started | Successfully planted %s - Monitor growth and maintain hydration'):format(seedItem:gsub('_', ' ')), 'success')
        
        -- Notify all clients to show plant visual
        TriggerClientEvent('bldr_farming:updatePlantVisual', -1, farmId, 'growing', 0, seedItem)
        
        -- set ready state after growth time
        SetTimeout(farm.growTime, function()
            if farmStates[farmId].state == 'growing' then
                farmStates[farmId].state = 'ready'
                -- Update plant visual to full size
                TriggerClientEvent('bldr_farming:updatePlantVisual', -1, farmId, 'ready', 100, seedItem)
            end
        end)
        -- Note: Water decay now handled by centralized system
    elseif state == 'growing' then
        notify(src, 'This plot is still growing. Tend to its water and check back later.', 'primary')
    elseif state == 'ready' then
        -- harvesting: compute yield and quality
        local harvestItem = farm.harvestItem
        local amountRange = farm.amountRange or {1,3}
        local minAmt, maxAmt = amountRange[1], amountRange[2]
        local amount = math.random(minAmt, maxAmt)
        
        -- Apply fertilizer yield bonus
        if stateInfo.fertilized and stateInfo.fertilizerBonus and stateInfo.fertilizerBonus.yieldBonus then
            local bonus = math.floor(amount * stateInfo.fertilizerBonus.yieldBonus)
            amount = amount + bonus
        end
        
        -- determine quality if watering enabled
        local quality = 75 -- base quality
        if Config.Water.enabled then
            local water = stateInfo.water or Config.Water.maxWater
            local ratio = water / Config.Water.maxWater
            quality = math.max(1, math.min(100, math.floor(ratio * 100) + math.random(-10,10)))
        end
        
        -- Apply fertilizer quality bonus
        if stateInfo.fertilized and stateInfo.fertilizerBonus and stateInfo.fertilizerBonus.qualityBonus then
            quality = math.min(100, quality + stateInfo.fertilizerBonus.qualityBonus)
        end
        
        -- Add items with quality
        for i=1, amount do
            AddItem(src, harvestItem, 1, nil)  -- No quality metadata
        end
        
        -- Harvest notification
        local harvestMsg = ('Harvested %dx %s (Quality: %d%%)'):format(amount, harvestItem, quality)
        if stateInfo.fertilized then
            harvestMsg = harvestMsg .. (' [Fertilized with %s]'):format(stateInfo.fertilized:gsub('_', ' '))
        end
        notify(src, harvestMsg, 'success')
        -- award XP
        local xpVal = farm.xp or 0
        local xpExport = nil
        if exports['bldr-core'] and exports['bldr-core'].AddXP then
            xpExport = exports['bldr-core']
        elseif exports['bldr-drugs-core'] and exports['bldr-drugs-core'].AddXP then
            xpExport = exports['bldr-drugs-core']
        end
        if xpExport and xpVal > 0 then
            xpExport:AddXP(src, xpVal)
            -- after adding XP, check for blueprint rewards
            checkBlueprintRewards(src)
        end
        -- attempt to alert police based on harvested item
        alertPolice(harvestItem, farm.coords)
        -- reset state for next planting
        stateInfo.state       = 'empty'
        stateInfo.readyTime   = 0
        stateInfo.water       = 0
        stateInfo.fertilized  = nil
        stateInfo.fertilizerBonus = nil
        stateInfo.plantItem   = nil
        stateInfo.harvestItem = nil
        
        -- Notify all clients to remove plant visual
        TriggerClientEvent('bldr_farming:plantHarvested', -1, farmId)
        
        notify(src, harvestMsg, 'success')
    end
end)

-- Event to water a growing plant.  Consumes one water item and increases
-- the plant's water level up to the maximum.  Only works on
-- actively growing crops.
RegisterNetEvent('bldr_farming:water', function(farmId)
    local src = source
    farmId = tonumber(farmId)
    if not farmId or not Config.Farms[farmId] then return end
    if not Config.Water.enabled then return end
    local stateInfo = farmStates[farmId]
    if stateInfo.state ~= 'growing' then
        notify(src, '💧 No Plant Found | This plot has no growing plant that requires watering', 'error')
        return
    end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local waterItem = Config.Water.waterItem
    local invItem   = GetItem(src, waterItem)
    if not invItem or invItem.amount < 1 then
        notify(src, ('💧 Water Can Required | You need a %s to hydrate your plants'):format(waterItem:gsub('_', ' ')), 'error')
        return
    end
    RemoveItem(src, waterItem, 1)
    local oldWater = stateInfo.water or 0
    stateInfo.water = math.min(Config.Water.maxWater, oldWater + Config.Water.addAmount)
    local newPercent = math.floor((stateInfo.water / Config.Water.maxWater) * 100)
    notify(src, ('💧 Plant Hydrated | Water level restored to %d%% - Optimal growth conditions maintained'):format(newPercent), 'success')
end)

-- Event to water plant with water can (third-eye interaction)
RegisterNetEvent('bldr_farming:waterWithCan', function(farmId)
    local src = source
    farmId = tonumber(farmId)
    if not farmId or not Config.Farms[farmId] then return end
    if not Config.Water.enabled then return end
    
    local stateInfo = farmStates[farmId]
    if stateInfo.state ~= 'growing' then
        notify(src, '💧 No Growing Plant | This plot has no active plant that needs watering', 'error')
        return
    end
    
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    -- Check for water can items
    local waterCanItem = GetItem(src, 'water_can') or GetItem(src, 'watering_can')
    if not waterCanItem or waterCanItem.amount < 1 then
        notify(src, '💧 Water Can Required | You need a water can to irrigate plants properly', 'error')
        return
    end
    

-- =================================================================
-- BATCH HARVESTING SYSTEM
-- =================================================================

RegisterNetEvent('bldr_farming:batchHarvest', function(plotIds)
    local src = source
    
    if not Config.BatchHarvest or not Config.BatchHarvest.enabled then
        notify(src, 'Batch harvesting is not enabled', 'error')
        return
    end
    
    -- Check player level requirement
    local lvl = 0
    local coreExport = nil
    if exports['bldr-core'] and exports['bldr-core'].GetLevel then
        coreExport = exports['bldr-core']
    elseif exports['bldr-drugs-core'] and exports['bldr-drugs-core'].GetLevel then
        coreExport = exports['bldr-drugs-core']
    end
    if coreExport then
        lvl = coreExport:GetLevel(src) or 0
    end
    
    if lvl < (Config.BatchHarvest.requiredLevel or 0) then
        notify(src, ('🔒 Level Required | You need level %d to use batch harvesting'):format(Config.BatchHarvest.requiredLevel), 'error')
        return
    end
    
    -- Validate plots
    if not plotIds or type(plotIds) ~= 'table' or #plotIds == 0 then
        notify(src, 'No plots selected for batch harvest', 'error')
        return
    end
    
    if #plotIds > (Config.BatchHarvest.maxPlots or 5) then
        notify(src, ('Maximum %d plots can be harvested at once'):format(Config.BatchHarvest.maxPlots), 'error')
        return
    end
    
    local readyPlots = {}
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    -- Verify all plots are ready
    for _, farmId in ipairs(plotIds) do
        farmId = tonumber(farmId)
        if farmId and Config.Farms[farmId] and farmStates[farmId] and farmStates[farmId].state == 'ready' then
            table.insert(readyPlots, farmId)
        end
    end
    
    if #readyPlots == 0 then
        notify(src, 'No ready plots found for batch harvest', 'error')
        return
    end
    
    -- Start batch harvest
    notify(src, ('🌾 Batch Harvest Started | Harvesting %d plots...'):format(#readyPlots), 'primary')
    
    local totalHarvested = 0
    local totalXP = 0
    local harvestedItems = {}
    
    for i, farmId in ipairs(readyPlots) do
        local stateInfo = farmStates[farmId]
        local farm = Config.Farms[farmId]
        local harvestItem = farm.harvestItem
        local amountRange = farm.amountRange or {1,3}
        local minAmt, maxAmt = amountRange[1], amountRange[2]
        local amount = math.random(minAmt, maxAmt)
        
        -- Apply batch harvest bonus
        if Config.BatchHarvest.xpBonus then
            local bonusAmount = math.floor(amount * (Config.BatchHarvest.xpBonus - 1))
            amount = amount + bonusAmount
        end
        
        -- Apply fertilizer yield bonus
        if stateInfo.fertilized and stateInfo.fertilizerBonus and stateInfo.fertilizerBonus.yieldBonus then
            local bonus = math.floor(amount * stateInfo.fertilizerBonus.yieldBonus)
            amount = amount + bonus
        end
        
        -- Calculate quality
        local quality = 75
        if Config.Water.enabled then
            local water = stateInfo.water or Config.Water.maxWater
            local ratio = water / Config.Water.maxWater
            quality = math.max(1, math.min(100, math.floor(ratio * 100) + math.random(-10,10)))
        end
        
        -- Apply fertilizer quality bonus
        if stateInfo.fertilized and stateInfo.fertilizerBonus and stateInfo.fertilizerBonus.qualityBonus then
            quality = math.min(100, quality + stateInfo.fertilizerBonus.qualityBonus)
        end
        
        -- Add items
        for j=1, amount do
            AddItem(src, harvestItem, 1, nil)  -- No quality metadata
        end
        
        -- Track harvested items
        if not harvestedItems[harvestItem] then
            harvestedItems[harvestItem] = 0
        end
        harvestedItems[harvestItem] = harvestedItems[harvestItem] + amount
        totalHarvested = totalHarvested + amount
        
        -- Award XP with batch bonus
        local xpVal = farm.xp or 0
        if Config.BatchHarvest.xpBonus then
            xpVal = math.floor(xpVal * Config.BatchHarvest.xpBonus)
        end
        totalXP = totalXP + xpVal
        
        -- Reset plot state
        stateInfo.state = 'empty'
        stateInfo.readyTime = 0
        stateInfo.water = 0
        stateInfo.fertilized = nil
        stateInfo.fertilizerBonus = nil
        stateInfo.plantItem = nil
        stateInfo.harvestItem = nil
        
        -- Notify clients
        TriggerClientEvent('bldr_farming:plantHarvested', -1, farmId)
        
        -- Alert police (low chance per plot)
        if math.random() < 0.3 then
            alertPolice(harvestItem, farm.coords)
        end
    end
    
    -- Award total XP
    local xpExport = nil
    if exports['bldr-core'] and exports['bldr-core'].AddXP then
        xpExport = exports['bldr-core']
    elseif exports['bldr-drugs-core'] and exports['bldr-drugs-core'].AddXP then
        xpExport = exports['bldr-drugs-core']
    end
    if xpExport and totalXP > 0 then
        xpExport:AddXP(src, totalXP)
        checkBlueprintRewards(src)
    end
    
    -- Update statistics
    if exports['bldr-core'] and exports['bldr-core'].UpdateStat then
        exports['bldr-core']:UpdateStat(src, 'plants_harvested', #readyPlots)
        exports['bldr-core']:UpdateStat(src, 'total_farming_xp', totalXP)
    end
    
    -- Build notification message
    local itemsText = {}
    for item, count in pairs(harvestedItems) do
        table.insert(itemsText, ('%dx %s'):format(count, item))
    end
    
    notify(src, ('✅ Batch Harvest Complete | Harvested %d plots: %s (+%d XP)'):format(
        #readyPlots, table.concat(itemsText, ', '), totalXP
    ), 'success')
end)

-- =================================================================
-- HARVEST MINIGAME SYSTEM
-- =================================================================

RegisterNetEvent('bldr_farming:harvestWithMinigame', function(farmId, minigameResult)
    local src = source
    farmId = tonumber(farmId)
    
    if not farmId or not Config.Farms[farmId] then return end
    if not Config.HarvestMinigame or not Config.HarvestMinigame.enabled then return end
    
    local stateInfo = farmStates[farmId]
    if stateInfo.state ~= 'ready' then
        notify(src, 'This plot is not ready for harvest', 'error')
        return
    end
    
    local farm = Config.Farms[farmId]
    local harvestItem = farm.harvestItem
    local amountRange = farm.amountRange or {1,3}
    local minAmt, maxAmt = amountRange[1], amountRange[2]
    local amount = math.random(minAmt, maxAmt)
    
    -- Base quality
    local quality = 75
    if Config.Water.enabled then
        local water = stateInfo.water or Config.Water.maxWater
        local ratio = water / Config.Water.maxWater
        quality = math.max(1, math.min(100, math.floor(ratio * 100) + math.random(-10,10)))
    end
    
    -- Apply minigame result bonuses
    local resultData = Config.HarvestMinigame.rewards[minigameResult] or Config.HarvestMinigame.rewards.ok
    
    -- Yield bonus
    if resultData.yieldBonus then
        local bonusAmount = math.floor(amount * resultData.yieldBonus)
        amount = math.max(1, amount + bonusAmount)
    end
    
    -- Quality bonus
    if resultData.qualityBonus then
        quality = math.max(1, math.min(100, quality + resultData.qualityBonus))
    end
    
    -- Calculate quality for core system
    local qualityFactors = {
        equipment = 0,
        minigame = resultData.qualityBonus or 0,
        random = 0
    }
    
    if exports['bldr-core'] and exports['bldr-core'].CalculateQuality then
        quality = exports['bldr-core']:CalculateQuality(src, quality, qualityFactors)
    end
    
    -- Apply fertilizer bonuses
    if stateInfo.fertilized and stateInfo.fertilizerBonus then
        if stateInfo.fertilizerBonus.yieldBonus then
            local bonus = math.floor(amount * stateInfo.fertilizerBonus.yieldBonus)
            amount = amount + bonus
        end
        if stateInfo.fertilizerBonus.qualityBonus then
            quality = math.min(100, quality + stateInfo.fertilizerBonus.qualityBonus)
        end
    end
    
    -- Add items with quality
    for i=1, amount do
        AddItem(src, harvestItem, 1, nil)  -- No quality metadata
    end
    
    -- Award XP with minigame multiplier
    local xpVal = farm.xp or 0
    if resultData.xpMultiplier then
        xpVal = math.floor(xpVal * resultData.xpMultiplier)
    end
    
    local xpExport = nil
    if exports['bldr-core'] and exports['bldr-core'].AddXP then
        xpExport = exports['bldr-core']
    elseif exports['bldr-drugs-core'] and exports['bldr-drugs-core'].AddXP then
        xpExport = exports['bldr-drugs-core']
    end
    if xpExport and xpVal > 0 then
        xpExport:AddXP(src, xpVal)
        checkBlueprintRewards(src)
    end
    
    -- Update statistics
    if exports['bldr-core'] and exports['bldr-core'].UpdateStat then
        exports['bldr-core']:UpdateStat(src, 'plants_harvested', 1)
        exports['bldr-core']:UpdateStat(src, 'total_farming_xp', xpVal)
    end
    
    -- Get quality tier for display
    local qualityTier = 'Common'
    if exports['bldr-core'] and exports['bldr-core'].GetQualityTier then
        local tierInfo = exports['bldr-core']:GetQualityTier(quality)
        qualityTier = tierInfo.label
    end
    
    -- Notify with result
    local resultEmoji = {
        perfect = '⭐',
        good = '✨',
        ok = '✓',
        failed = '⚠️'
    }
    
    local emoji = resultEmoji[minigameResult] or '✓'
    notify(src, ('%s Harvested %dx %s | Quality: %s (%d%%) | Result: %s (+%d XP)'):format(
        emoji, amount, harvestItem, qualityTier, quality, minigameResult:upper(), xpVal
    ), 'success')
    
    -- Alert police
    alertPolice(harvestItem, farm.coords)
    
    -- Reset plot state
    stateInfo.state = 'empty'
    stateInfo.readyTime = 0
    stateInfo.water = 0
    stateInfo.fertilized = nil
    stateInfo.fertilizerBonus = nil
    stateInfo.plantItem = nil
    stateInfo.harvestItem = nil
    
    -- Notify clients
    TriggerClientEvent('bldr_farming:plantHarvested', -1, farmId)
end)
    -- Remove water can item (consumes usage)
    local itemName = waterCanItem.name
    RemoveItem(src, itemName, 1)
    
    -- Apply water to plant
    local oldWater = stateInfo.water or 0
    stateInfo.water = math.min(Config.Water.maxWater, oldWater + (Config.Water.addAmount * 1.5)) -- 50% more effective than regular watering
    local newPercent = math.floor((stateInfo.water / Config.Water.maxWater) * 100)
    
    notify(src, ('💧 Professional Irrigation Complete | Water level boosted to %d%% using %s - Enhanced growth rate activated'):format(newPercent, itemName:gsub('_', ' ')), 'success')
    
    -- Give small XP bonus for proper tool usage
    if coreExports.xp then
        coreExports.xp(src, 'farming', 2)
    end
end)

-- Event to apply fertilizer to a growing plant
RegisterNetEvent('bldr_farming:fertilize', function(farmId)
    local src = source
    farmId = tonumber(farmId)
    if not farmId or not Config.Farms[farmId] then return end
    if not Config.Fertilizer or not Config.Fertilizer.enabled then 
        notify(src, '🧪 System Unavailable | Fertilizer enhancement system is currently disabled', 'error')
        return 
    end
    
    local stateInfo = farmStates[farmId]
    if stateInfo.state ~= 'growing' then
        notify(src, '🧪 No Growing Plant | This plot has no active cultivation to fertilize', 'error')
        return
    end
    
    -- Check if already fertilized
    if stateInfo.fertilized then
        notify(src, '✅ Already Enhanced | This plant has already received optimal fertilizer treatment', 'error')
        return
    end
    
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    -- Check for fertilizer items (premium first, then basic)
    local fertilizer = nil
    local fertilizerType = nil
    
    local premiumFert = GetItem(src, 'premium_fertilizer')
    local basicFert = GetItem(src, 'basic_fertilizer')
    
    if premiumFert and premiumFert.amount > 0 then
        fertilizer = 'premium_fertilizer'
        fertilizerType = Config.Fertilizer.types.premium_fertilizer
    elseif basicFert and basicFert.amount > 0 then
        fertilizer = 'basic_fertilizer'
        fertilizerType = Config.Fertilizer.types.basic_fertilizer
    end
    
    if not fertilizer then
        notify(src, '🧪 No Fertilizer Available | Purchase basic or premium fertilizer from the market to enhance your crops', 'error')
        return
    end
    
    RemoveItem(src, fertilizer, 1)
    stateInfo.fertilized = fertilizer
    stateInfo.fertilizerBonus = fertilizerType
    
    -- Apply growth speed bonus by reducing remaining time
    if fertilizerType.growthBonus and fertilizerType.growthBonus > 0 then
        local now = GetGameTimer()
        local remaining = stateInfo.readyTime - now
        local reduction = remaining * fertilizerType.growthBonus
        stateInfo.readyTime = stateInfo.readyTime - reduction
    end
    
    notify(src, ('🧪 Enhancement Applied | %s treatment successful - Growth accelerated by %d%%'):format(fertilizer:gsub('_', ' '), math.floor((fertilizerType.growthBonus or 0) * 100)), 'success')
end)

-- Provide the current state of a plot to the client for UI
RegisterNetEvent('bldr_farming:getState', function(farmId)
    local src = source
    farmId = tonumber(farmId)
    if not farmId or not Config.Farms[farmId] then return end
    local stateInfo = farmStates[farmId]
    local state = stateInfo and stateInfo.state or 'empty'
    local progress = 0
    if state == 'growing' then
        local now = GetGameTimer()
        local farm = Config.Farms[farmId]
        local total = farm.growTime
        local readyTime = stateInfo.readyTime
        local elapsed = total - (readyTime - now)
        if elapsed < 0 then elapsed = 0 end
        progress = math.min(100, math.floor((elapsed / total) * 100))
    end
    local waterPercent = nil
    if Config.Water.enabled and state == 'growing' then
        local water = stateInfo.water or Config.Water.maxWater
        waterPercent = math.floor((water / Config.Water.maxWater) * 100)
    end
    local data = {
        farmId     = farmId,
        label      = Config.Farms[farmId].label or 'Farm Plot',
        state      = state,
        progress   = progress,
        water      = waterPercent,
        waterMax   = Config.Water.enabled and 100 or nil,
        fertilized = stateInfo and stateInfo.fertilized or nil,
        plantItem  = stateInfo and stateInfo.plantItem or nil,
        harvestItem = stateInfo and stateInfo.harvestItem or nil
    }
    TriggerClientEvent('bldr_farming:showContextMenu', src, data)
end)

-- Event to request current plant visual state (for client initialization)
RegisterNetEvent('bldr_farming:requestPlantVisual', function(farmId)
    local src = source
    farmId = tonumber(farmId)
    if not farmId or not Config.Farms[farmId] then return end
    
    local stateInfo = farmStates[farmId]
    local state = stateInfo and stateInfo.state or 'empty'
    
    if state == 'growing' or state == 'ready' then
        local progress = 0
        if state == 'growing' then
            local now = GetGameTimer()
            local farm = Config.Farms[farmId]
            local total = farm.growTime
            local readyTime = stateInfo.readyTime
            local elapsed = total - (readyTime - now)
            if elapsed < 0 then elapsed = 0 end
            progress = math.min(100, math.floor((elapsed / total) * 100))
        elseif state == 'ready' then
            progress = 100
        end
        
        TriggerClientEvent('bldr_farming:updatePlantVisual', src, farmId, state, progress, stateInfo.plantItem)
    end
end)

-- Growth update system - update plant visuals every 2 minutes
CreateThread(function()
    while true do
        Wait(120000) -- 2 minutes
        
        for farmId, stateInfo in pairs(farmStates) do
            if stateInfo.state == 'growing' and stateInfo.plantItem then
                local now = GetGameTimer()
                local farm = Config.Farms[farmId]
                local total = farm.growTime
                local readyTime = stateInfo.readyTime
                local elapsed = total - (readyTime - now)
                if elapsed < 0 then elapsed = 0 end
                local progress = math.min(100, math.floor((elapsed / total) * 100))
                
                -- Update all clients with current growth progress
                TriggerClientEvent('bldr_farming:updatePlantVisual', -1, farmId, 'growing', progress, stateInfo.plantItem)
            end
        end
    end
end)

--[[
    Market logic

    The market allows players to buy seeds and supplies and sell
    harvested goods.  Prices fluctuate based on supply and demand: each
    purchase increases the price by Config.Market.priceAdjust and each
    sale decreases the price by the same factor.  Prices are stored
    in the MarketState table and constrained between the configured
    basePrice and double the base price.  Level restrictions are
    enforced based on Config.Market.items entries.
]]

-- Send current market information to a client.  Called when the
-- client opens the market UI.
RegisterNetEvent('bldr_farming:getMarket', function()
    local src = source
    local items = {}
    for item, cfg in pairs(Config.Market.items or {}) do
        items[item] = {
            label    = cfg.label,
            price    = MarketState[item] or cfg.price,
            type     = cfg.type,
            minLevel = cfg.minLevel or 0
        }
    end
    TriggerClientEvent('bldr_farming:marketData', src, items)
end)

-- Handle a purchase from the market.  Consumes money from the player
-- and increases the price of the purchased item.  Only items with
-- type='buy' are valid purchases.
RegisterNetEvent('bldr_farming:buyItem', function(itemName, amount)
    local src = source
    itemName = tostring(itemName or '')
    amount   = tonumber(amount) or 1
    if amount <= 0 then return end
    local itemCfg = Config.Market.items[itemName]
    if not itemCfg or itemCfg.type ~= 'buy' then
        notify(src, 'Item cannot be purchased.', 'error')
        return
    end
    -- check level requirement
    local levelReq = itemCfg.minLevel or 0
    local lvl = 0
    local coreExport = nil
    if exports['bldr-core'] and exports['bldr-core'].GetLevel then
        coreExport = exports['bldr-core']
    elseif exports['bldr-drugs-core'] and exports['bldr-drugs-core'].GetLevel then
        coreExport = exports['bldr-drugs-core']
    end
    if coreExport then
        lvl = coreExport:GetLevel(src) or 0
    end
    if lvl < levelReq then
        notify(src, ('🔒 Access Restricted | Level %d farming experience required to purchase %s'):format(levelReq, itemCfg.label), 'error')
        return
    end
    -- determine price
    local currentPrice = MarketState[itemName] or itemCfg.price
    local total = math.floor(currentPrice * amount)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    -- remove cash; if insufficient funds RemoveMoney returns false
    if not Player.Functions.RemoveMoney('cash', total, 'farm-market-buy') then
        notify(src, ('💳 Insufficient Funds | You need $%d to complete this purchase'):format(total), 'error')
        return
    end
    -- add items to inventory
    AddItem(src, itemName, amount)
    -- adjust price upward
    local adjust = Config.Market.priceAdjust or 0
    local newPrice = currentPrice * (1 + adjust)
    local maxPrice = (itemCfg.basePrice or currentPrice) * 2
    if newPrice > maxPrice then newPrice = maxPrice end
    MarketState[itemName] = newPrice
    notify(src, ('🛒 Purchase Complete | Acquired %dx %s for $%d - Premium quality guaranteed'):format(amount, itemCfg.label, total), 'success')
end)

-- Handle a sale at the market.  Removes items from the player's
-- inventory, pays out money and decreases the item's price.  Only
-- items with type='sell' can be sold.
RegisterNetEvent('bldr_farming:sellItem', function(itemName, amount)
    local src = source
    itemName = tostring(itemName or '')
    amount   = tonumber(amount) or 1
    if amount <= 0 then return end
    local itemCfg = Config.Market.items[itemName]
    if not itemCfg or itemCfg.type ~= 'sell' then
        notify(src, 'Item cannot be sold here.', 'error')
        return
    end
    -- level requirement
    local levelReq = itemCfg.minLevel or 0
    local lvl = 0
    local coreExport = nil
    if exports['bldr-core'] and exports['bldr-core'].GetLevel then
        coreExport = exports['bldr-core']
    elseif exports['bldr-drugs-core'] and exports['bldr-drugs-core'].GetLevel then
        coreExport = exports['bldr-drugs-core']
    end
    if coreExport then
        lvl = coreExport:GetLevel(src) or 0
    end
    if lvl < levelReq then
        notify(src, ('You must be level %d to sell %s.'):format(levelReq, itemCfg.label), 'error')
        return
    end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local invItem = GetItem(src, itemName)
    if not invItem or invItem.amount < amount then
        notify(src, 'You do not have enough to sell.', 'error')
        return
    end
    -- remove items
    RemoveItem(src, itemName, amount)
    -- compute payout
    local currentPrice = MarketState[itemName] or itemCfg.price
    local total = math.floor(currentPrice * amount)
    -- pay via core exports or fallback to cash
    local payExport = nil
    if exports['bldr-core'] and exports['bldr-core'].AddMoney then
        payExport = exports['bldr-core']
    elseif exports['bldr-drugs-core'] and exports['bldr-drugs-core'].AddMoney then
        payExport = exports['bldr-drugs-core']
    end
    if payExport then
        payExport:AddMoney(src, total)
    else
        Player.Functions.AddMoney('cash', total, 'farm-market-sell')
    end
    -- adjust price downward
    local adjust = Config.Market.priceAdjust or 0
    local newPrice = currentPrice * (1 - adjust)
    local base = itemCfg.basePrice or currentPrice
    if newPrice < base then newPrice = base end
    MarketState[itemName] = newPrice
    notify(src, ('💰 Sale Complete | Sold %dx %s for $%d - Premium market rate achieved'):format(amount, itemCfg.label, total), 'success')
end)

-- Harvest a wild plant.  Wild plants can only be harvested once per
-- server restart and do not need to be planted or watered.  When
-- harvested the plant is marked as harvested and will not yield
-- again until restart.  Grants a random quantity within the
-- configured range and awards XP.
RegisterNetEvent('bldr_farming:harvestWild', function(wildId)
    local src = source
    wildId = tonumber(wildId)
    if not wildId or not Config.WildPlants or not Config.WildPlants[wildId] then return end
    -- check if already harvested
    if wildStates[wildId] then
        notify(src, 'This wild plant has already been harvested.', 'error')
        return
    end
    local wild = Config.WildPlants[wildId]
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    -- random amount within range
    local minAmt, maxAmt = wild.amount[1], wild.amount[2]
    local amount = math.random(minAmt, maxAmt)
    -- random quality between 80 and 100
    local quality = math.random(80, 100)
    for i=1, amount do
        AddItem(src, wild.item, 1, { quality = quality })
    end
    -- award XP
    local xpVal = wild.xp or 0
    local xpExport = nil
    if exports['bldr-core'] and exports['bldr-core'].AddXP then
        xpExport = exports['bldr-core']
    elseif exports['bldr-drugs-core'] and exports['bldr-drugs-core'].AddXP then
        xpExport = exports['bldr-drugs-core']
    end
    if xpExport and xpVal > 0 then
        xpExport:AddXP(src, xpVal)
        -- check for blueprint rewards after XP gain
        checkBlueprintRewards(src)
    end
    wildStates[wildId] = true
    notify(src, ('You harvested a wild plant and obtained %d %s (quality %d%%).'):format(amount, wild.item, quality), 'success')
end)

--[[
    Admin/testing command

    Provides a simple interface for server admins to test the farming
    system.  Use `/farmadmin` followed by a subcommand.  Only players
    with `admin` or `god` permission (via QBCore permissions) may use
    this command.  Available subcommands:

      seeds            - Gives 5x of each farming seed to the caller
      bps              - Gives one of each blueprint (weed_joint_bp and cocaine_bag_bp)
      xp <amount>      - Adds <amount> experience points to the caller
                         and checks for blueprint unlocks
      item <name> <amt> - Gives the specified item in the specified amount

    Examples:
      /farmadmin seeds
      /farmadmin bps
      /farmadmin xp 500
      /farmadmin item weed 10
]]
RegisterCommand('farmadmin', function(source, args)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    -- check permission via QBCore
    -- check BLDR admin permissions (fallback local check if core export missing)
    if not isBLDRAdmin(src) then
        notify(src, 'No permission.', 'error')
        return
    end
    local action = args[1] and tostring(args[1]):lower() or ''
    if action == 'seeds' or action == 'seed' then
        local seeds = { 'weed_seed', 'coca_seed', 'poppy_seed', 'lavender_seed' }
        for _, item in ipairs(seeds) do
            AddItem(src, item, 5)
        end
        notify(src, 'Admin: You have been given farming seeds.', 'success')
    elseif action == 'bps' or action == 'blueprints' or action == 'bp' then
        local bps = { 'weed_joint_bp', 'cocaine_bag_bp' }
        for _, item in ipairs(bps) do
            AddItem(src, item, 1)
        end
        notify(src, 'Admin: You have been given blueprint items.', 'success')
    elseif action == 'xp' then
        local amount = tonumber(args[2] or '0') or 0
        if amount <= 0 then
            notify(src, 'Usage: /farmadmin xp <amount>', 'error')
            return
        end
        local xpExport = nil
        if exports['bldr-core'] and exports['bldr-core'].AddXP then
            xpExport = exports['bldr-core']
        elseif exports['bldr-drugs-core'] and exports['bldr-drugs-core'].AddXP then
            xpExport = exports['bldr-drugs-core']
        end
        if xpExport then
            xpExport:AddXP(src, amount)
            -- check blueprint unlocks immediately
            checkBlueprintRewards(src)
            notify(src, ('Admin: Added %d XP.'):format(amount), 'success')
        else
            notify(src, 'Admin: XP export unavailable.', 'error')
        end
    elseif action == 'item' then
        local itemName = args[2] and tostring(args[2]):lower() or ''
        local count    = tonumber(args[3] or '1') or 1
        if itemName == '' then
            notify(src, 'Usage: /farmadmin item <name> <amount>', 'error')
            return
        end
        AddItem(src, itemName, count)
        notify(src, ('Admin: Given %d x %s.'):format(count, itemName), 'success')
    else
        notify(src, 'Invalid subcommand. Use seeds, bps, xp, or item.', 'error')
    end
end, false)

-- 🌾 FARMING TEST & ADMIN COMMANDS

-- Give seeds to player
RegisterCommand('giveseeds', function(source, args, rawCommand)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not isBLDRAdmin(src) then
        notify(src, '❌ Permission Denied | Admin only', 'error')
        return
    end
    
    local seedType = args[1] or 'weed_seed'
    local amount = tonumber(args[2]) or 10
    
    AddItem(src, seedType, amount)
    notify(src, string.format('🌱 Given %dx %s', amount, seedType), 'success')
end, false)

-- Force plant to mature
RegisterCommand('matureplant', function(source, args, rawCommand)
    local src = source
    
    if not isBLDRAdmin(src) then
        notify(src, '❌ Permission Denied | Admin only', 'error')
        return
    end
    
    local farmId = tonumber(args[1])
    
    if not farmId or not farmStates[farmId] then
        notify(src, '❌ Invalid Farm ID', 'error')
        return
    end
    
    if farmStates[farmId].state ~= 'growing' then
        notify(src, '❌ Farm plot is not growing', 'error')
        return
    end
    
    farmStates[farmId].readyTime = os.time() - 1
    farmStates[farmId].state = 'ready'
    
    TriggerClientEvent('bldr_farming:updatePlantVisual', -1, farmId, 'ready', 100, farmStates[farmId].plantItem)
    notify(src, string.format('🌾 Farm Plot %d | Plant matured instantly', farmId), 'success')
    
    print(string.format('[BLDR Farming] Admin %s matured farm plot %d', GetPlayerName(src), farmId))
end, false)

-- Reset farm plot
RegisterCommand('resetfarm', function(source, args, rawCommand)
    local src = source
    
    if not isBLDRAdmin(src) then
        notify(src, '❌ Permission Denied | Admin only', 'error')
        return
    end
    
    local farmId = tonumber(args[1])
    
    if not farmId or not Config.Farms[farmId] then
        notify(src, '❌ Invalid Farm ID', 'error')
        return
    end
    
    farmStates[farmId] = { state = 'empty', water = Config.Water.maxWater, plantItem = nil }
    
    TriggerClientEvent('bldr_farming:updatePlantVisual', -1, farmId, 'empty', 0, nil)
    notify(src, string.format('🛠️ Farm Plot %d | Reset to empty', farmId), 'success')
    
    print(string.format('[BLDR Farming] Admin %s reset farm plot %d', GetPlayerName(src), farmId))
end, false)

-- Check farm status
RegisterCommand('checkfarm', function(source, args, rawCommand)
    local src = source
    
    if not isBLDRAdmin(src) then
        notify(src, '❌ Permission Denied | Admin only', 'error')
        return
    end
    
    local farmId = tonumber(args[1])
    
    if not farmId or not farmStates[farmId] then
        notify(src, '❌ Invalid Farm ID', 'error')
        return
    end
    
    local farm = farmStates[farmId]
    local statusMsg = string.format(
        '📊 Farm Plot %d Status:\n' ..
        'State: %s\n' ..
        'Plant: %s\n' ..
        'Water: %d%%\n' ..
        'Fertilized: %s\n' ..
        'Owner: %s',
        farmId,
        farm.state or 'unknown',
        farm.plantItem or 'none',
        farm.water or 0,
        farm.fertilized or 'no',
        farm.ownerId or 'none'
    )
    
    notify(src, statusMsg, 'primary', 8000)
    print(string.format('[BLDR Farming] Admin %s checked farm %d: %s', GetPlayerName(src), farmId, farm.state))
end, false)

-- List all active farms
RegisterCommand('listfarms', function(source, args, rawCommand)
    local src = source
    
    if not isBLDRAdmin(src) then
        notify(src, '❌ Permission Denied | Admin only', 'error')
        return
    end
    
    local activeCount = 0
    local growingCount = 0
    local readyCount = 0
    
    for farmId, farm in pairs(farmStates) do
        if farm.state ~= 'empty' then
            activeCount = activeCount + 1
            if farm.state == 'growing' then
                growingCount = growingCount + 1
            elseif farm.state == 'ready' then
                readyCount = readyCount + 1
            end
        end
    end
    
    local statusMsg = string.format(
        '🏞️ Farm Status Report:\n' ..
        'Total Plots: %d\n' ..
        'Active: %d\n' ..
        'Growing: %d\n' ..
        'Ready: %d',
        #Config.Farms,
        activeCount,
        growingCount,
        readyCount
    )
    
    notify(src, statusMsg, 'primary', 6000)
    print('[BLDR Farming] Farm status:', activeCount, 'active,', growingCount, 'growing,', readyCount, 'ready')
end, false)

print('[BLDR Farming] 🛠️ Admin commands loaded: /giveseeds, /matureplant, /resetfarm, /checkfarm, /listfarms')