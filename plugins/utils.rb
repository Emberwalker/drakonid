# frozen_string_literal: true

require 'discordrb'
require_relative '../util/utils'

# noinspection RubyStringKeysInHashInspection
module Utils
  extend Discordrb::Commands::CommandContainer

  bucket :ping, limit: 3, time_span: 60, delay: 5

  command :ping, bucket: :ping do |event|
    "#{event.user.mention} Pong!"
  end

  command :rmhist do |event, amount|
    req_perm = :administrator
    req_perm = :superuser if ServerConf.get_svar(event.server, Const::SVAR_RMHIST_ALLOW_SU)
    next "#{event.user.mention} :warning: You don't have permission to do that." unless
        Permissions.check_permission(event.server, event.user, req_perm)
    next "#{event.user.mention} This has to be run in a server channel." if event.channel.private?
    amount = amount.to_i + 1 # Add 1 to account for the request itself.
    next "#{event.user.mention} Amount of messages to delete must be a number between 1 and 99." if
        amount < 2 || amount > 100
    event.channel.prune(amount, false)
    next "#{event.user.mention} has cleared up to #{amount - 1} messages from the channel. Older messages " \
         '(2 weeks or older) have not been touched.'
  end
end
