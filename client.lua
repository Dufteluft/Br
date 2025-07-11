-- client.lua
print("Battle Royale Client Skript geladen")

local lobbyInteractionPos = vector3(1974.78, 3819.47, 32.1) -- Beispielkoordinaten in Sandy Shores (Tankstelle)
local interactionDistance = 2.0
local isNearInteractionPoint = false
local uiOpen = false

-- Funktion zum Anzeigen von Texthinweisen
function ShowHelpNotification(msg)
    local entryKey = 'BR_INTERACT_MSG' -- Eindeutiger Key
    AddTextEntry(entryKey, msg)
    BeginTextCommandDisplayHelp(entryKey)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

-- Thread für die Interaktion
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local distance = #(playerCoords - lobbyInteractionPos)

        if distance < interactionDistance then
            isNearInteractionPoint = true
            if not uiOpen then
                ShowHelpNotification("Drücke [E], um die Battle Royale Lobby zu öffnen.")
                if IsControlJustReleased(0, 38) then -- 38 ist der Keycode für E
                    print("E gedrückt, öffne UI")
                    SendNUIMessage({
                        type = "ui",
                        status = true
                    })
                    SetNuiFocus(true, true)
                    uiOpen = true
                end
            end
        else
            if isNearInteractionPoint and not uiOpen then
                -- Hier könnte man eine Nachricht zum Verlassen des Bereichs anzeigen, falls nötig
            end
            isNearInteractionPoint = false
        end

        -- Marker für den Interaktionspunkt (optional, aber hilfreich für Tests)
        if not uiOpen then -- Marker nur zeichnen, wenn UI nicht offen ist, um Konflikte zu vermeiden
            DrawMarker(
                1, -- Marker-Typ
                lobbyInteractionPos.x, lobbyInteractionPos.y, lobbyInteractionPos.z - 0.98, -- Position (etwas unter dem Boden für bessere Sichtbarkeit)
                0.0, 0.0, 0.0, -- Richtung
                0.0, 0.0, 0.0, -- Rotation
                1.0, 1.0, 1.0, -- Skalierung
                0, 255, 0, 100, -- Farbe (Grün, halb-transparent)
                false, -- BobUpAndDown
                true,  -- FaceCamera
                2,     -- p19
                false, -- Rotate
                nil,   -- TextureDict
                nil,   -- TextureName
                false  -- DrawOnEnts
            )
        end
    end
end)

-- NUI Callback für das Schließen der UI
RegisterNUICallback('br:closeUi', function(data, cb)
    SetNuiFocus(false, false)
    uiOpen = false
    cb({ ok = true })
end)

-- NUI Callback für das Verlassen der Lobby (kann auch UI schließen)
RegisterNUICallback('br:leaveLobby', function(data, cb)
    -- Hier wird später die Server-Logik zum Verlassen der Lobby aufgerufen
    print("Client: Verlasse Lobby Event empfangen")
    -- Schließe UI und gib Fokus zurück, wird bereits in script.js gemacht, aber zur Sicherheit auch hier
    SetNuiFocus(false, false)
    uiOpen = false
    TriggerServerEvent('br:server:leaveLobby') -- Server benachrichtigen
    cb({ ok = true })
end)

-- NUI Callback für "Bereit"
RegisterNUICallback('br:ready', function(data, cb)
    print("Client: Bereit Event empfangen, Status: " .. tostring(data.ready))
    TriggerServerEvent('br:server:playerReady', data.ready)
    cb({ ok = true })
end)

-- Event vom Server, um Spieleranzahl zu aktualisieren
RegisterNetEvent('br:client:updatePlayerCount')
AddEventHandler('br:client:updatePlayerCount', function(count)
    SendNUIMessage({
        type = "updatePlayerCount",
        count = count
    })
end)

-- Event vom Server, um die UI zu schließen (z.B. bei Rundenstart)
RegisterNetEvent('br:client:forceCloseUi')
AddEventHandler('br:client:forceCloseUi', function()
    if uiOpen then
        SendNUIMessage({
            type = "ui",
            status = false
        })
        SetNuiFocus(false, false)
        uiOpen = false
    end
end)

-- Event vom Server, um den Spieler in der Luft zu spawnen
local spawnZoneCenter = vector3(2199.0, 5597.0, 500.0) -- Beispielkoordinaten über Sandy Shores Airfield, hohe Z für Spawn in der Luft
local spawnRadius = 200.0 -- Radius, in dem Spieler zufällig gespawnt werden

