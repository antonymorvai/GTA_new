fx_version 'cerulean'
game 'gta5'

name 'hrp_economy'
description 'HardcoreRP – Wirtschafts-Engine: Shops mit dynamischen Preisen (Angebot & Nachfrage)'
version '1.0.0'

dependencies {
    'hrp_core',
    'hrp_inventory',
}

shared_scripts {
    'shared/pricing.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

server_only 'yes'
