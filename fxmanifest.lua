-- fxmanifest.lua for bldr_farming
-- This resource adds simple farming functionality that hooks into
-- bldr_drugs_core (or bldr_core) to award experience points.  Players
-- can plant seeds at designated plots and harvest the resulting crop
-- after a configurable growth time.  The script uses qb-target and
-- QBCore for interactions.

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'bldr_farming'
description 'Simple farming system for BLDR'
author 'blakethepet'

dependencies {
    'bldr_core',
    'qb-core',
    'qb-target'
}

shared_script 'config.lua'

client_scripts {
    'client/main.lua'
}

server_scripts {
    'config_test.lua', -- Temporary config validation
    'server/main.lua'
}

-- Removed ui_page and files since we're using ox_lib context menus instead

-- files {
--     'html/index.html',
--     'html/images/coca_seed.png',
--     'html/images/pesticide.png',
--     'html/images/poppy_seed.png',
--     'html/images/water_can.png',
--     'html/images/weed_seed.png',
--     'html/images/weed_seed_large.png'
-- }
