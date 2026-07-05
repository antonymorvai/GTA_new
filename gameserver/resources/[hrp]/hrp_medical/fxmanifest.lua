fx_version 'cerulean'
game 'gta5'

name 'hrp_medical'
description 'HardcoreRP – Verletzungssystem: Trefferzonen, Bewusstlosigkeit statt Respawn, Krankenakten, Vitals'
version '1.0.0'

dependencies {
    'hrp_core',
    'hrp_jobs',
    'baseevents',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
}
