fx_version 'cerulean'
game 'gta5'

name 'hrp_crafting'
description 'HardcoreRP – Crafting: Rezepte aus der DB, Skill-Freischaltung, Qualität'
version '1.0.0'

dependencies {
    'hrp_core',
    'hrp_inventory',
    'hrp_skills',
}

shared_scripts {
    'shared/crafting.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

server_only 'yes'
