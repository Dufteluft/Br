-- client_hud.lua
print("Battle Royale Client HUD Skript geladen")

local hudVisible = false
local localInGame = false -- Lokale Kopie des inGame Status, um Zirkelbezüge zu vermeiden, wenn client.lua auch darauf zugreift
local localNextShrinkTime = 0 -- Lokale Kopie

-- Funktion zum Anzeigen/Ausblenden der HUD (wird von client.lua aufgerufen oder hier direkt)
function ShowHud(show)
    if hudVisible == show then return end
    SendNUIMessage({
        type = "hud", -- Wird von script.js behandelt, um hud-container und hotbar-container zu steuern
        status = show
    })
    hudVisible = show
    print("BR_DEBUG_HUD: HUD Status geändert auf: " .. tostring(show))
end

-- Wird von client.lua aufgerufen, um den Spielstatus zu synchronisieren
function SetHudGameStatus(inGameStatus, nextShrink)
    localInGame = inGameStatus
    localNextShrinkTime = nextShrink or 0 -- Setze auf 0, wenn nicht angegeben
    ShowHud(inGameStatus)
    print("BR_DEBUG_HUD: SetHudGameStatus - inGame: " .. tostring(localInGame) .. ", nextShrink: " .. tostring(localNextShrinkTime))
    if not localInGame then
        -- Reset Kills und andere HUD-spezifische Anzeigen, wenn das Spiel endet
         SendNUIMessage({ type = "updateKillCount", count = 0 })
         -- Alive count wird vom Server bei Rundenende/Neustart aktualisiert
    end
end

-- Thread zur regelmäßigen Aktualisierung der HUD-Daten
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(500) -- Aktualisierungsintervall

        if localInGame and hudVisible then
            local playerPed = PlayerPedId()
            if not playerPed or not DoesEntityExist(playerPed) then
                Citizen.Wait(1000)
            else
                local health = GetEntityHealth(playerPed)
                local maxHealth = GetPedMaxHealth(playerPed)
                local armour = GetPedArmour(playerPed)
                local zoneTimeLeft = 0

                if localNextShrinkTime > 0 then
                    zoneTimeLeft = localNextShrinkTime - GetGameTimer()
                    if zoneTimeLeft < 0 then zoneTimeLeft = 0 end
                end

                SendNUIMessage({
                    type = "updateHudStats",
                    health = health,
                    maxHealth = maxHealth,
                    armour = armour,
                    zoneTimeLeft = zoneTimeLeft
                })
            end
        end
    end
end)

-- Event vom Server, um die Anzahl der lebenden Spieler zu aktualisieren
RegisterNetEvent('br:client:updateAliveCount')
AddEventHandler('br:client:updateAliveCount', function(count)
    if hudVisible then
        SendNUIMessage({
            type = "updateAliveCount",
            count = count
        })
        print("BR_DEBUG_HUD: Alive count updated to: " .. count)
    end
end)

-- Event vom Server, um die Kill-Anzahl des Spielers zu aktualisieren
RegisterNetEvent('br:client:updateKillCount')
AddEventHandler('br:client:updateKillCount', function(count)
    if hudVisible then
        SendNUIMessage({
            type = "updateKillCount",
            count = count
        })
        print("BR_DEBUG_HUD: Kill count updated to: " .. count)
    end
end)

-- Globale Funktion, damit client.lua den nächsten Shrink Time aktualisieren kann
-- Dies ist nötig, da nextShrinkTime in client.lua in der Zonenlogik aktualisiert wird.
function UpdateNextShrinkTime(newTime)
    localNextShrinkTime = newTime
    -- print("BR_DEBUG_HUD: localNextShrinkTime updated to: " .. localNextShrinkTime)
end

-- Hotbar NUI Funktionen
function ClearHotbarNui()
    SendNUIMessage({ type = "clearHotbar" })
    print("BR_DEBUG_HUD: ClearHotbarNui gesendet")
end

