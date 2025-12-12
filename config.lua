-- Configuration for bldr_farming
-- Each entry in `Farms` defines a plot where players can plant a
-- particular seed and later harvest the grown crop.  When the crop
-- is harvested the script will award XP via the bldr_core export.

Config = {}

-- System Compatibility Settings
-- The script will automatically detect which systems are available
-- You can force a specific system by setting these values
Config.Systems = {
    -- Target system: 'auto', 'ox_target', or 'qb-target'
    -- Auto will detect which is available
    target = 'auto',
    -- Inventory system: 'auto', 'ox_inventory', or 'qb-inventory'
    -- Auto will detect which is available
    inventory = 'auto'
}

-- Batch Harvesting System
Config.BatchHarvest = {
    enabled = true,
    maxDistance = 20.0,      -- Maximum distance to include plots in batch
    maxPlots = 5,            -- Maximum plots that can be harvested at once
    timePerPlot = 3000,      -- 3 seconds per plot in batch
    xpBonus = 1.2,           -- 20% XP bonus for batch harvesting
    requiredLevel = 2        -- Minimum level to unlock batch harvesting
}

-- Harvest Minigame System
Config.HarvestMinigame = {
    enabled = true,
    difficulty = 'medium',   -- 'easy', 'medium', 'hard'
    type = 'timing',         -- 'timing' or 'pattern'
    timing = {
        easy = { speed = 1.5, perfectZone = 0.3, goodZone = 0.5 },
        medium = { speed = 2.0, perfectZone = 0.2, goodZone = 0.4 },
        hard = { speed = 2.5, perfectZone = 0.1, goodZone = 0.3 }
    },
    rewards = {
        perfect = { qualityBonus = 20, yieldBonus = 0.5, xpMultiplier = 1.5 },
        good = { qualityBonus = 10, yieldBonus = 0.25, xpMultiplier = 1.2 },
        ok = { qualityBonus = 0, yieldBonus = 0, xpMultiplier = 1.0 },
        failed = { qualityBonus = -10, yieldBonus = -0.25, xpMultiplier = 0.8 }
    },
    skipOption = true  -- Allow players to skip minigame for standard rewards
}

-- Entry location for weed facility (outside entrance)
Config.WeedFacilityEntry = {
    coords = vector3(116.87, -1990.39, 17.49), -- Outside entrance
    label = 'Enter Weed Facility',
    icon = 'fas fa-door-open',
    teleportCoords = vector3(1066.06, -3183.22, -40.16) -- Interior location
}

-- Exit location for weed facility (inside exit)
Config.WeedFacilityExit = {
    coords = vector3(1066.14, -3183.33, -40.16), -- Inside exit point
    label = 'Exit Weed Facility',
    icon = 'fas fa-door-closed',
    teleportCoords = vector3(116.87, -1990.39, 17.49) -- Outside destination
}

