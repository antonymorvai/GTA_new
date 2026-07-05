fx_version 'cerulean'
game 'gta5'

name 'hrp_territories'
description 'HardcoreRP – Gang-Territorien: Einfluss als kontinuierlicher Wert mit Verfall'
version '1.0.0'

dependencies {
    'hrp_core',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

server_only 'yes'
