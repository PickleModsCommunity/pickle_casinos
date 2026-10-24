fx_version "cerulean"
game "gta5"
author "Pickle Mods"
description "The best system for player-owned casinos."
version "v1.5.8"

ui_page "nui/index.html"

files {
	"nui/index.html",
	"nui/images/*.*",
	"nui/images/**/*.*",
	"nui/audio/*.*",
	"nui/audio/**/*.*",
	"nui/assets/**/*.*",
	"nui/debug.js",
	"components/**/*.*",
}

shared_scripts {
	"@ox_lib/init.lua",
	"config.lua",
    "core/shared.lua",
	"templates/*.lua",
	"locales/locale.lua",
    "locales/translations/*.lua",
	"modules/**/shared.lua",
}

client_scripts {
	"bridge/**/**/client.lua",
	"modules/**/client.lua",
	"modules/casino/employees_client.lua",
    "core/client.lua"
}

server_scripts {
	"@mysql-async/lib/MySQL.lua",
	"bridge/**/**/server.lua",
	"modules/**/server.lua",
	"modules/casino/employees_server.lua",
    "core/server.lua",
    "core/proximity_server.lua",
	"config_sv.lua",
}

files {
    'peds.meta'
}

data_file 'PED_METADATA_FILE' 'peds.meta'
data_file 'DLC_ITYP_REQUEST' 'fury_p_wheeloff.ytyp'
data_file 'DLC_ITYP_REQUEST' 'fury_p_poker_table.ytyp'
data_file 'DLC_ITYP_REQUEST' 'fury_picklegamblingprops.ytyp'
data_file 'DLC_ITYP_REQUEST' 'npds_bettingmachine_01.ytyp'
data_file 'DLC_ITYP_REQUEST' 'fury_p_slots.ytyp'

lua54 'yes'

escrow_ignore {
	"config.lua",
	"config_sv.lua",
	"templates.lua",
	"templates/*.lua",
	"__INSTALL/**/*.*",
	"core/*.*",
	"bridge/**/**/*.*",
	"bridge/**/*.*",
    "locales/locale.lua",
    "locales/translations/*.lua",
}