-- List of farming plots.  You can add more entries or adjust the
-- existing coordinates.  Each plot has its own growth timer and
-- yields.  Note that growTime is in milliseconds (600000 ms = 10
-- minutes).
--[[
    Farming plots definition

    Each entry defines a plot in the world where players can plant a
    seed and later harvest the grown plant.  The fields are:
      coords      - world coordinates of the plot
      plantItem   - the seed item required to plant
      harvestItem - the item given on harvest
      growTime    - time in milliseconds from planting to ready
      amountRange - {min,max} number of items harvested
      xp          - XP awarded on harvest
      label       - display name in the UI

    You can add as many plots as you like.  To support multiple
    crops the `plantItem` and `harvestItem` fields can be set
    per‑plot.  Players must meet the level requirement (see
    Config.LevelUnlocks) to plant higher tier seeds.
]]
Config.Farms = {
    -- Weed plot cluster (basic crop) - Multiple plots in Paleto Forest hidden grow area
    {
        -- Paleto Forest hidden grow area - Plot 1 (main)
        coords      = vector3(2211.73, 5577.62, 53.83),
        plantItem   = 'weed_seed',
        harvestItem = 'weed',
        growTime    = 600000, -- 10 minutes
        amountRange = {1, 3},
        xp          = 10,
        label       = 'Weed Plot 1'
    },
    {
        -- Paleto Forest hidden grow area - Plot 2 (nearby)
        coords      = vector3(2213.45, 5579.12, 53.75),
        plantItem   = 'weed_seed',
        harvestItem = 'weed',
        growTime    = 600000, -- 10 minutes
        amountRange = {1, 3},
        xp          = 10,
        label       = 'Weed Plot 2'
    },
    {
        -- Paleto Forest hidden grow area - Plot 3 (spread out)
        coords      = vector3(2209.89, 5575.34, 53.91),
        plantItem   = 'weed_seed',
        harvestItem = 'weed',
        growTime    = 600000, -- 10 minutes
        amountRange = {1, 3},
        xp          = 10,
        label       = 'Weed Plot 3'
    },
    {
        -- Paleto Forest hidden grow area - Plot 4 (corner)
        coords      = vector3(2215.21, 5576.88, 53.69),
        plantItem   = 'weed_seed',
        harvestItem = 'weed',
        growTime    = 600000, -- 10 minutes
        amountRange = {1, 3},
        xp          = 10,
        label       = 'Weed Plot 4'
    },
    {
        -- Paleto Forest hidden grow area - Plot 5 (back area)
        coords      = vector3(2208.67, 5580.45, 53.88),
        plantItem   = 'weed_seed',
        harvestItem = 'weed',
        growTime    = 600000, -- 10 minutes
        amountRange = {1, 3},
        xp          = 10,
        label       = 'Weed Plot 5'
    },
    -- Coca plot (mid tier crop)
    {
        -- Updated location: remote grove near Chiliad trail
        coords      = vector3(284.99, 6471.84, 30.47),
        plantItem   = 'coca_seed',
        harvestItem = 'cocaine',
        growTime    = 900000, -- 15 minutes
        amountRange = {1, 2},
        xp          = 20,
        label       = 'Coca Field'
    },
    -- Poppy plot (high tier crop)
    {
        -- Updated location: secluded field outside Grapeseed
        coords      = vector3(2463.77, 4843.56, 36.45),
        plantItem   = 'poppy_seed',
        harvestItem = 'heroin',
        growTime    = 900000,
        amountRange = {1, 2},
        xp          = 30,
        label       = 'Poppy Patch'
    },
    -- Lavender plot (legal high tier crop)
    {
        -- A legal crop that unlocks at a higher farming level
        coords      = vector3(2059.56, 4859.32, 41.71),
        plantItem   = 'lavender_seed',
        harvestItem = 'lavender',
        growTime    = 600000, -- 10 minutes
        amountRange = {1, 3},
        xp          = 15,
        label       = 'Lavender Field'
    }
}

-- Advanced farming mechanics configuration
Config.Water = {
    enabled       = true,       -- enable or disable the watering mechanic
    maxWater      = 5,          -- maximum water units a freshly planted crop starts with
    decayInterval = 120000,     -- interval (ms) at which water decays by `decayAmount`
    decayAmount   = 1,          -- how much water is lost every decay interval
    waterItem     = 'water_can',-- item used to water plants
    addAmount     = 3           -- amount of water restored per watering action
}

-- Plant disease system
Config.Disease = {
    enabled       = true,       -- enable disease system
    chancePerHour = 0.05,       -- 5% chance per hour for disease
    diseaseTypes  = {
        blight = {
            name = 'Blight',
            description = 'A fungal infection affecting plant growth',
            yieldReduction = 0.5,  -- 50% yield reduction
            cureItem = 'fungicide'
        },
        aphids = {
            name = 'Aphid Infestation',
            description = 'Insects damaging the plant',
            yieldReduction = 0.3,  -- 30% yield reduction
            cureItem = 'pesticide'
        }
    }
}

-- Fertilizer system
Config.Fertilizer = {
    enabled = true,
    types = {
        basic_fertilizer = {
            growthBonus = 0.2,     -- 20% faster growth
            yieldBonus = 0.1,      -- 10% more yield
            qualityBonus = 5       -- +5 quality points
        },
        premium_fertilizer = {
            growthBonus = 0.4,     -- 40% faster growth
            yieldBonus = 0.25,     -- 25% more yield
            qualityBonus = 15      -- +15 quality points
        }
    }
}

