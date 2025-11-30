-- Configuration test script for bldr_farming
-- This will help diagnose config loading issues

CreateThread(function()
    Wait(1000)
    
    print("=== BLDR FARMING CONFIG TEST ===")
    
    if Config then
        print("✅ Config table exists")
        
        if Config.Farms then
            print("✅ Config.Farms exists with " .. #Config.Farms .. " farms")
        else
            print("❌ Config.Farms is missing")
        end
        
        if Config.Water then
            print("✅ Config.Water exists")
        else
            print("❌ Config.Water is missing")
        end
        
        if Config.Market then
            print("✅ Config.Market exists")
        else
            print("❌ Config.Market is missing")
        end
        
        if Config.Greenhouses then
            print("✅ Config.Greenhouses exists with " .. #Config.Greenhouses .. " greenhouses")
        else
            print("❌ Config.Greenhouses is missing")
        end
        
    else
        print("❌ Config table is NIL - check config.lua for syntax errors")
    end
    
    print("=== END CONFIG TEST ===")
end)