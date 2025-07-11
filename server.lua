-- server.lua
print("Battle Royale Server Skript geladen")

local lobbyPlayers = {} -- Tabelle, um Spieler in der Lobby zu speichern {source = PlayerId, ready = false}
local gameSettings = {
    minPlayersToStart = 1,
    countdownDuration = 5 -- Sekunden
}
local gameInProgress = false -- Bleibt true, solange eine Runde potenziell läuft oder in Vorbereitung ist
local roundActive = false -- Wird true, wenn Spieler gespawnt sind und die Runde tatsächlich läuft
local countdownTimer = nil
local alivePlayersInRound = {} -- Tabelle, um die Quellen der lebenden Spieler zu speichern
local playerKills = {} -- Tabelle zum Speichern der Kills: playerKills[source] = killCount

-- Funktion, um die Spieleranzahl an alle Clients zu senden
function UpdatePlayerCount()
    local readyPlayerCount = 0
    for _, playerData in pairs(lobbyPlayers) do
        if playerData.ready then
            readyPlayerCount = readyPlayerCount + 1
        end
    end
    -- Sende die Anzahl der bereiten Spieler an alle Clients
    -- oder die Gesamtanzahl, je nachdem was in der UI angezeigt werden soll.
    -- Aktuell senden wir die Gesamtanzahl der Spieler in der Lobby.
    TriggerClientEvent('br:client:updatePlayerCount', -1, #lobbyPlayers)
end

-- Event-Handler, wenn ein Spieler dem Server beitritt
AddEventHandler('playerJoining', function()
    -- Optional: Aktionen beim Betreten des Servers, falls relevant für die Lobby
end)

-- Event-Handler, wenn ein Spieler den Server verlässt
AddEventHandler('playerDropped', function(reason)
    local source = source
    if lobbyPlayers[source] then
        print("Spieler " .. GetPlayerName(source) .. " hat die Lobby verlassen (Verbindung getrennt).")
        lobbyPlayers[source] = nil
        UpdatePlayerCount()
        CheckAndStartGame() -- Überprüfen, ob das Spiel abgebrochen werden muss, falls der letzte bereite Spieler geht
    end
end)

-- Event vom Client, wenn ein Spieler bereit ist
RegisterNetEvent('br:server:playerReady')
AddEventHandler('br:server:playerReady', function(isReady)
    local source = source
    if not gameInProgress then
        if lobbyPlayers[source] then
            lobbyPlayers[source].ready = isReady
            print("Spieler " .. GetPlayerName(source) .. " ist " .. (isReady and "bereit" or "nicht mehr bereit") .. ".")
        else
            -- Spieler zur Lobby hinzufügen, wenn er auf "Bereit" klickt und noch nicht drin ist
            lobbyPlayers[source] = { id = source, ready = isReady }
            print("Spieler " .. GetPlayerName(source) .. " ist der Lobby beigetreten und " .. (isReady and "bereit" or "nicht bereit") .. ".")
        end
        UpdatePlayerCount()
        CheckAndStartGame()
    else
        print("Spiel kann nicht beigetreten werden, da es bereits läuft.")
        -- Optional: Nachricht an Client senden
    end
end)

-- Event vom Client, wenn ein Spieler die Lobby verlässt (über UI-Button)
RegisterNetEvent('br:server:leaveLobby')
AddEventHandler('br:server:leaveLobby', function()
    local source = source
    if lobbyPlayers[source] then
        print("Spieler " .. GetPlayerName(source) .. " hat die Lobby verlassen.")
        lobbyPlayers[source] = nil
        UpdatePlayerCount()
        CheckAndStartGame() -- Überprüfen, ob das Spiel abgebrochen werden muss
    end
end)

-- Funktion zum Überprüfen und Starten des Spiels
function CheckAndStartGame()
    if gameInProgress then return end

    local readyPlayers = {}
    for src, data in pairs(lobbyPlayers) do
        if data.ready then
            table.insert(readyPlayers, src)
        end
    end

    print("Bereite Spieler: " .. #readyPlayers .. ", Benötigt: " .. gameSettings.minPlayersToStart)

    if #readyPlayers >= gameSettings.minPlayersToStart then
        if not countdownTimer then
            StartGameCountdown(readyPlayers)
        end
    else
        if countdownTimer then
            -- Countdown abbrechen, wenn nicht mehr genug Spieler bereit sind
            print("Countdown abgebrochen, nicht genügend bereite Spieler.")
            ClearTimer(countdownTimer)
            countdownTimer = nil
            -- TODO: Clients informieren, dass der Countdown abgebrochen wurde
        end
    end
end

function StartGameCountdown(playersToStart)
    gameInProgress = true -- Verhindert, dass neue Spieler beitreten oder der Countdown erneut startet
    local timeLeft = gameSettings.countdownDuration
    print("Spiel startet in " .. timeLeft .. " Sekunden für " .. #playersToStart .. " Spieler.")

    -- TODO: Countdown an Clients senden, damit sie ihn anzeigen können

    countdownTimer = SetInterval(function()
        timeLeft = timeLeft - 1
        print("Spiel startet in: " .. timeLeft)
        -- TODO: Countdown-Aktualisierung an Clients senden

        if timeLeft <= 0 then
            ClearTimer(countdownTimer)
            countdownTimer = nil
            print("Countdown beendet. Starte Spiel!")
            StartRound(playersToStart)
        end
    end, 1000)
end

function StartRound(players)
    print("Runde wird gestartet für Spieler: ", table.concat(players, ", "))
    -- UI bei allen Clients schließen
    TriggerClientEvent('br:client:forceCloseUi', -1)

    for _, playerSrc in ipairs(players) do
        -- Spieler aus der Lobby entfernen, da sie jetzt im Spiel sind
        -- lobbyPlayers[playerSrc] = nil -- Oder markiere sie als 'im Spiel'

        -- Hier kommt die Logik zum Spawnen der Spieler in der Luft etc.
        TriggerClientEvent('br:client:spawnPlayerInAir', playerSrc)
    end
    -- UpdatePlayerCount() -- Lobby ist jetzt leer oder enthält nur nicht-spielende Spieler
    -- gameInProgress bleibt true bis Rundenende
    -- Reset für nächste Runde muss implementiert werden
    StartZoneLogic(players)
end

function StartZoneLogic(playersInGame)
    local initialZoneData = {
        center = vector3(2199.0, 5597.0, 30.0), -- Muss mit client.lua übereinstimmen oder von hier gesendet werden
        radius = 1000.0,
        shrinkInterval = 60000, -- 60 Sekunden
        shrinkAmount = 150.0,
        minRadius = 50.0,
        damagePerTick = 5 -- Schaden pro Sekunde außerhalb der Zone
    }
    -- Sende die initialen Zonendaten an alle Spieler, die im Spiel sind
    for _, playerSrc in ipairs(playersInGame) do
        TriggerClientEvent('br:client:startGame', playerSrc, initialZoneData)
    end
    print("Zonenlogik gestartet und Daten an Clients gesendet.")

    -- Trigger das Loot-Spawning
    local lootboxCount = 15 -- Beispiel: Anzahl der Lootboxen
    TriggerEvent('br:server:startLootSpawning', initialZoneData, lootboxCount)
    print("Loot Spawning getriggert mit " .. lootboxCount .. " Boxen.")

    -- Hier könnte man serverseitig die Zonenveränderung auch tracken, falls nötig für serverseitige Checks oder Logik
    roundActive = true
    alivePlayersInRound = {}
    playerKills = {} -- Kills für die neue Runde zurücksetzen
    for _, playerSrc in ipairs(playersInGame) do
        table.insert(alivePlayersInRound, playerSrc)
        playerKills[playerSrc] = 0 -- Initialisiere Kills für jeden Spieler mit 0
        TriggerClientEvent('br:client:updateKillCount', playerSrc, 0) -- Sende initiale Kill-Anzahl (0)
    end
    TriggerClientEvent('br:client:updateAliveCount', -1, #alivePlayersInRound)
    print("Runde aktiv. Lebende Spieler initial: " .. #alivePlayersInRound)
end

AddEventHandler('playerDropped', function(reason)
    local source = source
    if playerKills[source] then -- Entferne Spieler auch aus der Kill-Liste
        playerKills[source] = nil
    end
    if lobbyPlayers[source] then
        print("Spieler " .. GetPlayerName(source) .. " hat die Lobby verlassen (Verbindung getrennt).")
        lobbyPlayers[source] = nil
        UpdatePlayerCount()
        CheckAndStartGame()
    end

    -- Entferne Spieler aus der Liste der lebenden Spieler, falls er in der Runde war
    local found = false
    for i, playerSrc in ipairs(alivePlayersInRound) do
        if playerSrc == source then
            table.remove(alivePlayersInRound, i)
            found = true
            break
        end
    end
    if found and roundActive then
        print("Spieler " .. GetPlayerName(source) .. " hat während der Runde die Verbindung getrennt. Verbleibende Spieler: " .. #alivePlayersInRound)
        TriggerClientEvent('br:client:updateAliveCount', -1, #alivePlayersInRound)
        CheckForWinner()
    end
end)

-- Serverseitiges Event, wenn ein Spieler stirbt (muss von client.lua getriggert werden, wenn baseevents nicht serverseitig verfügbar ist ODER man nutzt server-seitige Tod Erkennung)
-- Für dieses Beispiel gehen wir davon aus, dass wir 'playerDied' serverseitig haben oder ein Äquivalent.
-- FiveM hat kein eingebautes serverseitiges 'playerDied', das den Killer direkt liefert.
-- Man muss dies oft clientseitig erkennen und an den Server senden oder komplexere Logik verwenden.
-- Wir simulieren hier, dass wir den toten Spieler entfernen. Die Kill-Logik kommt später.

RegisterNetEvent('br:server:playerDied')
AddEventHandler('br:server:playerDied', function(victimSource, killerSource, weaponHash)
    local victimName = GetPlayerName(victimSource)
    local killerName = "Umwelt/Selbst"

    if killerSource and killerSource ~= 0 then
        killerName = GetPlayerName(killerSource)
        if playerKills[killerSource] then
            playerKills[killerSource] = playerKills[killerSource] + 1
            TriggerClientEvent('br:client:updateKillCount', killerSource, playerKills[killerSource])
            print("Spieler " .. killerName .. " (Source: " .. killerSource .. ") hat Spieler " .. victimName .. " (Source: " .. victimSource .. ") getötet. Kills: " .. playerKills[killerSource])
        else
            print("WARNUNG: Killer " .. killerName .. " (Source: " .. killerSource .. ") nicht in playerKills Tabelle gefunden.")
        end
    else
        print("Spieler " .. victimName .. " (Source: " .. victimSource .. ") ist durch Umwelt oder Selbstverschulden gestorben.")
    end

    local removed = false
    for i, playerSrcInList in ipairs(alivePlayersInRound) do
        if playerSrcInList == victimSource then
            table.remove(alivePlayersInRound, i)
            removed = true
            break
        end
    end

    if removed and roundActive then
        print("Verbleibende Spieler: " .. #alivePlayersInRound)
        TriggerClientEvent('br:client:updateAliveCount', -1, #alivePlayersInRound)
        CheckForWinner()
    elseif not removed and roundActive then
        print("WARNUNG: Verstorbener Spieler " .. victimName .. " (Source: " .. victimSource .. ") nicht in alivePlayersInRound gefunden beim Versuch zu entfernen.")
    end
end)

function CheckForWinner()
    if roundActive and #alivePlayersInRound <= 1 then
        local winnerName = "Niemand"
        if #alivePlayersInRound == 1 then
            winnerName = GetPlayerName(alivePlayersInRound[1])
        end
        print("RUNDE BEENDET! Gewinner: " .. winnerName)
        TriggerClientEvent('br:client:roundOver', -1, winnerName) -- Sende an alle Clients, dass die Runde vorbei ist

        -- Reset für die nächste Runde / Lobby
        roundActive = false
        gameInProgress = false -- Erlaube neuen Lobby-Beitritt / Spielstart
        alivePlayersInRound = {}
        -- Hier könnte man Spieler zurück in die Lobby teleportieren oder ähnliches.
        -- Fürs Erste wird nur der Status zurückgesetzt.
        -- TODO: Spieler über Rundenende und Gewinner informieren (z.B. UI-Nachricht)
    end
end


-- Event, das vom Client ausgelöst wird, nachdem er gespawnt wurde.
-- Dies könnte verwendet werden, um zu bestätigen, dass alle Spieler bereit sind, bevor die Zone offiziell startet.
-- Aktuell wird StartZoneLogic direkt nach dem Spawnbefehl aufgerufen.
-- Man könnte eine Zählung einbauen, um sicherzustellen, dass alle Spieler 'spawned' gemeldet haben.
local spawnedPlayerCount = 0
RegisterNetEvent('br:server:playerSpawned')
AddEventHandler('br:server:playerSpawned', function()
    local source = source
    -- Man könnte hier zählen, wie viele Spieler gespawnt sind,
    -- bevor die Zone für alle gleichzeitig aktiviert wird.
    -- Fürs Erste starten wir die Zone direkt in StartRound.
    print("Spieler " .. GetPlayerName(source) .. " ist im Spiel gespawnt.")
end)


-- Hilfsfunktionen für Timer (falls nicht schon vorhanden)
-- Diese sind oft in Frameworks enthalten, hier eine einfache Implementierung:
local timers = {}
function SetInterval(callback, ms)
    local id = #timers + 1
    timers[id] = Citizen.CreateThread(function()
        while timers[id] do -- Solange der Timer existiert
            Citizen.Wait(ms)
            if timers[id] then -- Erneute Prüfung, falls er während Wait gelöscht wurde
                callback()
            end
        end
    end)
    return id
end

function ClearTimer(id)
    if timers[id] then
        -- Um den Thread sicher zu beenden, setzen wir timers[id] auf nil.
        -- Der Thread selbst wird beim nächsten Durchlauf der Schleife beendet.
        local threadToStop = timers[id]
        timers[id] = nil -- Signalisiert dem Thread, sich zu beenden
        -- Citizen.DeleteResourceThread(threadToStop) -- Nicht empfohlen, kann zu Abstürzen führen
        print("Timer " .. id .. " gestoppt.")
    end
end
