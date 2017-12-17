# frozen_string_literal: true

require 'securerandom'
require 'discordrb'
require_relative '../util/utils'

# noinspection RubyStringKeysInHashInspection
module Games
  extend Discordrb::Commands::CommandContainer
  extend Discordrb::EventContainer

  command :roll do |event, *args|
    next unless ServerConf.get_svar(event.server, Const::SVAR_ALLOW_GAMES)

    rnd_min = ServerConf.get_svar(event.server, Const::SVAR_ROLL_MIN)
    rnd_max = ServerConf.get_svar(event.server, Const::SVAR_ROLL_MAX)
    rnd_max = args[0].to_i if args.size >= 1

    # +1 because "::random_number returns an integer: 0 <= ::random_number < n."
    rnd = SecureRandom.random_number(1 + rnd_max - rnd_min) + rnd_min
    next "#{event.user.mention} rolled #{rnd}"
  end
end
