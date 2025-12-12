# BLDR Farming

**Version:** 1.0.0  
**Author:** blakethepet  
**Framework:** QBCore  
**Database:** oxmysql

## 📋 Description

`bldr_farming` is an advanced farming system that allows players to plant seeds, maintain crops, and harvest plants for valuable resources. The system features interactive farming plots, growth timers, water management, and progression through the BLDR Core leveling system.

Perfect for roleplay servers looking to add legal or illegal farming mechanics with a rich progression system.

## ✨ Features

- **Multiple Farming Plots** - Pre-configured plots across the map for different crops
- **Crop Variety** - Weed, Coca, Poppy, and more crop types
- **Growth System** - Realistic growth timers with visual plant props
- **Water Management** - Plants require regular watering to survive
- **XP Progression** - Level up through farming activities
- **Level-Gated Crops** - Higher tier crops require higher farming levels
- **Interactive Emotes** - Realistic planting and harvesting animations
- **Visual Props** - Dynamic plant models that grow over time
- **Weather Effects** - Weather impacts crop growth rates
- **Advanced Features** - Greenhouse systems, irrigation, crop rotation
- **Police Detection** - Risk-reward system for illegal crops
- **qb-target Integration** - Smooth interaction system

## 🌱 Crop Types

| Crop | Seed Item | Harvest Item | Growth Time | XP | Required Level |
|------|-----------|--------------|-------------|-----|----------------|
| Weed | weed_seed | weed | 10 minutes | 10 | 0 |
| Coca | coca_seed | cocaine | 15 minutes | 20 | 2 |
| Poppy | poppy_seed | heroin | 15 minutes | 30 | 4 |

## 📦 Dependencies

### Required
- **bldr_core** - Core progression and XP system ⚠️ **REQUIRED**
- **qb-core** - QBCore Framework
- **qb-target** - Interaction system
- **oxmysql** - Database connector

### Optional
- **qb-progressbar** - Progress bars during actions
- **rpemotes** - Enhanced emote system

## 💾 Installation

### 1. Install Dependencies

**IMPORTANT:** Install `bldr_core` first! This resource will not work without it.

```cfg
# In your server.cfg - ORDER MATTERS!
ensure bldr_core          # Install this FIRST
ensure qb-core
ensure qb-target
ensure oxmysql
ensure bldr_farming       # Install after bldr_core
```

### 2. Database Setup

No additional database tables required - uses `bldr_core` database.

### 3. Add Items to Shared

Add these items to your `qb-core/shared/items.lua`:

```lua
-- Seeds
['weed_seed'] = {
    ['name'] = 'weed_seed',
    ['label'] = 'Weed Seed',
    ['weight'] = 50,
    ['type'] = 'item',
    ['image'] = 'weed_seed.png',
    ['unique'] = false,
    ['useable'] = false,
    ['shouldClose'] = false,
    ['description'] = 'A cannabis seed for planting'
},
['coca_seed'] = {
    ['name'] = 'coca_seed',
    ['label'] = 'Coca Seed',
    ['weight'] = 50,
    ['type'] = 'item',
    ['image'] = 'coca_seed.png',
    ['unique'] = false,
    ['useable'] = false,
    ['shouldClose'] = false,
    ['description'] = 'A coca plant seed'
},
['poppy_seed'] = {
    ['name'] = 'poppy_seed',
    ['label'] = 'Poppy Seed',
    ['weight'] = 50,
    ['type'] = 'item',
    ['image'] = 'poppy_seed.png',
    ['unique'] = false,
    ['useable'] = false,
    ['shouldClose'] = false,
    ['description'] = 'An opium poppy seed'
},

-- Harvest Items
['weed'] = {
    ['name'] = 'weed',
    ['label'] = 'Weed',
    ['weight'] = 100,
    ['type'] = 'item',
    ['image'] = 'weed.png',
    ['unique'] = false,
    ['useable'] = true,
    ['shouldClose'] = true,
    ['description'] = 'Dried cannabis'
},
['cocaine'] = {
    ['name'] = 'cocaine',
    ['label'] = 'Cocaine',
    ['weight'] = 100,
    ['type'] = 'item',
    ['image'] = 'cocaine.png',
    ['unique'] = false,
    ['useable'] = true,
    ['shouldClose'] = true,
    ['description'] = 'Processed cocaine'
},
['heroin'] = {
    ['name'] = 'heroin',
    ['label'] = 'Heroin',
    ['weight'] = 100,
    ['type'] = 'item',
    ['image'] = 'heroin.png',
    ['unique'] = false,
    ['useable'] = true,
    ['shouldClose'] = true,
    ['description'] = 'Processed heroin'
},
```

