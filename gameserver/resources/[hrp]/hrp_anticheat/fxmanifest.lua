fx_version 'cerulean'
game 'gta5'

name 'hrp_anticheat'
description 'HardcoreRP – Anti-Cheat: server-seitige Plausibilitätsprüfungen, Strike-System'
version '1.0.0'

dependencies {
    'hrp_core',
}

server_scripts {
    'server/main.lua',
}

server_only 'yes'
