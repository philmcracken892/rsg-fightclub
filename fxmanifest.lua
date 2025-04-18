fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

author 'Phil mcracken'
description 'Saloon bar fight system for RSG-Core with ox_lib'
version '1.0.0'

shared_scripts {
    
    '@ox_lib/init.lua',    
    'config.lua'          
}

client_scripts {
    'client.lua',
	
}

server_scripts {
    'server.lua'
}

dependencies {
    'rsg-core',
    'ox_lib'
}
lua54 'yes'
