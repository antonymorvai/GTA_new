fx_version 'cerulean'
game 'gta5'

name 'hrp_companies'
description 'HardcoreRP – Firmen: Handelsregister, Mitglieder, Firmenkonto, Lohnlauf'
version '1.0.0'

dependencies {
    'hrp_core',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

server_only 'yes'
