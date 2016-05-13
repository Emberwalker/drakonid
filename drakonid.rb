#!/usr/bin/env ruby
#
# Drakonid - a simple Discord bot.
#

require 'json'
require 'discordrb'
require_relative 'logging'

# Constants
DISCORD_APP_ID_KEY = "discord_app_id"
DISCORD_TOKEN_KEY = "discord_token"
BNET_PRIVATE_KEY = "battlenet_token"
COMMAND_PREFIX = "!"

def load_config()
  begin
    raw = File.read "config.json"
    config = JSON.parse raw
    debug(config.to_s)
  rescue Exception => ex
    fatal "Failed to read config: #{ex.message}"
  end

  if config[DISCORD_APP_ID_KEY] == "" || config[DISCORD_TOKEN_KEY] == ""
    fatal("Missing Discord connection data; did you complete a config.json?")
  end

  return config
end

def attach_plugins(config, bot)
  # Base
  require_relative 'plugins/base'
  base_plugin = Base.new
  base_plugin.attach_to_bot(bot)

  # Battle.net
  if config[BNET_PRIVATE_KEY] == ""
    warn "Skipping BNet plugin: missing authentication keys."
  else
    require_relative 'plugins/bnet'
    bnet = BNet.new
    bnet.attach_to_bot(bot, config[BNET_PRIVATE_KEY])
  end
end

# Main
config = load_config
bot = Discordrb::Commands::CommandBot.new(token: config[DISCORD_TOKEN_KEY], application_id: config[DISCORD_APP_ID_KEY].to_i,
  prefix: COMMAND_PREFIX)
attach_plugins(config, bot)

bot.run