RegisterNetEvent('br:client:spawnPlayerInAir')
AddEventHandler('br:client:spawnPlayerInAir', function()
    local playerPed = PlayerPedId()

    DoScreenFadeOut(200) -- Fade out before teleport
    Citizen.Wait(250)

    local playerPed = PlayerPedId()
    local playerId = PlayerId()
    -- local model = `mp_m_freemode_01` -- Standard Freemode Model - Entfernt gemäß Anforderung

    print("br:client:spawnPlayerInAir - Starte Spawn für Spieler " .. playerId .. " mit eigenem Modell.")

    -- Modell laden - Entfernt
    -- RequestModel(model)
    -- local attempts = 0
    -- while not HasModelLoaded(model) and attempts < 100 do -- Max 100 Versuche (ca. 1 Sekunde)
    --     Citizen.Wait(10)
    --     attempts = attempts + 1
    -- end

    -- if not HasModelLoaded(model) then
    --     print("BR_DEBUG: Modell konnte nicht geladen werden: " .. model)
    --     DoScreenFadeIn(500)
    --     return -- Abbruch, wenn Modell nicht lädt
    -- end
    -- print("BR_DEBUG: Modell geladen: " .. model)

    -- SetPlayerModel(playerId, model) -- Entfernt
    -- SetModelAsNoLongerNeeded(model) -- Entfernt
    -- print("BR_DEBUG: Spielermodell gesetzt.") -- Entfernt

    -- Spieler an eine zufällige Position über der Zone teleportieren
    math.randomseed(GetGameTimer())
    local randomAngle = math.random() * 2 * math.pi
    local randomDist = math.random() * spawnRadius
    local spawnPos = vector3(
        spawnZoneCenter.x + math.cos(randomAngle) * randomDist,
        spawnZoneCenter.y + math.sin(randomAngle) * randomDist,
        spawnZoneCenter.z
    )
    print("BR_DEBUG: Ziel-Spawn-Position: x=" .. spawnPos.x .. ", y=" .. spawnPos.y .. ", z=" .. spawnPos.z)

    -- Versuche es mit NetworkResurrectLocalPlayer, das oft stabiler für Spawns ist
    NetworkResurrectLocalPlayer(spawnPos.x, spawnPos.y, spawnPos.z, math.random(0, 360) + 0.0, true, false)
    -- SetEntityCoords(playerPed, spawnPos.x, spawnPos.y, spawnPos.z, false, false, false, true) -- Alternative, falls Resurrect nicht wie gewünscht funktioniert
    print("BR_DEBUG: NetworkResurrectLocalPlayer aufgerufen.")

    -- Stelle sicher, dass der Ped-Handle nach Resurrect noch gültig ist oder neu geholt wird
    playerPed = PlayerPedId() -- Wichtig nach Resurrect oder wenn Ped sich ändern könnte

    SetEntityVisible(playerPed, true, false)
    print("BR_DEBUG: SetEntityVisible aufgerufen.")
    FreezeEntityPosition(playerPed, false)
    print("BR_DEBUG: FreezeEntityPosition aufgerufen.")
    SetPlayerInvincible(playerId, false)
    print("BR_DEBUG: SetPlayerInvincible aufgerufen.")

    SetPedMaxHealth(playerPed, 200) -- Max Health setzen bevor aktuelle Health gesetzt wird
    SetEntityHealth(playerPed, GetPedMaxHealth(playerPed)) -- Volle Gesundheit
    SetPedArmour(playerPed, 100)
    print("BR_DEBUG: Gesundheit und Rüstung gesetzt.")

    -- ClearPedTasksImmediately muss nach dem Setzen von Gesundheit/Position und vor dem Geben von Waffen/Fallschirm kommen.
    ClearPedTasksImmediately(playerPed)
    print("BR_DEBUG: Tasks gecleart VOR Waffen.")
    RemoveAllPedWeapons(playerPed, true)
    print("BR_DEBUG: Waffen entfernt.")

    -- Fallschirm geben und ausrüsten
    local parachuteHash = GetHashKey("GADGET_PARACHUTE")
    GiveWeaponToPed(playerPed, parachuteHash, 1, false, true)
    print("BR_DEBUG: Fallschirmwaffe gegeben.")
    SetPedGadget(playerPed, parachuteHash, true) -- Fallschirm ausrüsten / aktivieren für den Sprung
    print("BR_DEBUG: Fallschirmgadget gesetzt.")

    -- Erneutes Sicherstellen der Sichtbarkeit und des Status nach allen Operationen
    SetEntityVisible(playerPed, true, false)
    print("BR_DEBUG: Spieler sichtbar gesetzt (erneut).")
    FreezeEntityPosition(playerPed, false)
    print("BR_DEBUG: Spieler nicht mehr eingefroren (erneut).")
    ClearPedTasksImmediately(playerPed) -- Sicherstellen, dass keine Fallschirmanimation o.ä. den Spieler blockiert
    print("BR_DEBUG: Tasks gecleart NACH Waffen/Fallschirm.")

    DoScreenFadeIn(1000)
    print("BR_DEBUG: Spieler in der Luft bei " .. spawnPos .. " gespawnt mit Fallschirm.")
    TriggerServerEvent('br:server:playerSpawned')
end)

