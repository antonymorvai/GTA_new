fx_version 'cerulean'
game 'gta5'

name 'hrp_resources'
description 'HardcoreRP – Dynamische Ressourcen: endliche, regenerierende Pools'
version '1.0.0'

dependencies {
    'hrp_core',
    'hrp_inventory',
    'hrp_skills',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
}
