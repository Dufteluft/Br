-- Battle Royale Item Database Schema
-- Version 1.0

-- This SQL schema is a reference for a potential database integration.
-- It is not directly used by the Lua scripts at this stage but provides
-- a structure for defining items if a database is implemented later.

CREATE TABLE IF NOT EXISTS `battle_royale_items` (
  `item_identifier` VARCHAR(50) NOT NULL, -- Unique identifier (e.g., "weapon_pistol", "medikit_small")
  `label` VARCHAR(100) NOT NULL,           -- Display name for UI (e.g., "Pistol", "Small Medikit")
  `type` VARCHAR(30) NOT NULL,             -- Item type (e.g., "weapon", "consumable", "ammo", "armour_item")
  `description` TEXT DEFAULT NULL,         -- Short description of the item
  `image_path` VARCHAR(255) DEFAULT NULL,  -- Path to a UI icon (e.g., "nui://br_inventory/html/img/pistol.png")
  `weight` FLOAT DEFAULT 0,                -- Item weight (for inventory systems)
  `max_stack` INT DEFAULT 1,               -- Maximum stack size in inventory
  `usable` BOOLEAN DEFAULT TRUE,           -- Can the item be used?
  `removable` BOOLEAN DEFAULT TRUE,        -- Can the item be dropped/discarded?
  `data` JSON DEFAULT NULL,                -- JSON string for item-specific data:
                                           -- For weapons: { "hash": "WEAPON_PISTOL_HASH", "default_ammo": 30, "ammo_type": "AMMO_PISTOL" }
                                           -- For consumables: { "effect": "heal", "amount": 50 } or { "effect": "armour", "amount": 50 }
                                           -- For ammo: { "ammo_type_native": "AMMO_PISTOL", "for_weapon_group": "pistol" }
                                           -- (for_weapon_group can be used to identify compatible weapons)
  PRIMARY KEY (`item_identifier`)
);

-- Example INSERT statements:

INSERT INTO `battle_royale_items`
  (`item_identifier`, `label`, `type`, `description`, `image_path`, `weight`, `max_stack`, `usable`, `data`)
VALUES
  ('weapon_pistol', 'Pistole', 'weapon', 'Standard-Pistole.', 'img/weapon_pistol.png', 1.0, 1, true, JSON_OBJECT('hash', 'WEAPON_PISTOL', 'default_ammo', 12, 'ammo_type', 'ammo_pistol')),
  ('weapon_smg', 'SMG', 'weapon', 'Maschinenpistole.', 'img/weapon_smg.png', 1.5, 1, true, JSON_OBJECT('hash', 'WEAPON_SMG', 'default_ammo', 30, 'ammo_type', 'ammo_smg')),
  ('medikit_small', 'Kleines Medikit', 'consumable', 'Stellt 50 HP wieder her.', 'img/medikit_small.png', 0.3, 5, true, JSON_OBJECT('effect', 'heal', 'amount', 50)),
  ('medikit_large', 'Großes Medikit', 'consumable', 'Stellt 100 HP wieder her.', 'img/medikit_large.png', 0.6, 3, true, JSON_OBJECT('effect', 'heal', 'amount', 100)),
  ('armour_small', 'Kleine Weste', 'consumable', 'Gibt 50 Rüstung.', 'img/armour_small.png', 0.8, 3, true, JSON_OBJECT('effect', 'armour', 'amount', 50)),
  ('armour_large', 'Große Weste', 'consumable', 'Gibt 100 Rüstung.', 'img/armour_large.png', 1.2, 2, true, JSON_OBJECT('effect', 'armour', 'amount', 100)),
  ('ammo_pistol', 'Pistolenmunition', 'ammo', 'Munition für Pistolen.', 'img/ammo_pistol.png', 0.2, 200, false, JSON_OBJECT('ammo_type_native', 'AMMO_PISTOL', 'quantity_per_pickup', 24)),
  ('ammo_smg', 'SMG-Munition', 'ammo', 'Munition für SMGs.', 'img/ammo_smg.png', 0.2, 250, false, JSON_OBJECT('ammo_type_native', 'AMMO_SMG', 'quantity_per_pickup', 30)),
  ('ammo_rifle', 'Gewehrsmunition', 'ammo', 'Munition für Gewehre.', 'img/ammo_rifle.png', 0.25, 180, false, JSON_OBJECT('ammo_type_native', 'AMMO_RIFLE', 'quantity_per_pickup', 30)),
  ('ammo_shotgun', 'Schrotflintenmunition', 'ammo', 'Munition für Schrotflinten.', 'img/ammo_shotgun.png', 0.3, 60, false, JSON_OBJECT('ammo_type_native', 'AMMO_SHOTGUN', 'quantity_per_pickup', 8));

-- Note: `image_path` examples are relative and would need a proper NUI setup or an image hosting solution.
-- The `data` field uses JSON_OBJECT for MySQL/MariaDB. Syntax might vary for other SQL databases.
-- For SQLite, you would typically store JSON as TEXT.
-- The weapon hashes in `data` should be the actual integer hashes (e.g., `GetHashKey("WEAPON_PISTOL")` in Lua would give the integer).
-- For simplicity, string placeholders are used here in the example INSERTs for weapon hashes.
-- Ammo types in `data` for weapons should match `item_identifier` of corresponding ammo items for easier lookup.
-- `ammo_type_native` for ammo items refers to the native ammo type used by FiveM/GTA.
