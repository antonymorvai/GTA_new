fx_version 'cerulean'
game 'gta5'

name 'hrp_skills'
description 'HardcoreRP – Skills: XP nur durch Nutzung, Decay bei Nichtnutzung'
version '1.0.0'

dependencies {
    'hrp_core',
}

shared_scripts {
    'shared/leveling.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
}
