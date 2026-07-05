fx_version 'cerulean'
game 'gta5'

name 'hrp_weapons'
description 'HardcoreRP – Waffen als Item-Instanzen: Ausrüsten, Munition, Schusszähler'
version '1.0.0'

dependencies {
    'hrp_core',
    'hrp_inventory',
}

server_scripts {
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
}
