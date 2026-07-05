fx_version 'cerulean'
game 'gta5'

name 'hrp_justice'
description 'HardcoreRP – Justiz: versioniertes Gesetzbuch, Bußgelder, Haft'
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
