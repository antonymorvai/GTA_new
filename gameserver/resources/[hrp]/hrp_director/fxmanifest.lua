fx_version 'cerulean'
game 'gta5'

name 'hrp_director'
description 'HardcoreRP – World Director: gewichtete Zufallsereignisse, live steuerbar'
version '1.0.0'

dependencies {
    'hrp_core',
}

server_scripts {
    'server/main.lua',
}

server_only 'yes'
