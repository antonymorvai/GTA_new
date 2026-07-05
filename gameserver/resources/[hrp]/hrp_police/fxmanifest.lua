fx_version 'cerulean'
game 'gta5'

name 'hrp_police'
description 'HardcoreRP – Polizei: MDT-Datenbasis, Strafregister, Fahndungen, Beweismittelkette'
version '1.0.0'

dependencies {
    'hrp_core',
    'hrp_jobs',
    'hrp_inventory',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

server_only 'yes'
