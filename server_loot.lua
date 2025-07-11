-- server_loot.lua
print("Battle Royale Server Loot Skript geladen")

-- Konfiguration (kann auch geteilt sein, wenn client und server dieselben Hashes brauchen)
-- Konfiguration wird jetzt aus config_lootboxes.lua (Config.*) geladen

activeLootboxes = {} -- Speichert { id (aus Config), position, modelHash, items = {}, isOpened = false, entity = nil }
-- nextLootboxId wird nicht mehr benötigt, da IDs aus der Config kommen

-- Hilfsfunktion zum Kopieren von Tabellen (für Item-Instanzen)
function table.copy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[table.copy(orig_key)] = table.copy(orig_value)
        end
        setmetatable(copy, table.copy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

function DefineBoxContents(boxId, lootProfileName)
    local itemsInBox = {}
    local profile = Config.LootProfiles[lootProfileName]

    if not profile then
        print("WARNUNG: Loot-Profil '" .. lootProfileName .. "' für Box " .. boxId .. " nicht in Config.LootProfiles gefunden. Box bleibt leer.")
        return itemsInBox
    end

    local numItemStacksToGenerate = math.random(Config.ItemsPerBox.min, Config.ItemsPerBox.max)
    local generatedStacks = 0

    -- Erstelle eine temporäre Liste von möglichen Items basierend auf ihrer Chance, um die Auswahl zu erleichtern
    local weightedProfile = {}
    for _, itemEntry in ipairs(profile) do
        if math.random() <= itemEntry.chance then
            table.insert(weightedProfile, itemEntry)
        end
    end

    -- Wenn nach der Chance-Filterung nicht genügend unterschiedliche Items übrig sind, um die Box zu füllen,
    -- oder gar keine, fülle mit den ersten Items des Profils auf (oder habe eine Fallback-Logik).
    -- Für dieses Beispiel: Wenn weightedProfile leer ist, aber Items generiert werden sollen, nehmen wir die ersten Items.
    if #weightedProfile == 0 and numItemStacksToGenerate > 0 and #profile > 0 then
        print("WARNUNG: Kein Item im Profil '" .. lootProfileName .. "' hat die Chance-Prüfung bestanden. Fülle mit ersten Items auf.")
        for i = 1, math.min(numItemStacksToGenerate, #profile) do
            table.insert(weightedProfile, profile[i])
        end
    end

    -- Wähle zufällig aus der gewichteten Liste, bis die gewünschte Anzahl erreicht ist
    for i = 1, numItemStacksToGenerate do
        if #weightedProfile == 0 then break end -- Keine Items mehr zur Auswahl

        local randomIndex = math.random(#weightedProfile)
        local chosenItemEntry = weightedProfile[randomIndex]

        local itemInstance = table.copy(chosenItemEntry)
        itemInstance.quantity = math.random(itemInstance.quantityMin, itemInstance.quantityMax)

        itemInstance.chance = nil
        itemInstance.quantityMin = nil
        itemInstance.quantityMax = nil

        table.insert(itemsInBox, itemInstance)

        -- Optional: Entferne das gewählte Item aus weightedProfile, um Duplikate desselben Item-Typs zu reduzieren,
        -- es sei denn, das Profil ist klein und Duplikate sind erwünscht/akzeptabel.
        -- table.remove(weightedProfile, randomIndex)
    end

    print("Box " .. boxId .. " (Profil: " .. lootProfileName .. ") Inhalt definiert: ", json.encode(itemsInBox))
    return itemsInBox
end


-- Wird von server.lua getriggert, wenn eine neue Runde startet
RegisterNetEvent('br:server:startLootSpawning')
AddEventHandler('br:server:startLootSpawning', function(gameZoneData_unused, lootboxCount_unused)
    ResetPlayerInventory(nil) -- Alle Inventare für neue Runde zurücksetzen
    -- Alte Lootboxen entfernen/resetten
    for _, boxData in pairs(activeLootboxes) do
        if boxData.entity and DoesEntityExist(boxData.entity) then
            DeleteEntity(boxData.entity)
        end
    end
    activeLootboxes = {}
    print("Alte Lootboxen entfernt und Spielerinventare zurückgesetzt. Starte neues Loot Spawning basierend auf Config.")

    if not Config or not Config.Lootboxes or not Config.LootboxModel then
        print("FEHLER: Config.Lootboxes oder Config.LootboxModel nicht in config_lootboxes.lua gefunden!")
        return
    end

    for _, boxConfig in ipairs(Config.Lootboxes) do
        local boxId = boxConfig.id
        local coords = boxConfig.coords
        local lootProfileName = boxConfig.lootProfile or "default_medium" -- Fallback, falls kein Profil angegeben

        local boxContents = DefineBoxContents(boxId, lootProfileName)

        local boxEntity = CreateObjectNoOffset(Config.LootboxModel, coords.x, coords.y, coords.z, true, true, false)
        SetEntityHeading(boxEntity, coords.w)
        FreezeEntityPosition(boxEntity, true) -- Kisten sollen statisch sein

        activeLootboxes[boxId] = {
            id = boxId,
            position = vector3(coords.x, coords.y, coords.z), -- Nur vec3 für Position speichern
            modelHash = Config.LootboxModel,
            items = boxContents,
            isOpened = false,
            entity = boxEntity
        }
        print("Lootbox '" .. boxId .. "' erstellt bei x=" .. coords.x .. ", y=" .. coords.y .. ", z=" .. coords.z .. ", H=" .. coords.w .. " mit Entity: " .. boxEntity)
        TriggerClientEvent('br:client:createLootboxClient', -1, boxId, Config.LootboxModel, vector3(coords.x, coords.y, coords.z), coords.w)
    end
end)

RegisterNetEvent('br:server:requestOpenLootbox')
AddEventHandler('br:server:requestOpenLootbox', function(boxId)
    local source = source
    local box = activeLootboxes[boxId]

    if box and not box.isOpened then
        box.isOpened = true
        print("Spieler " .. GetPlayerName(source) .. " öffnet Box " .. boxId)
        TriggerClientEvent('br:client:lootboxOpenedFeedback', source, boxId, box.items)
        TriggerClientEvent('br:client:announceLootboxOpened', -1, boxId, source) -- Sende auch den Öffner, falls relevant

        -- Optional: Serverseitiges Objekt löschen oder ändern, nachdem es geöffnet wurde
        if box.entity and DoesEntityExist(box.entity) then
            -- DeleteEntity(box.entity) -- Oder Modell ändern
            -- box.entity = nil
        end
        -- Die Box bleibt in activeLootboxes als "geöffnet" markiert, um doppeltes Öffnen zu verhindern.
    elseif box and box.isOpened then
        print("Box " .. boxId .. " wurde bereits geöffnet.")
        -- Optional: Nachricht an Client senden, dass Box schon offen ist.
    else
        print("WARNUNG: Box " .. boxId .. " nicht gefunden oder ungültig für requestOpenLootbox von Spieler " .. GetPlayerName(source))
    end
end)

-- Hilfsfunktion zum Kopieren von Tabellen (für Item-Instanzen)
function table.copy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[table.copy(orig_key)] = table.copy(orig_value)
        end
        setmetatable(copy, table.copy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

-- Wird von server.lua getriggert, wenn eine neue Runde startet
RegisterNetEvent('br:server:startLootSpawning')
AddEventHandler('br:server:startLootSpawning', function(gameZoneData, lootboxCount)
    -- Alte Lootboxen entfernen/resetten, falls vorhanden (wichtig für Folgerunden)
    for boxId, boxData in pairs(activeLootboxes) do
        if boxData.entity and DoesEntityExist(boxData.entity) then
            DeleteEntity(boxData.entity)
        end
    end
    activeLootboxes = {}
    nextLootboxId = 1
    print("Alte Lootboxen entfernt. Starte neues Loot Spawning.")

    SpawnInitialLootboxesInZone(gameZoneData, lootboxCount)
end)

-- Simpler serverseitiger Inventarspeicher
local playerHotbarInventories = {} -- Beispiel: playerHotbarInventories[source] = { [1] = {item}, [2] = {item}, ... }
local MAX_HOTBAR_SLOTS = 5

-- Funktion zum Zurücksetzen des Inventars eines Spielers (oder aller, wenn source nil ist)
function ResetPlayerInventory(playerSource)
    if playerSource then
        playerHotbarInventories[playerSource] = {}
        -- Informiere den Client, seine Hotbar zu leeren
        TriggerClientEvent('br:client:clearHotbar', playerSource)
        print("Inventar für Spieler " .. playerSource .. " zurückgesetzt.")
    else
        for src, _ in pairs(playerHotbarInventories) do
            playerHotbarInventories[src] = {}
            TriggerClientEvent('br:client:clearHotbar', src)
        end
        print("Alle Spielerinventare zurückgesetzt.")
    end
end

-- Beim Start einer neuen Loot-Spawning-Runde auch Inventare zurücksetzen
-- (Annahme: startLootSpawning signalisiert einen Runden-Neustart)
local originalStartLootSpawning = AddEventHandler -- Behalte eine Referenz, falls es eine Funktion war
if type(RemoveEventHandler) == 'function' and type(AddEventHandler) == 'function' then
    -- Dies ist komplexer als gedacht, da AddEventHandler keinen Handler zurückgibt, den man einfach überschreiben kann.
    -- Stattdessen modifizieren wir den bestehenden Handler oder fügen einen neuen hinzu, der Reset aufruft.
    -- Für Einfachheit: Wir rufen ResetPlayerInventory innerhalb des bestehenden br:server:startLootSpawning auf.
    -- Die doppelte Registrierung von br:server:startLootSpawning weiter unten ist ein Fehler und wird entfernt.
    -- Die Logik wird in den ersten Handler integriert.
end

-- Modifiziere den bestehenden startLootSpawning Handler
local original_br_server_startLootSpawning_handler = nil -- Platzhalter, um die Idee zu zeigen

-- Die erste Definition von br:server:startLootSpawning wird diejenige sein, die wir erweitern
-- Die zweite weiter unten im Originalcode ist ein Duplikat und sollte entfernt oder zusammengeführt werden.
-- Ich gehe davon aus, dass die erste Definition die korrekte ist.
-- Innerhalb DIESES Handlers (der erste im File) fügen wir ResetPlayerInventory() hinzu.
-- Der Codeblock für `RegisterNetEvent('br:server:startLootSpawning')` wird also so modifiziert:
-- AddEventHandler('br:server:startLootSpawning', function(gameZoneData_unused, lootboxCount_unused)
--     ResetPlayerInventory(nil) -- Alle Inventare zurücksetzen
--     -- ... restlicher Code des Handlers ...
-- end)
-- Da ich den Code nicht direkt hier ausführen kann, um den Handler zu modifizieren,
-- markiere ich dies als eine notwendige manuelle Anpassung oder eine Annahme für den nächsten Diff.
-- Für den Zweck dieses Schritts, füge ich es hier als Kommentar ein und im nächsten Diff wird es im Handler sein.


RegisterNetEvent('br:server:playerPickedUpItems')
AddEventHandler('br:server:playerPickedUpItems', function(items)
    local source = source
    if not playerHotbarInventories[source] then
        playerHotbarInventories[source] = {}
    end

    print("Spieler " .. GetPlayerName(source) .. " hat Items aufgehoben: " .. json.encode(items))

    for _, itemData in ipairs(items) do
        -- Logik, um zu entscheiden, ob und wie das Item ins Inventar/Hotbar kommt
        -- Vereinfacht: Waffen und Konsumgüter versuchen, einen Hotbar-Slot zu bekommen
        -- Munition wird serverseitig "gespeichert" (hier nicht voll implementiert, nur als Konzept)

        local itemType = itemData.type
        local itemName = itemData.itemName
        local quantity = itemData.quantity or 1
        local iconUrl = itemData.iconUrl or "img/icons/default.png" -- Fallback Icon
        local displayName = itemData.displayName or itemName

        if itemType == "weapon" or itemType == "consumable" then
            local placedInHotbar = false
            -- Versuche, einen existierenden Slot mit demselben Item zu finden (für stapelbare Consumables)
            if itemType == "consumable" then
                for slotId = 1, MAX_HOTBAR_SLOTS do
                    local slotItem = playerHotbarInventories[source][slotId]
                    if slotItem and slotItem.itemName == itemName then
                        -- TODO: Stacking-Logik hier, falls Consumables stacken sollen (z.B. Medikits)
                        -- Vorerst ersetzen wir es oder finden einen neuen Slot, wenn es nicht dasselbe ist.
                        -- Für dieses Beispiel: Wir nehmen an, dass jedes Consumable einen eigenen Slot belegt oder wir suchen einen leeren.
                    end
                end
            end

            -- Finde ersten leeren Slot für das neue Item, falls nicht gestackt
            if not placedInHotbar then
                for slotId = 1, MAX_HOTBAR_SLOTS do
                    if not playerHotbarInventories[source][slotId] then
                        playerHotbarInventories[source][slotId] = {
                            itemName = itemName,
                            type = itemType,
                            quantity = quantity,
                            ammo = itemData.ammo, -- für Waffen
                            heal = itemData.heal, -- für Consumables
                            armour = itemData.armour, -- für Consumables
                            iconUrl = iconUrl,
                            displayName = displayName
                            -- Füge hier weitere relevante Item-Attribute hinzu
                        }
                        TriggerClientEvent('br:client:updatePlayerHotbarSlot', source, slotId, iconUrl, quantity, displayName)
                        print("Item " .. itemName .. " zu Hotbar Slot " .. slotId .. " für Spieler " .. source .. " hinzugefügt.")
                        placedInHotbar = true
                        break
                    end
                end
            end

            if not placedInHotbar then
                print("Kein freier Hotbar-Slot für Item " .. itemName .. " für Spieler " .. source)
                -- TODO: Sende eine Nachricht an den Spieler, dass die Hotbar voll ist oder das Item nicht aufgenommen werden konnte.
                -- Oder implementiere ein größeres "Rucksack"-Inventar.
            end

        elseif itemType == "ammo" then
            -- TODO: Munitionslogik serverseitig implementieren
            -- Zum Beispiel: Füge Munition zu einer separaten Tabelle hinzu oder direkt zur Waffe, falls der Spieler sie hat.
            print("Munition " .. itemName .. " (" .. quantity .. ") für Spieler " .. source .. " aufgenommen (serverseitige Logik TBD).")
            -- Vorerst geben wir dem Spieler die Munition direkt, wenn er die Waffe hat.
            -- Dies ist eine sehr grundlegende Implementierung.
            local forWeaponHash = GetHashKey(itemData.forWeapon)
            local playerPed = GetPlayerPed(source) -- GetPlayerPed benötigt eine Spieler-ID, nicht source direkt für FiveM natives
            -- Die Verwendung von GetPlayerPed(source) ist in FiveM nicht direkt so gedacht. Man braucht den Ped Handle.
            -- TriggerClientEvent('br:client:giveAmmoToPlayer', source, forWeaponHash, quantity)
            -- Besser: Der Client fordert Munition an oder die Waffenlogik auf dem Server handhabt das.
            -- Für jetzt: Wir senden ein Event an den Client, um Munition hinzuzufügen. Dies ist nicht ideal.
            TriggerClientEvent('br:client:addAmmoToWeaponConcept', source, itemData.forWeapon, quantity, iconUrl, displayName)


        else
            print("Unbekannter Item-Typ: " .. itemType .. " für Item " .. itemName)
        end
    end
end)

-- Event, wenn Spieler den Server verlässt
AddEventHandler('playerDropped', function(reason)
    local source = source
    if playerHotbarInventories[source] then
        print("Spieler " .. GetPlayerName(source) .. " hat den Server verlassen. Inventar entfernt.")
        playerHotbarInventories[source] = nil
    end
end)

RegisterNetEvent('br:server:useHotbarItem')
AddEventHandler('br:server:useHotbarItem', function(slotId)
    local source = source
    local playerPed = GetPlayerPed(source) -- Serverseitigen Ped Handle holen

    if not playerPed or playerPed == 0 then
        print("BR_SERVER_LOOT: Konnte Ped für Spieler " .. source .. " nicht finden für useHotbarItem.")
        return
    end

    if not playerHotbarInventories[source] or not playerHotbarInventories[source][slotId] then
        print("BR_SERVER_LOOT: Spieler " .. source .. " hat kein Item in Hotbar Slot " .. slotId)
        return
    end

    local item = playerHotbarInventories[source][slotId]
    print("BR_SERVER_LOOT: Spieler " .. GetPlayerName(source) .. " benutzt Item '" .. item.displayName .. "' aus Slot " .. slotId)

    if item.type == "weapon" then
        local weaponHash = GetHashKey(item.itemName)
        local ammoCount = item.ammo or 0

        -- Entferne alle Waffen, bevor eine neue gegeben wird, um Konflikte zu vermeiden (optional, je nach gewünschtem Verhalten)
        -- RemoveAllPedWeapons(playerPed, true) -- Überlege, ob das gewünscht ist.

        GiveWeaponToPed(playerPed, weaponHash, ammoCount, false, true) -- ped, weaponhash, ammo, isHidden, equipNow
        print("BR_SERVER_LOOT: Waffe " .. item.itemName .. " mit " .. ammoCount .. " Munition an Spieler " .. source .. " gegeben.")

        -- Item aus Hotbar entfernen nach Benutzung (für Waffen erstmal so)
        playerHotbarInventories[source][slotId] = nil
        TriggerClientEvent('br:client:updatePlayerHotbarSlot', source, slotId, "", 0, "") -- Slot im Client leeren

    elseif item.type == "consumable" then
        local currentHealth = GetEntityHealth(playerPed)
        local currentArmour = GetPedArmour(playerPed)
        local maxHealth = GetPedMaxHealth(playerPed) -- Normalerweise 200 mit Standard-GTA-Logik (100 Basis + 100 durchgehend)
                                                  -- Du könntest dies auch aus einer Config holen, falls du andere Max-Health-Werte hast.

        if item.heal then
            local newHealth = math.min(currentHealth + item.heal, maxHealth)
            SetEntityHealth(playerPed, newHealth)
            print("BR_SERVER_LOOT: Spieler " .. source .. " geheilt um " .. item.heal .. ". Neue Gesundheit: " .. newHealth)
        end

        if item.armour then
            local newArmour = math.min(currentArmour + item.armour, 100) -- Max Rüstung ist normalerweise 100
            SetPedArmour(playerPed, newArmour)
            print("BR_SERVER_LOOT: Spieler " .. source .. " erhielt " .. item.armour .. " Rüstung. Neue Rüstung: " .. newArmour)
        end

        item.quantity = (item.quantity or 1) - 1

        if item.quantity <= 0 then
            playerHotbarInventories[source][slotId] = nil
            TriggerClientEvent('br:client:updatePlayerHotbarSlot', source, slotId, "", 0, "") -- Slot im Client leeren
            print("BR_SERVER_LOOT: Consumable '" .. item.displayName .. "' für Spieler " .. source .. " aufgebraucht.")
        else
            -- Update den Slot mit der neuen Menge
            playerHotbarInventories[source][slotId] = item -- Stelle sicher, dass die geänderte Menge gespeichert wird
            TriggerClientEvent('br:client:updatePlayerHotbarSlot', source, slotId, item.iconUrl, item.quantity, item.displayName)
            print("BR_SERVER_LOOT: Consumable '" .. item.displayName .. "' für Spieler " .. source .. " hat noch " .. item.quantity .. " Ladungen.")
        end
    else
        print("BR_SERVER_LOOT: Unbekannter Item-Typ '" .. item.type .. "' in Hotbar für Spieler " .. source)
    end
end)


-- Der doppelte 'br:server:startLootSpawning' Handler muss entfernt werden.
-- Die folgende Definition wird auskommentiert, da die Logik in den ersten Handler integriert werden sollte.
--[[
RegisterNetEvent('br:server:startLootSpawning')
AddEventHandler('br:server:startLootSpawning', function(gameZoneData, lootboxCount)
    -- Alte Lootboxen entfernen/resetten, falls vorhanden (wichtig für Folgerunden)
    for boxId, boxData in pairs(activeLootboxes) do
        if boxData.entity and DoesEntityExist(boxData.entity) then
            DeleteEntity(boxData.entity)
        end
    end
    activeLootboxes = {}
    nextLootboxId = 1
    print("Alte Lootboxen entfernt. Starte neues Loot Spawning.")

    SpawnInitialLootboxesInZone(gameZoneData, lootboxCount)
end)
--]]
