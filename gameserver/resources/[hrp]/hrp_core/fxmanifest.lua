fx_version 'cerulean'
game 'gta5'

name 'hrp_core'
description 'HardcoreRP – Framework-Core: Accounts, Sessions, Event-Security, RBAC, Geld-Basis'
version '1.0.0'

dependencies {
    'oxmysql',
    'hrp_logger',
}

shared_scripts {
    'shared/reasons.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/db.lua',
    'server/main.lua',
    'server/tuning.lua',
    'server/security.lua',
    'server/rbac.lua',
    'server/accounts.lua',
    'server/money.lua',
    'server/admin.lua',
}

client_scripts {
    'client/main.lua',
}
