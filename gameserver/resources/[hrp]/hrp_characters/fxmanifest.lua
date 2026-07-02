fx_version 'cerulean'
game 'gta5'

name 'hrp_characters'
description 'HardcoreRP – Multi-Charakter (3 Slots), Erstellung, Spawn, periodischer Save'
version '1.0.0'

dependencies {
    'hrp_core',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
}

ui_page 'nui/index.html'

files {
    'nui/index.html',
    'nui/app.js',
    'nui/style.css',
}
