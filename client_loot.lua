-- client_loot.lua
print("Battle Royale Client Loot Skript geladen")

clientActiveLootboxes = {} -- Speichert { serverId, objectHandle, blipHandle, isOpened = false, position, heading }
activeDroppedBags = {} -- Speichert { objectHandle, items = {}, position, spawnTime }
local BAG_MODEL_HASH = GetHashKey("prop_money_bag_01") -- Kleiner Geldsack als Item-Tasche

local currentLocalInGame = false -- Lokale Variable für dieses Skript

-- Import von ShowHelpNotificationShared entfernt

-- Hilfsfunktion, um die Anzahl der Einträge in einer Tabelle zu bekommen
function GetTableLength(T)
    local count = 0
    if T == nil then return 0 end
    for _ in pairs(T) do count = count + 1 end
    return count
end

-- Lokale Funktion zum Anzeigen des Interaktionshinweises für Lootboxen
function DisplayLootInteractMessage(message)
    local entryKey = "BR_LOOT_INTERACT_HINT" -- Eigener, eindeutiger Key für diese Funktion
    AddTextEntry(entryKey, message)
    BeginTextCommandDisplayHelp(entryKey)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

RegisterNetEvent('br:client:actualGameStateChanged')
AddEventHandler('br:client:actualGameStateChanged', function(status)
    currentLocalInGame = status
    print("BR_LOOT_DEBUG: actualGameStateChanged empfangen, neuer Status für Loot-Interaktion: " .. tostring(status))
    if not status then
        for serverId, boxData in pairs(clientActiveLootboxes) do
            if boxData.blipHandle and DoesBlipExist(boxData.blipHandle) then RemoveBlip(boxData.blipHandle) end
            if boxData.objectHandle and DoesEntityExist(boxData.objectHandle) then DeleteEntity(boxData.objectHandle) end
        end
        clientActiveLootboxes = {}
        for bagHandle, _ in pairs(activeDroppedBags) do
            if DoesEntityExist(bagHandle) then
                DeleteEntity(bagHandle)
            end
        end
        activeDroppedBags = {}
        print("BR_LOOT_DEBUG: Spiel beendet, alle clientseitigen Lootboxen und Item-Taschen entfernt.")
    end
end)