-- Zonen Variablen
local currentZone = {
    center = vector3(2199.0, 5597.0, 30.0), -- Startzentrum der Zone (auf dem Boden)
    radius = 1000.0, -- Startradius
    damagePerTick = 5,
    shrinkInterval = 60000, -- 60 Sekunden in Millisekunden
    shrinkAmount = 150.0, -- Um wie viel der Radius pro Intervall schrumpft
    minRadius = 50.0
}
local nextShrinkTime = 0
local zoneBlip = nil
local inGame = false -- Wird true, wenn der Spieler gespawnt wurde

-- Funktion zum Erstellen/Aktualisieren des Zonen-Blips auf der Karte
function UpdateZoneBlip()
    if zoneBlip then
        RemoveBlip(zoneBlip)
    end
    zoneBlip = AddBlipForRadius(currentZone.center.x, currentZone.center.y, currentZone.center.z, currentZone.radius)
    SetBlipColour(zoneBlip, 2) -- Rot
    SetBlipAlpha(zoneBlip, 100)
    SetBlipAsShortRange(zoneBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Sichere Zone")
    EndTextCommandSetBlipName(zoneBlip)
end

-- Event vom Server, um das Spiel zu starten und die Zone zu initialisieren
RegisterNetEvent('br:client:startGame')
AddEventHandler('br:client:startGame', function(initialZoneData)
    print("Client: Spiel gestartet, initialisiere Zone.")
    currentZone.center = initialZoneData.center
    currentZone.radius = initialZoneData.radius
    currentZone.shrinkInterval = initialZoneData.shrinkInterval
    currentZone.shrinkAmount = initialZoneData.shrinkAmount
    currentZone.minRadius = initialZoneData.minRadius
    currentZone.damagePerTick = initialZoneData.damagePerTick

    inGame = true
    nextShrinkTime = GetGameTimer() + currentZone.shrinkInterval
    UpdateZoneBlip()
    -- ShowHud(true) -- Entfernt, wird jetzt durch SetHudGameStatus gehandhabt
    if type(SetHudGameStatus) == "function" then
        SetHudGameStatus(true, nextShrinkTime)
    end
end)


-- Thread für Zonenlogik (Schaden, Verkleinerung, Visualisierung)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000) -- Überprüfung jede Sekunde

        if inGame then
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)

            -- Distanz zum Zentrum der Zone (nur X und Y berücksichtigen für 2D-Distanz)
            local distanceToCenter = #(vector2(playerCoords.x, playerCoords.y) - vector2(currentZone.center.x, currentZone.center.y))

            -- Schaden außerhalb der Zone
            if distanceToCenter > currentZone.radius then
                ApplyDamageToPed(playerPed, currentZone.damagePerTick, true)
                ShowHelpNotification("Du bist außerhalb der sicheren Zone! Kehre zurück!")
                -- TODO: Visuellen Effekt für Schaden hinzufügen (z.B. Screen-Effekt)
            end

            -- Zonenverkleinerung
            if GetGameTimer() >= nextShrinkTime and currentZone.radius > currentZone.minRadius then
                local newRadius = currentZone.radius - currentZone.shrinkAmount
                currentZone.radius = math.max(newRadius, currentZone.minRadius) -- Sicherstellen, dass der Radius nicht kleiner als minRadius wird

                print("Zone schrumpft auf Radius: " .. currentZone.radius)
                UpdateZoneBlip()
                -- TODO: Neues Zentrum für die nächste Verkleinerung bestimmen (optional, für bewegliche Zonen)

                nextShrinkTime = GetGameTimer() + currentZone.shrinkInterval
                if type(UpdateNextShrinkTime) == "function" then
                    UpdateNextShrinkTime(nextShrinkTime) -- Sende die neue Zeit an client_hud.lua
                end
            elseif currentZone.radius <= currentZone.minRadius then
                -- Die Zone hat ihre minimale Größe erreicht, keine weitere Verkleinerung.
                nextShrinkTime = GetGameTimer() + currentZone.shrinkInterval * 100 -- Verhindert weiteres Schrumpfen
                if type(UpdateNextShrinkTime) == "function" then
                    UpdateNextShrinkTime(nextShrinkTime)
                end
            end
        end
    end