-- Weather effects on farming
Config.Weather = {
    enabled = true,
    effects = {
        rain = { growthBonus = 0.1, waterBonus = 1 },      -- Rain helps growth
        sun = { qualityBonus = 5 },                         -- Sun improves quality
        storm = { damageChance = 0.15 },                    -- Storms can damage plants
        drought = { waterLoss = 2 }                         -- Drought increases water loss
    }
}

-- Wild plants spawn in the world ready to harvest without planting.  After
-- harvesting they do not respawn until the next server restart.  Each
-- entry defines the coordinates, the item harvested and the amount
-- awarded.  XP will be granted according to the entry's xp value.
Config.WildPlants = {
    -- example weed plants near Paleto Bay
    {
        coords  = vector3(-2180.4, 5200.1, 17.0),
        item    = 'weed',
        amount  = {1, 3}, -- random range of harvested amount
        xp      = 5,
        label   = 'Wild Weed'
    },
    {
        coords  = vector3(-2175.2, 5195.3, 17.1),
        item    = 'weed',
        amount  = {1, 2},
        xp      = 4,
        label   = 'Wild Weed'
    }
}

-- Market configuration.  A simple market where players can purchase seeds,
-- water cans and sell harvested items.  Prices fluctuate slightly based
-- on supply and demand: when an item is bought the price increases by
-- `priceAdjust` percent, and when an item is sold the price decreases by
-- the same factor.  Each item entry contains a current price and a base
-- price used as a floor to prevent prices from collapsing.  You can
-- define separate buy and sell entries if the item has different
-- behaviour for purchasing and selling.
Config.Market = {
    -- Mountain Fresh Market (Paleto Bay)
    coords = vector3(1729.23, 6415.27, 35.04),
    priceAdjust = 0.05, -- 5% price change on buy/sell
    items = {
        -- seeds and supplies
        weed_seed = {
            label      = 'Weed Seed',
            price      = 50,
            basePrice  = 40,
            type       = 'buy',
            minLevel   = 0
        },
        coca_seed = {
            label      = 'Coca Seed',
            price      = 80,
            basePrice  = 60,
            type       = 'buy',
            minLevel   = 2 -- unlocked at level 2
        },
        poppy_seed = {
            label      = 'Poppy Seed',
            price      = 100,
            basePrice  = 80,
            type       = 'buy',
            minLevel   = 4 -- unlocked at level 4
        },
        water_can = {
            label      = 'Water Can',
            price      = 10,
            basePrice  = 8,
            type       = 'buy',
            minLevel   = 0
        },
        pesticide = {
            label      = 'Pesticide',
            price      = 30,
            basePrice  = 20,
            type       = 'buy',
            minLevel   = 1
        },
        basic_fertilizer = {
            label      = 'Basic Fertilizer',
            price      = 40,
            basePrice  = 30,
            type       = 'buy',
            minLevel   = 1
        },
        premium_fertilizer = {
            label      = 'Premium Fertilizer',
            price      = 80,
            basePrice  = 60,
            type       = 'buy',
            minLevel   = 3
        },
        fungicide = {
            label      = 'Fungicide',
            price      = 35,
            basePrice  = 25,
            type       = 'buy',
            minLevel   = 2
        },
        lavender_seed = {
            label      = 'Lavender Seed',
            price      = 90,
            basePrice  = 70,
            type       = 'buy',
            minLevel   = 5 -- unlocked at level 5
        },
        -- selling produce
        weed = {
            label     = 'Weed',
            price     = 20,
            basePrice = 10,
            type      = 'sell',
            minLevel  = 0
        },
        weed_bag = {
            label     = 'Bag of Weed',
            price     = 60,
            basePrice = 40,
            type      = 'sell',
            minLevel  = 0
        },
        cocaine = {
            label     = 'Coca Leaves',
            price     = 40,
            basePrice = 30,
            type      = 'sell',
            minLevel  = 0
        },
        cocaine_bag = {
            label     = 'Bag of Cocaine',
            price     = 120,
            basePrice = 80,
            type      = 'sell',
            minLevel  = 0
        },
        heroin = {
            label     = 'Heroin',
            price     = 160,
            basePrice = 120,
            type      = 'sell',
            minLevel  = 0
        },
        lavender = {
            label     = 'Lavender',
            price     = 40,
            basePrice = 30,
            type      = 'sell',
            minLevel  = 0
        }
    }
}

