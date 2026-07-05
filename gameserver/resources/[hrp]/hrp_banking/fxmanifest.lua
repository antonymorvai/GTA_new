fx_version 'cerulean'
game 'gta5'

name 'hrp_banking'
description 'HardcoreRP – Bank: Kontonummern, Ein-/Auszahlung, Überweisung, Daueraufträge'
version '1.0.0'

dependencies {
    'hrp_core',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
}
