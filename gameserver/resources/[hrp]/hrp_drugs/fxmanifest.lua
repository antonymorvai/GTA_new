fx_version 'cerulean'
game 'gta5'

name 'hrp_drugs'
description 'HardcoreRP – illegale Kette: Anbau -> Verarbeitung -> Verkauf mit Spuren'
version '1.0.0'

dependencies {
    'hrp_core',
    'hrp_inventory',
    'hrp_skills',
    'hrp_territories',
    'hrp_jobs',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
}
