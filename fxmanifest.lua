fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pn-lib'
author 'Project Nexora'
description 'PN Base bridge — player presence, panel sync, WebRTC signaling'
version '1.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
}

client_scripts {
    'client/main.lua',
    'client/webrtc.lua',
}

server_scripts {
    'server/main.lua',
    'server/inventory.lua',
    'server/bridge.lua',
    'server/actions.lua',
    'server/webrtc_signal.lua',
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/app.js',
}

dependencies {
    'ox_lib',
    'qbx_core',
}
