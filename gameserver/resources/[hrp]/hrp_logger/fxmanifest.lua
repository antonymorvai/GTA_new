fx_version 'cerulean'
game 'gta5'

name 'hrp_logger'
description 'HardcoreRP – Log-Pipeline-Client: Queue, Batch-Versand, Disk-Buffer, Position-Sampler'
version '1.0.0'

server_scripts {
    'server/uuid.lua',
    'server/logger.lua',
    'server/positions.lua',
}

server_only 'yes'
