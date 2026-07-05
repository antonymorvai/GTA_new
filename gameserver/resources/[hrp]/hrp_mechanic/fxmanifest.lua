fx_version 'cerulean'
game 'gta5'

name 'hrp_mechanic'
description 'HardcoreRP – Mechaniker: Reparaturen mit Rechnung (Spieler-zu-Spieler)'
version '1.0.0'

dependencies {
    'hrp_core',
    'hrp_jobs',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

server_only 'yes'
