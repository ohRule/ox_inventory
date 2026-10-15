fx_version 'cerulean'
use_experimental_fxv2_oal 'yes'
lua54 'yes'
game 'gta5'
name 'ox_inventory'
author 'Overextended'
version '2.47.9'
repository 'https://github.com/overextended/ox_inventory'
description 'Slot-based inventory with item metadata support'

dependencies {
    '/server:6116',
    '/onesync',
    'oxmysql',
    'ox_lib',
}

shared_script '@ox_lib/init.lua'

ox_libs {
    'locale',
    'table',
    'math',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'init.lua'
}

client_script 'init.lua'

ui_page 'web/build/index.html'

files {
    'client.lua',
    'server.lua',
    'locales/*.json',
    'web/build/index.html',
    'web/build/assets/*.js',
    'web/build/assets/*.css',
    'web/images/*.png',
    'modules/**/shared.lua',
    'modules/**/client.lua',
    'modules/bridge/**/client.lua',
    'data/*.lua',
}

-- Gear's add-on clothing sets (data/gear.lua): the backpack (mp_m_ruck_bags,
-- mp_f_ruck_bags), the empty holsters (mp_m_ruck_holster, mp_f_ruck_holster: the game's
-- two with the pistol taken out) and the waistband holster (mp_m_ruck_waistband). Their
-- models go in stream/ (not in this repo); without them the gear shows the game's own
-- clothes. Add-on clothing only streams on a server of 8 slots or fewer, or with
-- Element Club Argentum.
files { 'meta/*.meta' }
data_file 'SHOP_PED_APPAREL_META_FILE' 'meta/mp_m_freemode_01_mp_m_ruck_bags.meta'
data_file 'SHOP_PED_APPAREL_META_FILE' 'meta/mp_f_freemode_01_mp_f_ruck_bags.meta'
data_file 'SHOP_PED_APPAREL_META_FILE' 'meta/mp_m_freemode_01_mp_m_ruck_holster.meta'
data_file 'SHOP_PED_APPAREL_META_FILE' 'meta/mp_f_freemode_01_mp_f_ruck_holster.meta'
data_file 'SHOP_PED_APPAREL_META_FILE' 'meta/mp_m_freemode_01_mp_m_ruck_waistband.meta'