function UpdateHotbarSlotNui(slotId, iconUrl, quantity, itemName)
    SendNUIMessage({
        type = "updateHotbarSlot",
        slotId = slotId,
        iconUrl = iconUrl,
        quantity = quantity,
        itemName = itemName
    })
    -- print("BR_DEBUG_HUD: UpdateHotbarSlotNui für Slot " .. slotId .. " gesendet")
end

-- Anpassung von SetHudGameStatus, um ClearHotbarNui aufzurufen
function SetHudGameStatus(inGameStatus, nextShrink)
    localInGame = inGameStatus
    _G.BattleRoyaleLocalInGame = inGameStatus -- Setze die globale Variable für andere client Skripte (wie client_loot)
    TriggerEvent('br:client:actualGameStateChanged', inGameStatus) -- Sende Event für andere Skripte

    localNextShrinkTime = nextShrink or 0
    ShowHud(inGameStatus) -- ShowHud steuert jetzt auch die Hotbar-Sichtbarkeit via script.js
    print("BR_DEBUG_HUD: SetHudGameStatus - inGame: " .. tostring(localInGame) .. ", nextShrink: " .. tostring(localNextShrinkTime))
    if not localInGame then
        SendNUIMessage({ type = "updateKillCount", count = 0 })
        ClearHotbarNui() -- Hotbar leeren, wenn Spiel/HUD nicht mehr aktiv
    end
end

RegisterNetEvent('br:client:updatePlayerHotbarSlot')
AddEventHandler('br:client:updatePlayerHotbarSlot', function(slotId, iconUrl, quantity, itemName)
    print("BR_DEBUG_HUD: Empfange br:client:updatePlayerHotbarSlot - Slot: " .. slotId .. ", Item: " .. itemName .. ", Qty: " .. quantity .. ", Icon: " .. iconUrl)
    UpdateHotbarSlotNui(slotId, iconUrl, quantity, itemName)
end)

RegisterNetEvent('br:client:clearHotbar')
AddEventHandler('br:client:clearHotbar', function()
    print("BR_DEBUG_HUD: Empfange br:client:clearHotbar")
    ClearHotbarNui()
end)

-- Provisorische Funktion zum Anzeigen von Benachrichtigungen für aufgesammelte Munition
local function ShowNotification(text)
    SetNotificationTextEntry("STRING")
    AddTextComponentString(text)
    DrawNotification(false, true)
end

RegisterNetEvent('br:client:addAmmoToWeaponConcept')
AddEventHandler('br:client:addAmmoToWeaponConcept', function(forWeaponName, quantity, iconUrl, displayName)
    print("BR_DEBUG_HUD: Empfange br:client:addAmmoToWeaponConcept - Waffe: " .. forWeaponName .. ", Menge: " .. quantity)
    ShowNotification("Munition aufgesammelt: " .. quantity .. "x " .. displayName)
    -- Hier könnte man versuchen, die Munition direkt der Waffe hinzuzufügen, wenn der Spieler sie ausgerüstet hat,
    -- aber das erfordert komplexere Waffen-Handling-Logik clientseitig.
    -- Beispiel:
    -- local playerPed = PlayerPedId()
    -- local weaponHash = GetHashKey(forWeaponName)
    -- if HasPedGotWeapon(playerPed, weaponHash, false) then
    --    AddAmmoToPed(playerPed, weaponHash, quantity)
    --    ShowNotification("Munition für " .. displayName .. " hinzugefügt.")
    -- else
    --    ShowNotification("Munition aufgesammelt: " .. quantity .. "x " .. displayName .. " (Waffe nicht ausgerüstet)")
    -- end
    -- Fürs Erste belassen wir es bei einer einfachen Benachrichtigung.
    -- Die NUI für die Hotbar könnte auch für Munition aktualisiert werden, wenn sie als Item angezeigt wird.
    -- Für jetzt wird Munition nicht direkt in der Hotbar angezeigt, es sei denn, sie wird als normales Item behandelt.
end)

