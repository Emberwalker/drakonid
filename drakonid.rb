#!/usr/bin/env ruby
#
# Drakonid - a simple Discord bot.
#

require 'json'
require 'discordrb'
require_relative 'logging'
require_relative 'util/permissions'
require_relative 'plugins/base'
require_relative 'plugins/utils'
require_relative 'plugins/bnet'

# Constants
DISCORD_APP_ID_KEY = 'discord_app_id'
DISCORD_TOKEN_KEY = 'discord_token'
BNET_PRIVATE_KEY = 'battlenet_token'
GLOBAL_ADMIN_KEY = 'global_administrator'
COMMAND_PREFIX = '!'

def load_config
  begin
    raw = File.read 'config.json'
    config = JSON.parse raw
    debug(config.to_s)
  rescue Exception => ex
    fatal "Failed to read config: #{ex.message}"
  end

  if config[DISCORD_APP_ID_KEY] == '' || config[DISCORD_TOKEN_KEY] == ''
    fatal('Missing Discord connection data; did you complete a config.json?')
  end

  config
end

# Main
config = load_config
Permissions.set_global_administrator(config[GLOBAL_ADMIN_KEY])
Permissions.load_from_disk
Utils.load_announces
BNet.init(config[BNET_PRIVATE_KEY])

bot = Discordrb::Commands::CommandBot.new(token: config[DISCORD_TOKEN_KEY],
                                          application_id: config[DISCORD_APP_ID_KEY].to_i, prefix: COMMAND_PREFIX)
bot.include! Base
bot.include! Utils
bot.include! BNet

bot.run
