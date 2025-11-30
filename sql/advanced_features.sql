-- Advanced Farming Features Database Migration
-- This script adds tables for the new advanced farming systems

-- 🏠 Greenhouse Management
CREATE TABLE IF NOT EXISTS `bldr_greenhouses` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `player_id` varchar(50) NOT NULL,
  `coords` text NOT NULL,
  `size` text NOT NULL,
  `plots` int(11) DEFAULT 0,
  `benefits` text DEFAULT NULL,
  `purchase_date` timestamp DEFAULT CURRENT_TIMESTAMP,
  `last_maintenance` timestamp DEFAULT CURRENT_TIMESTAMP,
  `maintenance_cost` int(11) DEFAULT 0,
  `greenhouse_type` varchar(50) DEFAULT 'basic',
  PRIMARY KEY (`id`),
  KEY `player_id` (`player_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 💧 Irrigation Systems
CREATE TABLE IF NOT EXISTS `bldr_irrigation` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `plot_id` varchar(100) NOT NULL,
  `player_id` varchar(50) NOT NULL,
  `system_type` varchar(50) NOT NULL, -- sprinkler, drip, hydroponic
  `efficiency` decimal(3,2) DEFAULT 1.00,
  `installation_date` timestamp DEFAULT CURRENT_TIMESTAMP,
  `last_maintenance` timestamp DEFAULT CURRENT_TIMESTAMP,
  `maintenance_interval` bigint(20) DEFAULT 604800000, -- 7 days in ms
  `maintenance_cost` int(11) DEFAULT 0,
  `is_active` boolean DEFAULT true,
  PRIMARY KEY (`id`),
  UNIQUE KEY `plot_id` (`plot_id`),
  KEY `player_id` (`player_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 🔄 Crop Rotation History
CREATE TABLE IF NOT EXISTS `bldr_crop_rotation` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `plot_id` varchar(100) NOT NULL,
  `player_id` varchar(50) NOT NULL,
  `crop_type` varchar(50) NOT NULL,
  `crop_family` varchar(50) DEFAULT NULL,
  `plant_date` timestamp DEFAULT CURRENT_TIMESTAMP,
  `harvest_date` timestamp NULL DEFAULT NULL,
  `soil_health` decimal(3,2) DEFAULT 1.00,
  `yield_amount` int(11) DEFAULT 0,
  `rotation_bonus` decimal(3,2) DEFAULT 1.00,
  PRIMARY KEY (`id`),
  KEY `plot_id` (`plot_id`),
  KEY `player_id` (`player_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 🌱 Plant Breeding & Genetics
CREATE TABLE IF NOT EXISTS `bldr_plant_genetics` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `player_id` varchar(50) NOT NULL,
  `plant_type` varchar(50) NOT NULL,
  `parent1_id` int(11) DEFAULT NULL,
  `parent2_id` int(11) DEFAULT NULL,
  `traits` text NOT NULL, -- JSON encoded traits
  `rarity` enum('common','uncommon','rare','epic','legendary') DEFAULT 'common',
  `generation` int(11) DEFAULT 1,
  `created_date` timestamp DEFAULT CURRENT_TIMESTAMP,
  `is_active` boolean DEFAULT true,
  PRIMARY KEY (`id`),
  KEY `player_id` (`player_id`),
  KEY `plant_type` (`plant_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 🏭 Automation Systems
CREATE TABLE IF NOT EXISTS `bldr_automation` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `player_id` varchar(50) NOT NULL,
  `machine_type` varchar(50) NOT NULL, -- autoHarvester, soilAnalyzer, climateDome
  `coords` text NOT NULL,
  `range_covered` decimal(5,2) DEFAULT 0.00,
  `efficiency` decimal(3,2) DEFAULT 1.00,
  `energy_cost` int(11) DEFAULT 0,
  `purchase_date` timestamp DEFAULT CURRENT_TIMESTAMP,
  `last_maintenance` timestamp DEFAULT CURRENT_TIMESTAMP,
  `is_active` boolean DEFAULT true,
  PRIMARY KEY (`id`),
  KEY `player_id` (`player_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 📈 Market System
CREATE TABLE IF NOT EXISTS `bldr_market_prices` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `item_name` varchar(50) NOT NULL,
  `base_price` decimal(10,2) NOT NULL,
  `current_price` decimal(10,2) NOT NULL,
  `supply_level` int(11) DEFAULT 100,
  `demand_level` int(11) DEFAULT 100,
  `last_update` timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `price_history` text DEFAULT NULL, -- JSON array of price changes
  PRIMARY KEY (`id`),
  UNIQUE KEY `item_name` (`item_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 🤝 Cooperation System
CREATE TABLE IF NOT EXISTS `bldr_farming_coops` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `coop_name` varchar(100) NOT NULL,
  `leader_id` varchar(50) NOT NULL,
  `members` text NOT NULL, -- JSON array of member IDs
  `shared_plots` text DEFAULT NULL, -- JSON array of plot IDs
  `profit_sharing` text NOT NULL, -- JSON config
  `created_date` timestamp DEFAULT CURRENT_TIMESTAMP,
  `is_active` boolean DEFAULT true,
  PRIMARY KEY (`id`),
  KEY `leader_id` (`leader_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 🎯 Achievements System
CREATE TABLE IF NOT EXISTS `bldr_achievements` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `player_id` varchar(50) NOT NULL,
  `achievement_id` varchar(100) NOT NULL,
  `category` varchar(50) NOT NULL,
  `progress` int(11) DEFAULT 0,
  `completed` boolean DEFAULT false,
  `completion_date` timestamp NULL DEFAULT NULL,
  `rewards_claimed` boolean DEFAULT false,
  PRIMARY KEY (`id`),
  UNIQUE KEY `player_achievement` (`player_id`,`achievement_id`),
  KEY `player_id` (`player_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 📊 Analytics Data
CREATE TABLE IF NOT EXISTS `bldr_farming_analytics` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `player_id` varchar(50) NOT NULL,
  `metric_type` varchar(50) NOT NULL, -- harvest_yield, crop_quality, etc.
  `metric_value` decimal(10,2) NOT NULL,
  `context_data` text DEFAULT NULL, -- JSON additional data
  `recorded_date` timestamp DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `player_id` (`player_id`),
  KEY `metric_type` (`metric_type`),
  KEY `recorded_date` (`recorded_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Insert default market prices
INSERT IGNORE INTO `bldr_market_prices` (`item_name`, `base_price`, `current_price`) VALUES
('tomato', 8.00, 8.00),
('potato', 5.00, 5.00),
('corn', 6.00, 6.00),
('wheat', 4.00, 4.00),
('carrot', 7.00, 7.00),
('lettuce', 9.00, 9.00),
('onion', 6.00, 6.00),
('pepper', 12.00, 12.00),
('golden_tomato', 50.00, 50.00),
('crystal_corn', 75.00, 75.00),
('rainbow_pepper', 100.00, 100.00),
('giant_pumpkin', 150.00, 150.00),
('healing_herb', 200.00, 200.00),
('energy_fruit', 300.00, 300.00);

-- Success message
SELECT 'Advanced Farming Features database migration completed successfully!' AS message;