-- Seasonal farming effects
Config.Seasons = {
    enabled = true,
    length = 7, -- days per season (real time)
    effects = {
        spring = {
            growthBonus = 0.15,    -- 15% faster growth
            diseaseResistance = 0.1, -- 10% disease resistance
            description = "Perfect growing conditions"
        },
        summer = {
            yieldBonus = 0.2,      -- 20% more yield
            waterLoss = 1.5,       -- 50% more water consumption
            description = "High yield but needs more water"
        },
        autumn = {
            qualityBonus = 10,     -- +10 quality
            growthPenalty = 0.1,   -- 10% slower growth
            description = "Better quality but slower growth"
        },
        winter = {
            growthPenalty = 0.3,   -- 30% slower growth
            diseaseChance = 0.5,   -- 50% more disease chance
            description = "Harsh conditions for growing"
        }
    }
}

-- Quality system for plants and harvests
Config.Quality = {
    enabled = true,
    factors = {
        water = { min = 0.5, max = 1.0 },      -- Water level affects quality
        fertilizer = { bonus = 0.2 },           -- Fertilizer improves quality
        care = { bonus = 0.1 },                 -- Regular tending improves quality
        disease = { penalty = 0.4 },            -- Disease reduces quality
        weather = { variance = 0.15 }           -- Weather creates variance
    },
    grades = {
        poor = { min = 0, max = 30, multiplier = 0.7, label = "Poor Quality" },
        average = { min = 31, max = 60, multiplier = 1.0, label = "Average Quality" },
        good = { min = 61, max = 80, multiplier = 1.3, label = "Good Quality" },
        excellent = { min = 81, max = 95, multiplier = 1.6, label = "Excellent Quality" },
        perfect = { min = 96, max = 100, multiplier = 2.0, label = "Perfect Quality" }
    }
}

-- Level unlocks for seeds or other farming items.  Players must reach
-- at least the specified level (via bldr_core/bldr_drugs_core XP
-- system) to buy or plant these seeds.  If omitted a level of 0 is
-- assumed.
Config.LevelUnlocks = {
    weed_seed  = 0,
    coca_seed  = 2,
    poppy_seed = 4,
    lavender_seed = 5,
    basic_fertilizer = 1,
    premium_fertilizer = 3,
    fungicide = 2,
    pesticide = 1
    -- additional seeds can be added here with higher levels
}

-- Chance of alerting law enforcement when harvesting illegal crops.
-- The keys should match the harvestItem values in Config.Farms.
-- A random number between 0 and 1 is compared with the chance; if
-- the number is less than the chance a police alert will be sent.
Config.PoliceAlert = {
    weed    = 0.10, -- 10% chance when harvesting weed
    cocaine = 0.40, -- 40% chance when harvesting coca leaves
    heroin  = 0.50  -- 50% chance when harvesting poppy/ heroin
}