RegisterNetEvent('br:client:createLootboxClient')
AddEventHandler('br:client:createLootboxClient', function(serverId, modelHash, position, heading)
    print("BR_LOOT_DEBUG: Erhalte Befehl, Lootbox clientseitig zu erstellen: ID " .. serverId .. " an Pos " .. position)

    modelHash = modelHash or (Config and Config.LootboxModel) or GetHashKey("prop_box_ammo04a")

    RequestModel(modelHash)
    Citizen.CreateThread(function()
        local attempts = 0
        while not HasModelLoaded(modelHash) and attempts < 100 do
            Citizen.Wait(50)
            attempts = attempts + 1
        end

        if HasModelLoaded(modelHash) then
            local objectHandle = CreateObject(modelHash, position.x, position.y, position.z, true, true, false)

            if not DoesEntityExist(objectHandle) then
                print("BR_LOOT_DEBUG: Konnte Objekt für Lootbox nicht erstellen: " .. serverId)
                SetModelAsNoLongerNeeded(modelHash)
                return
            end

            SetEntityHeading(objectHandle, heading + 0.0)
            PlaceObjectOnGroundProperly(objectHandle)
            FreezeEntityPosition(objectHandle, true)

            Citizen.Wait(50)
            if not DoesEntityExist(objectHandle) then
                 print("BR_LOOT_DEBUG: Objekt für Lootbox " .. serverId .. " ist nach kurzer Wartezeit verschwunden.")
                 SetModelAsNoLongerNeeded(modelHash)
                 return
            end

            local finalPos = GetEntityCoords(objectHandle) -- Verwende die finale Position
            print("BR_LOOT_DEBUG: Lootbox " .. serverId .. " platziert an " .. finalPos .. ", Heading: " .. GetEntityHeading(objectHandle))

            local blipHandle = AddBlipForEntity(objectHandle)
            SetBlipSprite(blipHandle, 1)
            SetBlipColour(blipHandle, 2)
            SetBlipScale(blipHandle, 0.7)
            SetBlipAsShortRange(blipHandle, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString("Lootkiste")
            EndTextCommandSetBlipName(blipHandle)

            clientActiveLootboxes[serverId] = {
                serverId = serverId,
                objectHandle = objectHandle,
                blipHandle = blipHandle,
                isOpened = false,
                position = finalPos, -- WICHTIG: Speichere die finale Position nach PlaceObjectOnGroundProperly
                heading = heading
            }
            print("BR_LOOT_DEBUG: Eintrag in clientActiveLootboxes[" .. serverId .. "]: " .. json.encode(clientActiveLootboxes[serverId]))
        else
            print("BR_LOOT_DEBUG: Modell für Lootbox " .. serverId .. " konnte nicht geladen werden: " .. modelHash)
        end
        SetModelAsNoLongerNeeded(modelHash)
    end)
end)

-- Interaktions-Thread für Lootboxen (überarbeitet mit Debugging)
Citizen.CreateThread(function()
    local currentTargetBoxId = nil
    local isCurrentlyDisplayingInteractionText = false

    while true do
        Citizen.Wait(100)

        local playerPed = PlayerPedId()
        if not playerPed or not DoesEntityExist(playerPed) then
            if isCurrentlyDisplayingInteractionText then
                isCurrentlyDisplayingInteractionText = false
                currentTargetBoxId = nil
            end
            Citizen.Wait(500)
        else
            local playerCoords = GetEntityCoords(playerPed)
            local showInteractionTextThisFrame = false
            local newTargetBoxIdThisFrame = nil
            local closestDist = 3.5 -- Testweise erhöht

            -- print("BR_LOOT_DEBUG: Interaktions-Thread Tick. InGame: " .. tostring(currentLocalInGame) .. ". Anzahl Boxen: " .. GetTableLength(clientActiveLootboxes) .. ". PlayerCoords: " .. (playerCoords and json.encode(playerCoords) or "nil"))

            if currentLocalInGame then
                for serverId, boxData in pairs(clientActiveLootboxes) do
                    if boxData and boxData.objectHandle and DoesEntityExist(boxData.objectHandle) and not boxData.isOpened then
                        if not boxData.position then
                            -- print("BR_LOOT_DEBUG: WARNUNG - boxData.position ist nil für Box: " .. serverId)
                            goto continue
                        end
                        local dist = #(playerCoords - boxData.position)

                        -- print("BR_LOOT_DEBUG: Prüfe Box: " .. serverId .. " | BoxPos: " .. json.encode(boxData.position) .. " | Dist: " .. string.format("%.2f", dist) .. " | Opened: " .. tostring(boxData.isOpened))

                        if dist < closestDist then
                            print("BR_LOOT_DEBUG: Box " .. serverId .. " in Reichweite! Distanz: " .. string.format("%.2f", dist))
                            showInteractionTextThisFrame = true
                            newTargetBoxIdThisFrame = serverId
                            closestDist = dist
                        end
                    end
                    ::continue::
                end
            end

            if showInteractionTextThisFrame and newTargetBoxIdThisFrame then
                currentTargetBoxId = newTargetBoxIdThisFrame
                if not isCurrentlyDisplayingInteractionText then
                    print("BR_LOOT_DEBUG: Sollte jetzt Text anzeigen für Box: " .. currentTargetBoxId .. " (Verwende lokale Funktion)")
                    DisplayLootInteractMessage("Drücke [E], um die Kiste zu öffnen.")
                    isCurrentlyDisplayingInteractionText = true
                end

                if IsControlJustReleased(0, 38) then -- Taste E
                    print("BR_LOOT_DEBUG: E gedrückt für Box " .. currentTargetBoxId)
                    TriggerServerEvent('br:server:requestOpenLootbox', currentTargetBoxId)
                    isCurrentlyDisplayingInteractionText = false
                end
            else
                if isCurrentlyDisplayingInteractionText then
                    print("BR_LOOT_DEBUG: Interaktionstext wird nicht mehr angezeigt (keine Box in Reichweite oder Spiel nicht aktiv).")
                    isCurrentlyDisplayingInteractionText = false
                    currentTargetBoxId = nil
                end
            end
        end
    end
end)

RegisterNetEvent('br:client:announceLootboxOpened')
AddEventHandler('br:client:announceLootboxOpened', function(serverId, openerPlayerSource)
    local box = clientActiveLootboxes[serverId]
    if box then
        box.isOpened = true
        if box.blipHandle and DoesBlipExist(box.blipHandle) then
            RemoveBlip(box.blipHandle)
            box.blipHandle = nil
        end
        if box.objectHandle and DoesEntityExist(box.objectHandle) then
            DeleteEntity(box.objectHandle)
            box.objectHandle = nil
        end
        print("BR_LOOT_DEBUG: Box " .. serverId .. " wurde von Spieler " .. openerPlayerSource .. " geöffnet und clientseitig aktualisiert.")
    end
end)

RegisterNetEvent('br:client:lootboxOpenedFeedback')
AddEventHandler('br:client:lootboxOpenedFeedback', function(serverId, items)
    local box = clientActiveLootboxes[serverId]
    if not box then
        print("BR_LOOT_DEBUG: Feedback für unbekannte Box erhalten: " .. serverId)
        return
    end

    print("BR_LOOT_DEBUG: Items aus Box " .. serverId .. " erhalten: " .. json.encode(items))

    if not items or #items == 0 then
        print("BR_LOOT_DEBUG: Keine Items in der Box " .. serverId .. ", keine Tasche wird gespawnt.")
        return
    end

    local baseCoords = box.position
    -- Da das Lootbox-Objekt möglicherweise bereits gelöscht wurde (durch announceLootboxOpened),
    -- ist box.position die zuverlässigste Quelle für die Koordinaten.
    if not baseCoords then
        print("BR_LOOT_DEBUG: Kritisch - Keine Basiskoodinaten für Item-Drop von Box " .. serverId .. ". box.position war nil.")
        -- Fallback, falls die Box noch existiert, was unwahrscheinlich sein sollte, wenn announceLootboxOpened schnell ist.
        if box.objectHandle and DoesEntityExist(box.objectHandle) then
            baseCoords = GetEntityCoords(box.objectHandle)
            print("BR_LOOT_DEBUG: Fallback auf GetEntityCoords(box.objectHandle) genutzt.")
        else
            print("BR_LOOT_DEBUG: Konnte keine Koordinaten für den Taschen-Drop finden. Abbruch.")
            return
        end
    end

    RequestModel(BAG_MODEL_HASH)
    Citizen.CreateThread(function()
        local attempts = 0
        while not HasModelLoaded(BAG_MODEL_HASH) and attempts < 100 do
            Citizen.Wait(50)
            attempts = attempts + 1
        end

        if HasModelLoaded(BAG_MODEL_HASH) then
            -- Spawn die Tasche leicht über der Position der Lootbox, damit sie fallen kann
            local spawnPos = vector3(baseCoords.x, baseCoords.y, baseCoords.z + 0.75)
            local bagHandle = CreateObject(BAG_MODEL_HASH, spawnPos.x, spawnPos.y, spawnPos.z, true, true, false) -- isNetworked, isDynamic, isMissionEntity (false for auto cleanup)

            if DoesEntityExist(bagHandle) then
                print("BR_LOOT_DEBUG: Tasche (" .. bagHandle .. ") für Box " .. serverId .. " gespawnt bei " .. spawnPos)
                SetEntityHeading(bagHandle, math.random(0, 360) + 0.0)
                -- SetEntityDynamic(bagHandle, true) -- CreateObject mit isDynamic=true sollte reichen
                PlaceObjectOnGroundProperly(bagHandle) -- Sicherstellen, dass sie auf dem Boden landet
                SetEntityAsMissionEntity(bagHandle, false, true) -- Wichtig: false, true, damit es nicht sofort verschwindet und korrekt aufgeräumt wird

                local finalBagPos = GetEntityCoords(bagHandle)
                activeDroppedBags[bagHandle] = {
                    items = items, -- Speichere alle Items aus der Lootbox in dieser einen Tasche
                    position = finalBagPos,
                    spawnTime = GetGameTimer()
                }
                print("BR_LOOT_DEBUG: Tasche " .. bagHandle .. " mit Items " .. json.encode(items) .. " zu activeDroppedBags hinzugefügt.")
            else
                print("BR_LOOT_DEBUG: Konnte Taschenobjekt nicht erstellen für Box: " .. serverId)
            end
        else
            print("BR_LOOT_DEBUG: Taschenmodell (" .. BAG_MODEL_HASH .. ") konnte nicht geladen werden.")
        end
        SetModelAsNoLongerNeeded(BAG_MODEL_HASH)
    end)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        for serverId, boxData in pairs(clientActiveLootboxes) do
            if boxData.blipHandle and DoesBlipExist(boxData.blipHandle) then
                RemoveBlip(boxData.blipHandle)
            end
            if boxData.objectHandle and DoesEntityExist(boxData.objectHandle) then
                DeleteEntity(boxData.objectHandle)
            end
        end
        clientActiveLootboxes = {}

        for bagHandle, _ in pairs(activeDroppedBags) do
            if DoesEntityExist(bagHandle) then
                DeleteEntity(bagHandle)
            end
        end
        activeDroppedBags = {}
        print("BR_LOOT_DEBUG: Alle clientseitigen Lootboxen und Item-Taschen beim Ressourcenstopp entfernt.")
    end
end)

-- DrawText3D (auskommentiert)
-- ...

-- Lokale Funktion zum Anzeigen von Hinweisen (ähnlich zu client.lua, aber lokal für Loot-Interaktionen)
local function DisplayGenericHelpText(messageKey, message)
    AddTextEntry(messageKey, message)
    BeginTextCommandDisplayHelp(messageKey)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

-- Thread für die Interaktion mit Item-Taschen
Citizen.CreateThread(function()
    local currentTargetBagHandle = nil
    local isDisplayingBagInteractText = false
    local bagInteractKey = "BR_BAG_INTERACT_HINT"

    while true do
        Citizen.Wait(100) -- Prüfintervall

        if not currentLocalInGame or GetTableLength(activeDroppedBags) == 0 then
            if isDisplayingBagInteractText then
                isDisplayingBagInteractText = false -- Text ausblenden, wenn nicht im Spiel oder keine Taschen da sind
                currentTargetBagHandle = nil
            end
            Citizen.Wait(500) -- Längere Pause, wenn nichts zu tun ist
        else
            local playerPed = PlayerPedId()
            if not playerPed or not DoesEntityExist(playerPed) then
                Citizen.Wait(500)
                goto continue_bag_thread
            end

            local playerCoords = GetEntityCoords(playerPed)
            local showBagInteractThisFrame = false
            local newTargetBagHandle = nil
            local closestDistSq = 4.0 -- Interaktionsradius (2.0 * 2.0) für Taschen (quadratisch für schnellere Prüfung)

            for bagHandle, bagData in pairs(activeDroppedBags) do
                if DoesEntityExist(bagHandle) then -- Nur existierende Taschen prüfen
                    local distSq = #(playerCoords - bagData.position) -- Vdist2
                    if distSq < closestDistSq then
                        showBagInteractThisFrame = true
                        newTargetBagHandle = bagHandle
                        closestDistSq = distSq -- Update für die nächste, potenziell nähere Tasche
                    end
                else
                    -- Bereinige Taschen, die nicht mehr existieren (sollte selten vorkommen)
                    print("BR_LOOT_DEBUG: Tasche " .. bagHandle .. " existiert nicht mehr, entferne aus activeDroppedBags.")
                    activeDroppedBags[bagHandle] = nil
                end
            end

            if showBagInteractThisFrame and newTargetBagHandle then
                currentTargetBagHandle = newTargetBagHandle
                if not isDisplayingBagInteractText then
                    DisplayGenericHelpText(bagInteractKey, "Drücke [E], um die Tasche aufzuheben.")
                    isDisplayingBagInteractText = true
                end

                if IsControlJustReleased(0, 38) then -- Taste E
                    local pickedUpBagData = activeDroppedBags[currentTargetBagHandle]
                    if pickedUpBagData then
                        print("BR_LOOT_DEBUG: E gedrückt für Tasche " .. currentTargetBagHandle .. ". Inhalt: " .. json.encode(pickedUpBagData.items))
                        TriggerServerEvent('br:server:playerPickedUpItems', pickedUpBagData.items)

                        -- Visuelles Feedback für den Spieler (temporär, bis Server-Antwort kommt)
                        local itemsPickedUpMsg = "Aufgehoben:"
                        for _, item in ipairs(pickedUpBagData.items) do
                            itemsPickedUpMsg = itemsPickedUpMsg .. " " .. (item.quantity or 1) .. "x " .. (item.itemName or "Unbekannt") .. ","
                        end
                        -- Entferne letztes Komma
                        if string.sub(itemsPickedUpMsg, -1) == "," then itemsPickedUpMsg = string.sub(itemsPickedUpMsg, 1, -2) end
                        DisplayGenericHelpText("BR_PICKUP_FEEDBACK", itemsPickedUpMsg) -- Zeige für kurze Zeit
                        Citizen.SetTimeout(3000, function() DisplayGenericHelpText("BR_PICKUP_FEEDBACK", "") end)


                        DeleteEntity(currentTargetBagHandle)
                        activeDroppedBags[currentTargetBagHandle] = nil
                        isDisplayingBagInteractText = false -- Text sofort ausblenden
                        currentTargetBagHandle = nil      -- Ziel zurücksetzen
                    end
                end
            else
                if isDisplayingBagInteractText then
                    isDisplayingBagInteractText = false
                    currentTargetBagHandle = nil
                end
            end
            ::continue_bag_thread::
        end
    end
end)