end)

-- Thread für die visuelle Darstellung der Zone (Bubble)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0) -- Jeden Frame ausführen

        if inGame then
            -- Zeichne eine Blase für die Zone
            -- Parameter: type, posX, posY, posZ, dirX, dirY, dirZ, rotX, rotY, rotZ, scaleX, scaleY, scaleZ, r, g, b, alpha, bobUpAndDown, faceCamera, p19, rotate, textureDict, textureName, drawOnEnts
            DrawMarker(
                1, -- Typ 1 ist eine Kugel/Blase, die von innen nicht sichtbar ist. Besser wäre ein Zylinder oder mehrere Kreise.
                   -- Für eine bessere sichtbare "Wand" könnte man DrawCylinder oder mehrere Marker verwenden.
                currentZone.center.x, currentZone.center.y, currentZone.center.z, -- Position (am Boden)
                0.0, 0.0, 0.0,  -- Richtung
                0.0, 0.0, 0.0,  -- Rotation
                currentZone.radius * 2.0, currentZone.radius * 2.0, 500.0, -- Skalierung (Durchmesser, Höhe der Blase)
                0, 150, 255, 50, -- Farbe (Blau, leicht transparent)
                false,          -- BobUpAndDown
                false,          -- FaceCamera (false damit es sich wie eine Wand verhält)
                2,              -- p19
                false,          -- Rotate
                nil,            -- TextureDict
                nil,            -- TextureName
                false           -- DrawOnEnts
            )

            -- Alternative: Einen Zylinder zeichnen (besser sichtbar als Wand)
            -- DrawCylinder(currentZone.center.x, currentZone.center.y, currentZone.center.z - 100.0, currentZone.center.x, currentZone.center.y, currentZone.center.z + 300.0, currentZone.radius, 0, 150, 255, 80)

            -- Einen Kreis am Boden zeichnen
            local foundGround, groundZ = GetGroundZFor_3dCoord(currentZone.center.x, currentZone.center.y, currentZone.center.z + 20.0, false)
            local markerZ = currentZone.center.z + 0.1 -- Fallback Z
            if foundGround then
                markerZ = groundZ + 0.1
            end
            DrawMarker(
                28, -- Typ 28 ist ein flacher Kreis (Chevron-Muster)
                currentZone.center.x, currentZone.center.y, markerZ,
                0.0, 0.0, 0.0,
                180.0, 0.0, 0.0, -- Rotiert, um flach auf dem Boden zu liegen
                currentZone.radius * 2.0, currentZone.radius * 2.0, 1.0, -- Skalierung
                0, 150, 255, 100, -- Farbe
                false, false, 2, false, nil, nil, false
            )
        end
    end
end)

-- Wenn der Spieler stirbt, muss inGame auf false gesetzt werden.
AddEventHandler('baseevents:onPlayerKilled', function(killerId, data)
    if inGame then
        print("Spieler gestorben, Zone wird deaktiviert für diesen Client.")
        inGame = false
        if zoneBlip then
            RemoveBlip(zoneBlip)
            zoneBlip = nil
        end
        -- Hier könnte man eine Spectator-Funktion oder ähnliches aufrufen
        -- Oder den Spieler zurück zur Lobby schicken (serverseitig gesteuert)
    end
end)

-- Wenn die Ressource gestoppt wird, Blip entfernen
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        if zoneBlip then
            RemoveBlip(zoneBlip)
        end
        -- ShowHud(false) wird nun durch SetHudGameStatus in client_hud.lua gehandhabt
        if type(SetHudGameStatus) == "function" then
            SetHudGameStatus(false, 0)
        end
    end