-- Visual plant system configuration
Config.PlantVisuals = {
    enabled = true,                    -- Enable/disable visual plants
    updateInterval = 120000,           -- Update plant growth visuals every 2 minutes
    minScale = 0.2,                   -- Minimum plant size (20% of full size)
    maxScale = 1.0,                   -- Maximum plant size (100% of full size)
    useScaling = true,                -- Try to use entity scaling (disable if having issues)
    plantModels = {                   -- Plant models for different seeds
        weed_seed = 'prop_weed_01',       -- Using proper weed plant model
        coca_seed = 'prop_plant_01b',     -- Using generic plant model variant
        poppy_seed = 'prop_plant_01a',
        lavender_seed = 'prop_bush_lav_01'
    },
    -- Alternative: Different models for growth stages (if scaling doesn't work)
    growthStages = {
        weed_seed = {
            stage1 = 'prop_weed_01',      -- 0-33% growth
            stage2 = 'prop_weed_02',      -- 34-66% growth  
            stage3 = 'prop_weed_01'       -- 67-100% growth (full size)
        },
        -- You can add more crops with different growth stage models
    },
    defaultModel = 'prop_plant_01a'   -- Default model if specific one not found
}

-- � EMOTE SYSTEM - Immersive farming animations
Config.Emotes = {
    enabled = true,                   -- Enable/disable emote system
    cancelOnMove = true,              -- Cancel emotes when player moves
    showProgress = true,              -- Show progress bar during emotes
    
    -- Planting emotes
    planting = {
        dict = 'random@domestic',
        anim = 'pickup_low',
        duration = 4000,              -- 4 seconds
        progressText = 'Planting seed...',
        freezePlayer = true,
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true
    },
    
    -- Harvesting emotes
    harvesting = {
        dict = 'pickup_object',
        anim = 'pickup_low',
        duration = 3500,              -- 3.5 seconds
        progressText = 'Harvesting crop...',
        freezePlayer = true,
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true
    },
    
    -- Watering emotes
    watering = {
        dict = 'weapon@w_sp_jerrycan',
        anim = 'fire',
        duration = 3000,              -- 3 seconds
        progressText = 'Watering plant...',
        freezePlayer = true,
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true
    },
    
    -- Fertilizing emotes
    fertilizing = {
        dict = 'mp_common',
        anim = 'givetake1_a',
        duration = 2500,              -- 2.5 seconds
        progressText = 'Applying fertilizer...',
        freezePlayer = true,
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true
    }
}

-- �🏠 GREENHOUSE SYSTEM - Advanced controlled environment farming
Config.Greenhouses = {
    {
        coords = vector3(2426.5, 4969.2, 42.3),
        size = vector3(20.0, 30.0, 8.0), -- length, width, height
        plots = 12, -- number of plots inside
        benefits = {
            growthSpeedMultiplier = 1.5,
            diseaseResistance = 0.8,
            weatherProtection = true,
            yearRoundGrowing = true
        },
        requiredLevel = 5,
        purchasePrice = 50000,
        maintenanceCost = 500, -- per day
        label = 'Large Commercial Greenhouse'
    },
    {
        coords = vector3(1947.8, 3816.2, 32.1),
        size = vector3(15.0, 20.0, 6.0),
        plots = 8,
        benefits = {
            growthSpeedMultiplier = 1.3,
            diseaseResistance = 0.6,
            weatherProtection = true,
            yearRoundGrowing = false
        },
        requiredLevel = 3,
        purchasePrice = 25000,
        maintenanceCost = 250,
        label = 'Small Family Greenhouse'
    }
}

-- 🔄 CROP ROTATION SYSTEM - Soil health and yield optimization
Config.CropRotation = {
    enabled = true,
    soilDepletionRate = 0.1, -- per harvest
    rotationBonus = 1.2, -- yield multiplier for proper rotation
    familyGroups = {
        legumes = { 'soybean', 'peanut', 'clover' }, -- nitrogen fixers
        brassicas = { 'cabbage', 'broccoli', 'kale' }, -- heavy feeders
        nightshades = { 'tomato', 'potato', 'pepper' }, -- medium feeders
        grains = { 'corn', 'wheat', 'barley' }, -- soil builders
        root_vegetables = { 'carrot', 'beet', 'radish' } -- soil aerators
    },
    rotationCycles = {
        { 'legumes', 'brassicas', 'grains', 'root_vegetables' }, -- 4-year cycle
        { 'grains', 'legumes', 'nightshades' }, -- 3-year cycle
        { 'root_vegetables', 'brassicas' } -- 2-year cycle
    }
}

-- 💧 IRRIGATION SYSTEMS - Automated watering solutions
Config.Irrigation = {
    enabled = true,
    systems = {
        sprinkler = {
            name = 'Sprinkler System',
            range = 5.0, -- plots covered
            efficiency = 0.9, -- water efficiency
            automatedWatering = true,
            cost = 5000,
            maintenanceInterval = 7 * 24 * 60 * 60 * 1000, -- 7 days
            maintenanceCost = 200
        },
        drip = {
            name = 'Drip Irrigation',
            range = 3.0,
            efficiency = 0.95,
            automatedWatering = true,
            cost = 8000,
            maintenanceInterval = 14 * 24 * 60 * 60 * 1000, -- 14 days
            maintenanceCost = 150
        },
        hydroponic = {
            name = 'Hydroponic System',
            range = 2.0,
            efficiency = 1.2, -- better than water
            automatedWatering = true,
            growthBonus = 1.3,
            cost = 15000,
            maintenanceInterval = 30 * 24 * 60 * 60 * 1000, -- 30 days
            maintenanceCost = 500
        }
    }
}

-- 🌱 PLANT BREEDING SYSTEM - Genetic improvement and rare varieties
Config.Breeding = {
    enabled = true,
    crossBreedingChance = 0.15,
    mutationChance = 0.05,
    traits = {
        yield = { min = 0.8, max = 1.5 }, -- yield multiplier range
        growth_speed = { min = 0.7, max = 1.4 },
        disease_resistance = { min = 0.5, max = 0.95 },
        quality = { min = 0.9, max = 1.3 },
        water_efficiency = { min = 0.8, max = 1.2 }
    },
    rarePlants = {
        'golden_tomato', 'crystal_corn', 'rainbow_pepper',
        'giant_pumpkin', 'healing_herb', 'energy_fruit'
    },
    breedingRequirements = {
        researchPoints = 100, -- earned through successful harvests
        laboratoryLevel = 2,
        seedStorage = 'seed_vault' -- required item
    }
}

-- 🌤️ WEATHER EFFECTS SYSTEM - Dynamic environmental conditions
Config.WeatherEffects = {
    enabled = true,
    effects = {
        CLEAR = { growth = 1.0, disease = 0.1, water_loss = 1.2 },
        CLOUDS = { growth = 0.9, disease = 0.15, water_loss = 1.0 },
        RAIN = { growth = 1.1, disease = 0.25, water_loss = 0.3 },
        THUNDER = { growth = 0.8, disease = 0.35, water_loss = 0.5 },
        SMOG = { growth = 0.7, disease = 0.4, water_loss = 1.1 },
        FOGGY = { growth = 0.8, disease = 0.3, water_loss = 0.9 }
    },
    seasonalModifiers = {
        spring = { growth = 1.2, disease = 0.2 },
        summer = { growth = 1.0, disease = 0.15, water_loss = 1.5 },
        autumn = { growth = 0.9, disease = 0.3 },
        winter = { growth = 0.6, disease = 0.4, freeze_chance = 0.1 }
    }
}

-- 🏭 AUTOMATION SYSTEMS - Late-game farming technology
Config.Automation = {
    enabled = true,
    machines = {
        autoHarvester = {
            name = 'Automatic Harvester',
            range = 10.0,
            efficiency = 0.95,
            cost = 100000,
            requiredLevel = 15,
            energyCost = 50 -- per harvest
        },
        soilAnalyzer = {
            name = 'Soil Analysis Machine',
            ['function'] = 'soil_health_monitoring', -- Use quotes around reserved word
            cost = 25000,
            requiredLevel = 10,
            provides = { 'optimal_planting_suggestions', 'disease_early_warning' }
        },
        climateDome = {
            name = 'Climate Control Dome',
            range = 15.0,
            weatherImmunity = true,
            growthBonus = 1.8,
            cost = 250000,
            requiredLevel = 20,
            energyCost = 200 -- per day
        }
    }
}

-- 📈 ADVANCED MARKET & TRADING SYSTEM - Dynamic economy and player commerce
Config.AdvancedMarket = {
    enabled = true,
    priceFluctuation = {
        enabled = true,
        updateInterval = 60 * 60 * 1000, -- 1 hour
        volatility = 0.15, -- 15% max price change
        supplyDemandImpact = true
    },
    baseMarketPrices = {
        -- Basic crops
        tomato = 8, potato = 5, corn = 6, wheat = 4,
        carrot = 7, lettuce = 9, onion = 6, pepper = 12,
        -- Premium crops
        golden_tomato = 50, crystal_corn = 75, rainbow_pepper = 100,
        giant_pumpkin = 150, healing_herb = 200, energy_fruit = 300,
        -- Processed goods
        tomato_sauce = 25, wheat_flour = 15, corn_oil = 30
    },
    tradingPosts = {
        {
            coords = vector3(1692.62, 3584.85, 35.62),
            name = 'Sandy Shores Trading Post',
            specializes = { 'basic_crops' },
            priceModifier = 1.0,
            reputation = 100
        },
        {
            coords = vector3(-1109.53, 4920.16, 218.73),
            name = 'Mountain Fresh Market',
            specializes = { 'premium_crops', 'organic' },
            priceModifier = 1.25,
            reputation = 150
        },
        {
            coords = vector3(24.44, -1346.86, 29.5),
            name = 'Downtown Gourmet Exchange',
            specializes = { 'rare_varieties', 'processed_goods' },
            priceModifier = 1.5,
            reputation = 200
        }
    }
}

-- 🤝 COOPERATION SYSTEM - Shared farming and mentorship
Config.Cooperation = {
    enabled = true,
    farmingCoops = {
        maxMembers = 8,
        sharedPlots = true,
        profitSharing = {
            leader = 0.3,
            members = 0.7 -- split among all members
        },
        coopBenefits = {
            growthSpeedBonus = 1.15,
            diseaseResistance = 0.8,
            sharedKnowledge = true -- unlock recipes faster
        }
    },
    mentorship = {
        enabled = true,
        levelRequirement = 10, -- to become mentor
        mentorBenefits = {
            xpBonus = 1.2,
            teachingRewards = 50 -- per student milestone
        },
        studentBenefits = {
            learningSpeed = 1.5,
            mistakeReduction = 0.5,
            freeAdvice = true
        }
    }
}

-- 🎯 ACHIEVEMENTS & CHALLENGES - Goal-driven progression
Config.Achievements = {
    enabled = true,
    categories = {
        harvesting = {
            novice_harvester = { requirement = 50, reward = { xp = 100, money = 1000 } },
            crop_master = { requirement = 500, reward = { xp = 500, item = 'master_seeds' } },
            harvest_legend = { requirement = 2000, reward = { xp = 1000, title = 'Harvest King' } }
        },
        quality = {
            quality_seeker = { requirement = 25, condition = 'perfect_quality', reward = { xp = 200 } },
            perfectionist = { requirement = 100, condition = 'perfect_quality', reward = { item = 'golden_tools' } }
        },
        breeding = {
            genetic_engineer = { requirement = 10, condition = 'successful_crossbreeds', reward = { item = 'breeding_lab' } },
            mutation_master = { requirement = 5, condition = 'rare_mutations', reward = { title = 'Gene Wizard' } }
        },
        business = {
            entrepreneur = { requirement = 50000, condition = 'total_sales', reward = { money = 10000 } },
            market_mogul = { requirement = 500000, condition = 'total_sales', reward = { item = 'trading_license' } }
        }
    }
}

-- 📊 ANALYTICS & INSIGHTS - Performance tracking
Config.Analytics = {
    enabled = true,
    trackingMetrics = {
        'harvest_yield', 'crop_quality', 'disease_incidents',
        'water_efficiency', 'profit_margins', 'market_timing'
    },
    insights = {
        weeklyReport = true,
        monthlyAnalysis = true,
        seasonalTrends = true,
        marketPredictions = true
    }
}

-- Required dependencies.  Ensure these resources are started before
-- bldr_farming.  If you use other third‑party or input libraries you
-- can adapt the code accordingly.
Config.Dependencies = {
    qbtarget = true, -- requires qb-target for interactions
    oxlib    = true  -- requires ox_lib for input dialogs (optional)
}