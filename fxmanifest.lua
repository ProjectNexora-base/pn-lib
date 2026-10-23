fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pn-lib'
author 'Project Nexora'
description 'PN Base bridge — presence, live config, panel sync, WebRTC'
version '1.3.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
}

client_scripts {
    'client/main.lua',
    'client/webrtc.lua',
    'client/config.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/inventory.lua',
    'server/config.lua',
    'server/bridge.lua',
    'server/actions.lua',
    'server/config_nui.lua',
    'server/webrtc_signal.lua',
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/app.js',
    'sql/pn_config.sql',
}

server_exports {
    'RegisterConfig',
    'GetConfig',
    'GetConfigEntry',
    'GetConfigNamespace',
    'GetAllConfigEntries',
    'SetConfig',
    'DeleteConfig',
    'OnConfigChange',
    'PrintConfig',
    'GetConfigHash',
    'IsConfigTableOk',
    'GetPlayers',
    'RefreshPlayer',
    'GetResourceInventory',
    'PrintResourceInventory',
    'BridgeLastError',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
}
