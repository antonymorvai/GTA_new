fx_version 'cerulean'
game 'gta5'

name 'hrp_hud'
description 'HardcoreRP – HUD: Vitals, Gesundheit, Fahrzeugdaten (NUI)'
version '1.0.0'

dependencies {
    'hrp_core',
}

client_scripts {
    'client/main.lua',
}

ui_page 'nui/index.html'

files {
    'nui/index.html',
    'nui/style.css',
    'nui/app.js',
}