### 4. Configure Farming Plots

Edit `config.lua` to customize:
- Farming plot locations
- Growth times
- Crop yields
- XP rewards
- Level requirements

## 🔧 Configuration

### Basic Settings

```lua
Config.Farms = {
    {
        coords = vector3(2211.73, 5577.62, 53.83),
        plantItem = 'weed_seed',
        harvestItem = 'weed',
        growTime = 600000,      -- 10 minutes
        amountRange = {1, 3},   -- Harvest 1-3 items
        xp = 10,                -- XP per harvest
        label = 'Weed Plot 1'
    },
    -- Add more plots...
}
```

### Water System

```lua
Config.Water = {
    enabled = true,
    maxWater = 100,           -- Maximum water level
    decayAmount = 10,         -- Water loss per interval
    decayInterval = 120000,   -- 2 minutes
    wateringAmount = 50       -- Water added when watering
}
```

### Level Requirements

```lua
Config.LevelUnlocks = {
    weed_seed = 0,    -- Available at level 0
    coca_seed = 2,    -- Requires level 2
    poppy_seed = 4    -- Requires level 4
}
```

### Emote Settings

```lua
Config.Emotes = {
    enabled = true,
    planting = {
        dict = 'amb@world_human_gardener_plant@male@base',
        anim = 'base',
        duration = 5000
    },
    harvesting = {
        dict = 'amb@world_human_gardener_plant@male@base',
        anim = 'base',
        duration = 4000
    }
}
```

## 🎮 How to Use

### For Players

1. **Obtain Seeds** - Purchase seeds from the farming market or find them
2. **Find a Plot** - Locate farming plots (coordinates in config)
3. **Plant Seeds** - Use qb-target/ox_target on empty plots to plant
4. **Water Crops** - Return regularly to water your plants (if water system enabled)
5. **Play Minigame** - Complete the harvest minigame for quality bonuses
6. **Harvest** - Collect your grown crops and earn rewards
7. **Gain XP** - Each harvest earns XP through bldr_core
8. **Level Up** - Higher levels unlock better crops and features

### Interaction System

**Using qb-target or ox_target:**
- Look at an empty plot and press `[E]` or `[Third Eye]` to plant
- Target growing plants to:
  - Check growth progress
  - Water the plant (if needed)
  - Apply fertilizer (if available)
  - Treat disease (if infected)
- Target ready plants to harvest

### For Advanced Farmers

- **Batch Harvesting** - Harvest multiple plots at once (Level 2+)
- **Minigame Mastery** - Perfect scores give quality/yield bonuses
- **Water Management** - Plants die without regular watering
- **Disease Treatment** - Use pesticides/fungicides to cure infections
- **Fertilizer Use** - Boost growth speed and yield
- **Weather Awareness** - Rain helps growth, drought increases water loss
- **Seasonal Farming** - Different seasons affect growth rates
- **Quality System** - Proper care results in higher quality harvests
- **Greenhouse Farming** - Purchase greenhouses for protected growing
- **Irrigation Systems** - Install automated watering systems

## 📍 Default Plot Locations

### Weed Plots (Level 0)
- **Paleto Forest** - Multiple hidden plots (5 plots)
  - Remote location with natural cover
  - Coordinates: Around (2211.73, 5577.62, 53.83)

### Coca Plots (Level 2)
- **Chiliad Trail** - Remote grove
  - Coordinates: (284.99, 6471.84, 30.47)

### Poppy Plots (Level 4)
- **Grapeseed Outskirts** - Secluded field
  - Coordinates: (2463.77, 4843.56, 36.45)

## 🎮 Player Commands

### `/testminigame`
Test the harvest minigame system (client-side testing).

## 🛠️ Admin Commands

No admin commands are currently registered. Farm management is handled through:
- Server events for plot management
- Database persistence for plot states
- Automatic cleanup systems

## 🔐 Permissions

Admin commands require permission through bldr_core:
- QBCore 'god' or 'admin' permission
- ACE permission: `bldr.admin`
- License whitelist in bldr_core config

## 🌟 Advanced Features

### Greenhouse System
- Protected growing environment
- Faster growth rates
- No weather effects
- Requires ownership

