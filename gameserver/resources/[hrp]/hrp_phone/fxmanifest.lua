fx_version 'cerulean'
game 'gta5'

name 'hrp_phone'
description 'HardcoreRP – Smartphone-Basis: Rufnummern, Kontakte, SMS (comms.sms-Logging)'
version '1.0.0'

dependencies {
    'hrp_core',
    'hrp_inventory',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
}