-- Registrierung der Key Mappings und Commands für Hotbar-Slots
Citizen.CreateThread(function()
    -- Sicherstellen, dass localInGame und hudVisible initialisiert sind, bevor der Loop startet,
    -- obwohl diese Commands global registriert werden und nicht direkt von diesen Variablen abhängen sollten
    -- für ihre Ausführung, sondern die Bedingungen in den Command-Funktionen selbst geprüft werden.
    -- Die print-Ausgaben und TriggerServerEvent werden jetzt direkt in den Command-Handler-Funktionen ausgeführt.

    RegisterCommand('+useHotbarSlot1', function()
        if localInGame and hudVisible then
            print("BR_DEBUG_HUD: Hotbar Slot 1 (Command via KeyMapping) benutzt")
            TriggerServerEvent('br:server:useHotbarItem', 1)
        else
            print("BR_DEBUG_HUD: Hotbar Slot 1 Versuch - nicht im Spiel oder HUD nicht sichtbar.")
        end
    end, false) -- false bedeutet, dass es nicht für die Konsole (Chat) registriert wird

    RegisterCommand('+useHotbarSlot2', function()
        if localInGame and hudVisible then
            print("BR_DEBUG_HUD: Hotbar Slot 2 (Command via KeyMapping) benutzt")
            TriggerServerEvent('br:server:useHotbarItem', 2)
        else
            print("BR_DEBUG_HUD: Hotbar Slot 2 Versuch - nicht im Spiel oder HUD nicht sichtbar.")
        end
    end, false)

    RegisterCommand('+useHotbarSlot3', function()
        if localInGame and hudVisible then
            print("BR_DEBUG_HUD: Hotbar Slot 3 (Command via KeyMapping) benutzt")
            TriggerServerEvent('br:server:useHotbarItem', 3)
        else
            print("BR_DEBUG_HUD: Hotbar Slot 3 Versuch - nicht im Spiel oder HUD nicht sichtbar.")
        end
    end, false)

    RegisterCommand('+useHotbarSlot4', function()
        if localInGame and hudVisible then
            print("BR_DEBUG_HUD: Hotbar Slot 4 (Command via KeyMapping) benutzt")
            TriggerServerEvent('br:server:useHotbarItem', 4)
        else
            print("BR_DEBUG_HUD: Hotbar Slot 4 Versuch - nicht im Spiel oder HUD nicht sichtbar.")
        end
    end, false)

    RegisterCommand('+useHotbarSlot5', function()
        if localInGame and hudVisible then
            print("BR_DEBUG_HUD: Hotbar Slot 5 (Command via KeyMapping) benutzt")
            TriggerServerEvent('br:server:useHotbarItem', 5)
        else
            print("BR_DEBUG_HUD: Hotbar Slot 5 Versuch - nicht im Spiel oder HUD nicht sichtbar.")
        end
    end, false)

    -- Key Mappings für die oben definierten Commands
    -- Der dritte Parameter ist die Kategorie in den FiveM-Tasteneinstellungen (z.B. 'DeinSkriptName')
    -- Der vierte Parameter ist die Standardtaste.
    local resourceName = GetCurrentResourceName()
    RegisterKeyMapping('+useHotbarSlot1', 'Hotbar Slot 1', 'keyboard', '1')
    RegisterKeyMapping('+useHotbarSlot2', 'Hotbar Slot 2', 'keyboard', '2')
    RegisterKeyMapping('+useHotbarSlot3', 'Hotbar Slot 3', 'keyboard', '3')
    RegisterKeyMapping('+useHotbarSlot4', 'Hotbar Slot 4', 'keyboard', '4')
    RegisterKeyMapping('+useHotbarSlot5', 'Hotbar Slot 5', 'keyboard', '5')

    print("BR_DEBUG_HUD: Hotbar KeyMappings registriert.")
end)

-- Der alte Thread für Hotbar-Tasteneingaben mit IsControlJustReleased wurde entfernt.
