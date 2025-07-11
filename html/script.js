// script.js
document.addEventListener('DOMContentLoaded', () => {
    // Elemente für Lobby UI
    const lobbyContainer = document.getElementById('lobby-container');
    const readyButton = document.getElementById('ready-button');
    const leaveButton = document.getElementById('leave-button');
    const closeButton = document.getElementById('close-button');
    const playerCountSpan = document.getElementById('player-count');

    // Elemente für HUD UI (aus hud.js)
    const hudContainer = document.getElementById('hud-container');
    const healthDisplay = document.getElementById('health');
    const healthBar = document.getElementById('health-bar');
    const armourDisplay = document.getElementById('armour');
    const armourBar = document.getElementById('armour-bar');
    const alivePlayersDisplay = document.getElementById('alive-players');
    const killsDisplay = document.getElementById('kills');
    const zoneTimerDisplay = document.getElementById('zone-timer');

    // Elemente für Hotbar (neu)
    const hotbarContainer = document.getElementById('hotbar-container');
    const hotbarSlots = [];
    for (let i = 1; i <= 5; i++) {
        const slotElement = document.querySelector(`.hotbar-slot[data-slotid="${i}"]`);
        if (slotElement) {
            hotbarSlots.push({
                container: slotElement,
                icon: slotElement.querySelector('.slot-icon'),
                quantity: slotElement.querySelector('.slot-quantity')
            });
        } else {
            console.warn(`Hotbar-Slot ${i} nicht im DOM gefunden.`);
            hotbarSlots.push(null); // Platzhalter, falls ein Slot fehlt
        }
    }


    // Funktion, um NUI-Nachrichten an den Lua-Skript zu senden
    async function post(eventName, data = {}) {
        try {
            // Verwende GetParentResourceName(), um den Ressourcennamen dynamisch zu erhalten
            const resourceName = window.GetParentResourceName ? window.GetParentResourceName() : 'DEIN_FALLBACK_RESSOURCEN_NAME';
            const response = await fetch(`https://${resourceName}/${eventName}`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json; charset=UTF-8',
                },
                body: JSON.stringify(data),
            });
            // Überprüfe, ob die Antwort JSON ist, bevor sie geparst wird
            const contentType = response.headers.get("content-type");
            if (contentType && contentType.indexOf("application/json") !== -1) {
                return await response.json();
            } else {
                return await response.text(); // oder null, oder eine Fehlerbehandlung
            }
        } catch (error) {
            console.error('Fehler beim Senden der NUI-Nachricht an ' + eventName + ':', error);
            return null;
        }
    }

    // Event Listener für Lobby UI Buttons
    if (readyButton) readyButton.addEventListener('click', () => {
        console.log('Bereit Button geklickt');
        post('br:ready', { ready: true });
    });

    if (leaveButton) leaveButton.addEventListener('click', () => {
        console.log('Verlassen Button geklickt');
        post('br:leaveLobby');
        if (lobbyContainer) lobbyContainer.style.display = 'none';
        post('br:closeUi');
    });

    if (closeButton) closeButton.addEventListener('click', () => {
        console.log('Schließen Button geklickt');
        if (lobbyContainer) lobbyContainer.style.display = 'none';
        post('br:closeUi');
    });

    // Funktion zum Formatieren der Timer-Anzeige (Millisekunden zu MM:SS) - aus hud.js
    function formatTime(ms) {
        if (ms < 0) ms = 0;
        const totalSeconds = Math.floor(ms / 1000);
        const minutes = Math.floor(totalSeconds / 60);
        const seconds = totalSeconds % 60;
        return `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
    }

    // Kombinierter Event Listener für Nachrichten von Lua
    window.addEventListener('message', (event) => {
        const item = event.data; // In hud.js war es 'data', hier 'item' genannt, vereinheitlichen wir auf 'item'

        // Lobby UI Logik
        if (item.type === 'ui') {
            if (lobbyContainer) {
                lobbyContainer.style.display = item.status === true ? 'block' : 'none';
            }
        }
        if (item.type === 'updatePlayerCount') {
            if (playerCountSpan) {
                playerCountSpan.textContent = item.count;
            }
        }

        // HUD UI Logik (aus hud.js)
        if (item.type === 'hud') {
            const displayStyle = item.status ? 'flex' : 'none';
            if (hudContainer) {
                hudContainer.style.display = displayStyle;
            }
            if (hotbarContainer) { // Hotbar zusammen mit HUD ein-/ausblenden
                hotbarContainer.style.display = displayStyle;
            }
        }
        if (item.type === 'updateHudStats') {
            if (healthDisplay && healthBar) {
                const currentHealth = Math.max(0, item.health || 0);
                const maxHealth = item.maxHealth || 200;
                healthDisplay.textContent = currentHealth;
                healthBar.style.width = `${Math.min(100, (currentHealth / maxHealth) * 100)}%`;
            }
            if (armourDisplay && armourBar) {
                const currentArmour = item.armour || 0;
                const maxArmour = 100;
                armourDisplay.textContent = currentArmour;
                armourBar.style.width = `${(currentArmour / maxArmour) * 100}%`;
            }
            if (zoneTimerDisplay && typeof item.zoneTimeLeft !== 'undefined') {
                zoneTimerDisplay.textContent = formatTime(item.zoneTimeLeft);
            }
        }
        if (item.type === 'updateAliveCount' && alivePlayersDisplay) {
            alivePlayersDisplay.textContent = item.count;
        }
        if (item.type === 'updateKillCount' && killsDisplay) {
            killsDisplay.textContent = item.count;
        }

        // Hotbar Logik (neu)
        if (item.type === 'updateHotbarSlot') {
            const slotIndex = item.slotId - 1; // slotId ist 1-basiert
            if (hotbarSlots[slotIndex]) {
                const slot = hotbarSlots[slotIndex];
                if (item.iconUrl && item.iconUrl !== "") {
                    slot.icon.src = item.iconUrl;
                    slot.icon.style.display = 'block';
                    slot.container.title = item.itemName || ''; // Tooltip
                } else {
                    slot.icon.src = '';
                    slot.icon.style.display = 'none';
                    slot.container.title = '';
                }
                if (item.quantity !== null && typeof item.quantity !== 'undefined') {
                    slot.quantity.textContent = item.quantity > 1 ? item.quantity : ''; // Menge nur anzeigen, wenn > 1
                } else {
                    slot.quantity.textContent = '';
                }
            }
        }
        if (item.type === 'clearHotbar') {
            hotbarSlots.forEach(slot => {
                if (slot) {
                    slot.icon.src = '';
                    slot.icon.style.display = 'none';
                    slot.quantity.textContent = '';
                    slot.container.title = '';
                }
            });
        }
    });

    // Fallback für GetParentResourceName, falls es nicht in der FiveM Umgebung läuft (für Browser-Tests)
    if (typeof GetParentResourceName === 'undefined') {
        window.GetParentResourceName = () => 'DEIN_RESSOURCEN_NAME_HIER'; // Ersetzen mit dem tatsächlichen Ressourcennamen für Tests
        console.warn('GetParentResourceName nicht gefunden, Fallback für lokale Tests verwendet. Ersetze DEIN_RESSOURCEN_NAME_HIER mit dem Namen deiner Ressource.');
    }
});
