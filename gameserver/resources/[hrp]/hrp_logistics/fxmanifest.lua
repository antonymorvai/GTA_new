fx_version 'cerulean'
game 'gta5'

name 'hrp_logistics'
description 'HardcoreRP – Lieferketten: Tankstellen-Bestände + Trucker-Belieferung'
version '1.0.0'

dependencies {
    'hrp_core',
    'hrp_jobs',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
}
