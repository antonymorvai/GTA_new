fx_version 'cerulean'
game 'gta5'

name 'hrp_vehicles'
description 'HardcoreRP – Fahrzeuge: Kauf, Garagen, Schlüssel, Kraftstoff, Kilometerstand, Persistenz'
version '1.0.0'

dependencies {
    'hrp_core',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/insurance.lua',
}

client_scripts {
    'client/main.lua',
}
