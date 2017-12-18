#!/usr/bin/env ruby
# frozen_string_literal: true

#
# Drakonid - a simple Discord bot.
#

require 'json'
require 'discordrb'
require_relative 'patches'
require_relative 'util/logging'
require_relative 'util/permissions'
require_relative 'util/snark'
require_relative 'util/server_conf'
require_relative 'plugins/base'
require_relative 'plugins/announcements'
require_relative 'plugins/svars'
require_relative 'plugins/utils'
require_relative 'plugins/disciplinary'
require_relative 'plugins/bnet'
require_relative 'plugins/condenser'
require_relative 'plugins/quotes'
require_relative 'plugins/games'

# Constants
DISCORD_APP_ID_KEY = 'discord_app_id'
DISCORD_TOKEN_KEY = 'discord_token'
BNET_PRIVATE_KEY = 'battlenet_token'
GLOBAL_ADMIN_KEY = 'global_administrator'
LOGGING_DEBUG_KEY = 'debug_logging'
COMMAND_PREFIX = '!'

def load_config
  begin
    raw = File.read 'config.json'
    config = JSON.parse raw
  rescue StandardError => ex
    fatal "Failed to read config: #{ex.message}"
  end

  if config[DISCORD_APP_ID_KEY] == '' || config[DISCORD_TOKEN_KEY] == ''
    fatal('Missing Discord connection data; did you complete a config.json?')
  end

  config
end

# Main
config = load_config
Logging.debug = config[LOGGING_DEBUG_KEY] ? config[LOGGING_DEBUG_KEY] : false
Permissions.global_administrator = config[GLOBAL_ADMIN_KEY]
Permissions.load_from_disk
ServerConf.load_from_disk
Announcements.load_announces
Quotes.load_quotes
BNet.init(config[BNET_PRIVATE_KEY])
Condenser.load_from_disk

bot = Discordrb::Commands::CommandBot.new(token: config[DISCORD_TOKEN_KEY],
                                          application_id: config[DISCORD_APP_ID_KEY].to_i,
                                          prefix: COMMAND_PREFIX)
bot.include! Base
bot.include! Announcements
bot.include! SVars
bot.include! Utils
bot.include! Disciplinary
bot.include! BNet
bot.include! Condenser
bot.include! Quotes
bot.include! Games

bot.run
