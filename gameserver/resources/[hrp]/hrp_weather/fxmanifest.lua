fx_version 'cerulean'
game 'gta5'

name 'hrp_weather'
description 'HardcoreRP – Wetterfronten + synchrone Uhrzeit (server-autoritativ)'
version '1.0.0'

dependencies {
    'hrp_core',
}

shared_scripts {
    'shared/weather.lua',
}

server_scripts {
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
}
