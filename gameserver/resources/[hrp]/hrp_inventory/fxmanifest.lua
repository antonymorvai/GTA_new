fx_version 'cerulean'
game 'gta5'

name 'hrp_inventory'
description 'HardcoreRP – Inventar-Basis: Item-Instanzen (UUID), Locations, Gewicht, Lifecycle-Logging'
version '1.0.0'

dependencies {
    'hrp_core',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/events.lua',
}

server_only 'yes'