end)

-- HUD STEUERUNG UND DATENAKTUALISIERUNG wurde nach client_hud.lua verschoben
-- local hudVisible = false -- Entfernt
-- function ShowHud(show) -- Entfernt
-- -- Thread zur regelmäßigen Aktualisierung der HUD-Daten -- Entfernt
-- RegisterNetEvent('br:client:updateAliveCount') -- Entfernt (Handler ist in client_hud.lua)
-- RegisterNetEvent('br:client:updateKillCount') -- Entfernt (Handler ist in client_hud.lua)


-- Der bestehende 'br:client:startGame' Handler wird modifiziert, um ShowHud aufzurufen.
-- Kein neuer Handler wird hinzugefügt. Der vorherige Block war ein Fehler.
-- (Der Code für 'br:client:startGame' ist weiter oben in der Datei und wird hier nicht erneut gezeigt,
-- aber es wird davon ausgegangen, dass ShowHud(true) dort eingefügt wird.)

-- Beim Tod des Spielers oder wenn inGame false wird
local originalOnPlayerKilledHandler = nil
if type(RemoveEventHandler) == 'function' and type(AddEventHandler) == 'function' then
    -- Versuche, den alten Handler zu entfernen, falls er existiert und wir ihn überschreiben wollen.
    -- Dies ist ein bisschen heikel, da wir nicht wissen, ob baseevents:onPlayerKilled bereits existiert.
    -- Für dieses Beispiel fügen wir einfach einen neuen hinzu oder modifizieren den bestehenden.
    -- Es ist besser, eigene Events zu verwenden, wenn möglich.
end

AddEventHandler('baseevents:onPlayerKilled', function(killerEntity, data)
    -- killerEntity ist die Entity-ID des Killers, nicht die Spieler-ID oder Server-ID.
    -- data enthält Informationen wie killerType, weaponHash etc.
    if inGame then
        local victimServerId = PlayerServerId()
        local killerServerId = nil

        if killerEntity ~= 0 and killerEntity ~= PlayerPedId() and IsEntityAPed(killerEntity) and IsPedAPlayer(killerEntity) then
            -- Es gibt einen Killer, der ein anderer Spieler ist
            local killerPlayer = NetworkGetPlayerIndexFromPed(killerEntity)
            if GetPlayerServerId(killerPlayer) then -- Sicherstellen, dass der Spieler noch verbunden ist
                 killerServerId = GetPlayerServerId(killerPlayer)
            end
        end

        print("Spieler " .. victimServerId .. " gestorben. Killer-Entity: " .. killerEntity .. ", Killer-ServerID: " .. tostring(killerServerId) .. ", Waffe: " .. data.weaponHash)
        TriggerServerEvent('br:server:playerDied', victimServerId, killerServerId, data.weaponHash)

        -- SetInGameStatus(false) -- Alt, wird durch direkten Aufruf von SetHudGameStatus und inGame = false ersetzt
        inGame = false
        if type(SetHudGameStatus) == "function" then
            SetHudGameStatus(false, 0)
        end

        if zoneBlip then
            RemoveBlip(zoneBlip)
            zoneBlip = nil
        end
    end
end)

-- Die Funktion SetInGameStatus wurde effektiv durch die Logik in client_hud.lua (SetHudGameStatus)
-- und die direkte Steuerung der `inGame` Variable hier ersetzt.

-- Beispiel: Event vom Server, um das Spiel offiziell zu beenden
RegisterNetEvent('br:client:roundOver')
AddEventHandler('br:client:roundOver', function(winnerName)
    print("BR_DEBUG: Runde ist serverseitig beendet. Gewinner: " .. tostring(winnerName))
    -- SetInGameStatus(false) -- Alt
    inGame = false
    if type(SetHudGameStatus) == "function" then
        SetHudGameStatus(false, 0)
    end
    if zoneBlip then
        RemoveBlip(zoneBlip)
        zoneBlip = nil
    end
    -- TODO: Zeige Gewinner-Nachricht in der UI
end)

-- Die Event-Handler für br:client:updateAliveCount und br:client:updateKillCount wurden nach client_hud.lua verschoben.

-- Exportiere die Funktion, damit andere clientseitige Skripte sie nutzen können
exports('ShowHelpNotificationExport', ShowHelpNotification)
