-- fxmanifest.lua
fx_version 'cerulean'
game 'gta5'

author 'Jules @ AI'
description 'Einfaches Battle Royale Skript'
version '0.0.1'

client_scripts {
    'client.lua',
    'client_hud.lua',
    'client_loot.lua'
}

server_scripts {
    'server.lua',
    'server_loot.lua'
}

shared_script 'config_lootboxes.lua'

ui_page 'html/ui.html' -- Nur noch eine ui_page

files {
    'html/ui.html',
    'html/style.css',
    'html/script.js',
    'html/img/icons/*.png', -- Hinzugefügt für die Icons
    'database_schema.sql'
}
