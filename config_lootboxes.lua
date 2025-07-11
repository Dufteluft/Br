-- config_lootboxes.lua

Config = Config or {}

Config.LootboxModel = GetHashKey("prop_box_ammo04a") -- Standardmodell für Lootboxen

-- Definiere hier deine festen Lootbox-Positionen
Config.Lootboxes = {
    {
        id = "sandy_gasstation_1",
        coords = vector4(1970.0, 3815.0, 33.0, 90.0), -- x, y, z, heading (Z sollte die Bodenhöhe sein)
        lootProfile = "default_medium"
    },
    {
        id = "sandy_airfield_hangar_1",
        coords = vector4(2128.88, 5600.73, 45.5, 180.0),
        lootProfile = "military_medium"
    },
    {
        id = "sandy_motel_rooftop_1",
        coords = vector4(2677.11, 3270.89, 56.22, 270.0), -- Beispiel auf einem Dach
        lootProfile = "rare_items"
    },
    -- Füge hier weitere Lootbox-Positionen hinzu
    -- Beispiel für die vom Benutzer angegebene Koordinate:
    {
        id = "user_custom_1",
        coords = vector4(2455.6223, 5616.9907, 44.9625, 199.2080),
        lootProfile = "default_medium"
    }
}

-- Definiere hier Loot-Profile (was kann in einer Box eines bestimmten Typs gefunden werden)
Config.LootProfiles = {
    ["default_medium"] = {
        -- Jedes Item hat eine Chance, zu spawnen. Die Box wird mit Config.ItemsPerBox.min/max Items gefüllt.
        { itemName = "WEAPON_PISTOL", displayName = "Pistol", iconUrl = "img/icons/pistol.png", type = "weapon", ammo = 24, quantityMin = 1, quantityMax = 1, chance = 0.6 },
        { itemName = "medikit_small", displayName = "Small Medkit", iconUrl = "img/icons/medkit_small.png", type = "consumable", heal = 50, quantityMin = 1, quantityMax = 2, chance = 0.8 },
        { itemName = "armour_small", displayName = "Small Armour", iconUrl = "img/icons/armour_small.png", type = "consumable", armour = 50, quantityMin = 1, quantityMax = 1, chance = 0.7 },
        { itemName = "ammo_pistol", displayName = "Pistol Ammo", iconUrl = "img/icons/ammo_pistol.png", type = "ammo", forWeapon = "WEAPON_PISTOL", quantityMin = 20, quantityMax = 40, chance = 0.5 },
        { itemName = "ammo_smg", displayName = "SMG Ammo", iconUrl = "img/icons/ammo_smg.png", type = "ammo", forWeapon = "WEAPON_SMG", quantityMin = 30, quantityMax = 60, chance = 0.3 },
    },
    ["military_medium"] = {
        { itemName = "WEAPON_SMG", displayName = "SMG", iconUrl = "img/icons/smg.png", type = "weapon", ammo = 60, quantityMin = 1, quantityMax = 1, chance = 0.7 },
        { itemName = "WEAPON_CARBINERIFLE", displayName = "Carbine Rifle", iconUrl = "img/icons/carbinerifle.png", type = "weapon", ammo = 90, quantityMin = 1, quantityMax = 1, chance = 0.4 },
        { itemName = "armour_large", displayName = "Large Armour", iconUrl = "img/icons/armour_large.png", type = "consumable", armour = 100, quantityMin = 1, quantityMax = 1, chance = 0.5 },
        { itemName = "medikit_large", displayName = "Large Medkit", iconUrl = "img/icons/medkit_large.png", type = "consumable", heal = 100, quantityMin = 1, quantityMax = 1, chance = 0.3 },
        { itemName = "ammo_rifle", displayName = "Rifle Ammo", iconUrl = "img/icons/ammo_rifle.png", type = "ammo", forWeapon = "WEAPON_CARBINERIFLE", quantityMin = 60, quantityMax = 120, chance = 0.6 },
    },
    ["rare_items"] = {
        { itemName = "WEAPON_SNIPERRIFLE", displayName = "Sniper Rifle", iconUrl = "img/icons/sniperrifle.png", type = "weapon", ammo = 10, quantityMin = 1, quantityMax = 1, chance = 0.3 },
        { itemName = "WEAPON_ADVANCEDRIFLE", displayName = "Advanced Rifle", iconUrl = "img/icons/advancedrifle.png", type = "weapon", ammo = 120, quantityMin = 1, quantityMax = 1, chance = 0.2 },
        { itemName = "armour_large", displayName = "Large Armour", iconUrl = "img/icons/armour_large.png", type = "consumable", armour = 100, quantityMin = 1, quantityMax = 2, chance = 0.8 },
        { itemName = "medikit_large", displayName = "Large Medkit", iconUrl = "img/icons/medkit_large.png", type = "consumable", heal = 100, quantityMin = 1, quantityMax = 2, chance = 0.7 },
    },
    -- Füge hier 10 verschiedene Waffen hinzu, verteilt auf Profile oder in einem Waffen-spezifischen Profil
    -- WEAPON_PISTOL (bereits oben)
    -- WEAPON_SMG (bereits oben)
    -- WEAPON_PUMPSHOTGUN
    -- WEAPON_CARBINERIFLE (bereits oben)
    -- WEAPON_ASSAULTSHOTGUN
    -- WEAPON_SNIPERRIFLE (bereits oben)
    -- WEAPON_GRENADELAUNCHER
    -- WEAPON_COMBATPISTOL
    -- WEAPON_MICROSMG
    -- WEAPON_ADVANCEDRIFLE (bereits oben)
    ["weapons_common"] = {
        { itemName = "WEAPON_PUMPSHOTGUN", type = "weapon", ammo = 12, quantityMin = 1, quantityMax = 1, chance = 0.5 },
        { itemName = "WEAPON_COMBATPISTOL", type = "weapon", ammo = 36, quantityMin = 1, quantityMax = 1, chance = 0.6 },
        { itemName = "WEAPON_MICROSMG", type = "weapon", ammo = 80, quantityMin = 1, quantityMax = 1, chance = 0.4 },
    },
    ["weapons_rare"] = {
         { itemName = "WEAPON_ASSAULTSHOTGUN", type = "weapon", ammo = 16, quantityMin = 1, quantityMax = 1, chance = 0.3 },
         { itemName = "WEAPON_GRENADELAUNCHER", type = "weapon", ammo = 5, quantityMin = 1, quantityMax = 1, chance = 0.1 },
    }
}

-- Wie viele Item-Stapel sollen pro Box basierend auf dem Profil generiert werden.
Config.ItemsPerBox = {
    min = 2,
    max = 4
}

print("config_lootboxes.lua geladen.")
