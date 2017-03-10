require 'discordrb'
require_relative '../util/permissions'
require_relative '../util/snark'

# noinspection RubyStringKeysInHashInspection
module Base
  extend Discordrb::Commands::CommandContainer

  command :stop do |event|
    if Permissions.check_global_administrator event.user
      event.send_message "#{event.user.mention} Shutting down..."
      event.bot.stop
    end
    "#{event.user.mention} You don't have permission to do that."
  end

  command :permset do |event, _usr_raw, rank_raw|
    rank_raw.downcase!
    next "#{event.user.mention} :warning: You don't have permission to do that." unless Permissions.check_permission(event.server, event.user, :administrator)
    next "#{event.user.mention} This has to be run in a server channel." if event.channel.private?
    next "#{event.user.mention} That permission level doesn't exist." unless Permissions.rank_exists? rank_raw
    rank = rank_raw.to_sym
    mentions = event.message.mentions
    next "#{event.user.mention} Who do I change permissions for? (:bulb: hint: @ mention the target user)" unless mentions.length == 1
    Permissions.set_permission event.server, mentions[0], rank
    next "#{event.user.mention} :wrench: Updated permissions for user #{mentions[0].mention} to rank #{rank.to_s}."
  end

  command :snarkpls do |event|
    next "#{event.user.mention} :warning: You don't have permission to do that." unless Permissions.check_permission(event.server, event.user, :superuser)
    next "#{event.user.mention} This has to be run in a server channel." if event.channel.private?
    Snark.set_server_snark(event.server, true)
    next Snark.snrk(event.server, '@USER@ Snark enabled.', [
      '@USER@ Pff. Fine. Expect much sarcasm from now on...',
      '@USER@ Yes sir/ma\'am, I respect your authority. For now.',
      '@USER@ It\'s on now. I hope you\'re happy.'
    ], {'@USER@' => event.user.mention})
  end

  command :wehatefun do |event|
    next "#{event.user.mention} :warning: You don't have permission to do that." unless Permissions.check_permission(event.server, event.user, :superuser)
    next "#{event.user.mention} This has to be run in a server channel." if event.channel.private?
    Snark.set_server_snark(event.server, false)
    next "#{event.user.mention} Snark disabled."
  end
end
