fx_version 'cerulean'
game 'gta5'

name 'hrp_voice'
description 'HardcoreRP – Funk: Frequenzen, verschlüsselte Polizei-Kanäle, SaltyChat-Brücke'
version '1.0.0'

dependencies {
    'hrp_core',
    'hrp_inventory',
    'hrp_jobs',
}

server_scripts {
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
}