### Irrigation System
- Automatic watering
- Reduces maintenance
- Costs money to operate

### Crop Rotation
- Plant different crops in sequence
- Bonus yields for rotation
- Prevents soil depletion

### Weather Effects
- Rain increases growth speed
- Sunshine improves yields
- Storms can damage crops

## 💻 For Developers

### Server Events

```lua
-- Plant a seed at a plot
TriggerEvent('bldr_farming:server:plantSeed', farmId, seedItem)

-- Harvest a plot
TriggerEvent('bldr_farming:server:harvestPlot', farmId)

-- Water a plant
TriggerEvent('bldr_farming:server:waterPlant', farmId)
```

### Client Events

```lua
-- Update plant visual
TriggerEvent('bldr_farming:client:updatePlant', farmId, state, progress)

-- Show notification
TriggerEvent('bldr_farming:client:notify', message, type)
```

### Exports

```lua
-- Get farm state
local farmState = exports['bldr_farming']:GetFarmState(farmId)

-- Check if plot is available
local available = exports['bldr_farming']:IsPlotAvailable(farmId)
```

## 🐛 Troubleshooting

### Plants Not Growing
- ✅ Check that bldr_core is installed and started
- ✅ Verify growth timers in config
- ✅ Ensure server time is synchronized

### Can't Plant Seeds
- ✅ Check you have the required level
- ✅ Verify plot is not already occupied
- ✅ Ensure you have seeds in inventory

### Plants Dying
- ✅ Water plants regularly
- ✅ Check water decay settings
- ✅ Monitor weather effects

### No XP Gain
- ✅ Ensure bldr_core is running
- ✅ Check console for errors
- ✅ Verify XP values in config

## 📊 Performance

- Optimized update intervals (5 minutes for plant growth)
- Batch processing for multiple plots (max 5 per cycle)
- Efficient visual prop management with update queue
- Cached core exports to reduce lookup overhead
- Limited visual updates per cycle (3 max)
- Water decay runs every 3 minutes
- Visual updates every 5 seconds
- Smart prop scaling and growth stage rendering

## 🎯 Commands Reference

### Player Commands

| Command | Description | Permission |
|---------|-------------|------------|
| `/testminigame` | Test the harvest minigame | Everyone |

### Server Events (For Developers)

**Planting:**
```lua
TriggerServerEvent('bldr_farming:server:plantSeed', farmId, seedItem)
```

**Harvesting:**
```lua
TriggerServerEvent('bldr_farming:server:harvestPlot', farmId)
```

**Watering:**
```lua
TriggerServerEvent('bldr_farming:server:waterPlant', farmId)
```

**Fertilizing:**
```lua
TriggerServerEvent('bldr_farming:server:applyFertilizer', farmId, fertilizerType)
```

**Disease Treatment:**
```lua
TriggerServerEvent('bldr_farming:server:treatDisease', farmId, medicineType)
```

### Client Events

**Update plant visual:**
```lua
TriggerClientEvent('bldr_farming:client:updatePlant', src, farmId, state, progress)
```

**Show notification:**
```lua
TriggerClientEvent('bldr_farming:client:notify', src, message, type)
```

### Exports

**Show harvest minigame:**
```lua
exports['bldr_farming']:ShowHarvestMinigame(difficulty, type, callback)
```

**Get farm state:**
```lua
local farmState = exports['bldr_farming']:GetFarmState(farmId)
```

**Check plot availability:**
```lua
local available = exports['bldr_farming']:IsPlotAvailable(farmId)
```

## 🔄 Integration with Other BLDR Scripts

### bldr_crafting
Harvest crops to use in crafting recipes:
- Weed → Weed bags, joints
- Cocaine → Cocaine bags
- Heroin → Heroin syringes

### bldr-drugs
Sell harvested crops through the drug dealing system for profit.

### bldr_core
- Shared XP and leveling
- Consistent progression
- Unified admin system

## 📝 License

Copyright (c) 2024-2025 Blakethepet, Negan, and BLDR CHAT

See LICENSE file for full terms. Personal use allowed, commercial use requires permission.

## 🤝 Support

For issues or questions:
1. Verify bldr_core is installed and running
2. Check server console for errors
3. Enable debug mode: `/farmingdebug`
4. Review configuration settings

## 📈 Version History

### 1.0.0
- Initial release
- Multiple crop types
- Water management system
- Visual plant props
- XP progression
- Advanced features (greenhouse, irrigation, rotation)
