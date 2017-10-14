require 'discordrb'
require_relative '../util/utils'

# noinspection RubyStringKeysInHashInspection
module Announcements
  extend Discordrb::Commands::CommandContainer
  extend Discordrb::EventContainer

  JOIN_LEAVE_JSON_FILE_NAME = 'announces'.freeze
  STREAM_JSON_FILE_NAME = 'stream_announces'.freeze
  @__join_leave_announce_config = {}
  @__stream_announce_config = {}

  def self.load_announces
    @__join_leave_announce_config = JSONFiles.load_file JOIN_LEAVE_JSON_FILE_NAME
    @__stream_announce_config = JSONFiles.load_file STREAM_JSON_FILE_NAME
  end

  def self.save_announces
    JSONFiles.save_file JOIN_LEAVE_JSON_FILE_NAME, @__join_leave_announce_config
    JSONFiles.save_file STREAM_JSON_FILE_NAME, @__stream_announce_config
  end

  command :ann_set do |event|
    next "#{event.user.mention} :warning: You don't have permission to do that." unless Permissions.check_permission(event.server, event.user, :administrator)
    next "#{event.user.mention} This has to be run in a server channel. PMs or group chats are invalid targets." if event.channel.private?
    sid = event.server.id.to_s
    cid = event.channel.id.to_s
    @__join_leave_announce_config[sid] = cid
    save_announces
    next "#{event.user.mention} :mega: New member announcement channel set to #{event.channel.mention}."
  end

  command :sann_set do |event|
    next "#{event.user.mention} :warning: You don't have permission to do that." unless Permissions.check_permission(event.server, event.user, :administrator)
    next "#{event.user.mention} This has to be run in a server channel. PMs or group chats are invalid targets." if event.channel.private?
    sid = event.server.id.to_s
    cid = event.channel.id.to_s
    @__stream_announce_config[sid] = cid
    save_announces
    next "#{event.user.mention} :mega: Stream announcement channel set to #{event.channel.mention}."
  end

  command :ann_del do |event|
    next "#{event.user.mention} :warning: You don't have permission to do that." unless Permissions.check_permission(event.server, event.user, :administrator)
    next "#{event.user.mention} This has to be run in a server channel." if event.channel.private?

    @__join_leave_announce_config.delete(event.server.id.to_s)
    save_announces
    next "#{event.user.mention} :electric_plug: Disconnected member announcements on this server."
  end

  command :sann_del do |event|
    next "#{event.user.mention} :warning: You don't have permission to do that." unless Permissions.check_permission(event.server, event.user, :administrator)
    next "#{event.user.mention} This has to be run in a server channel." if event.channel.private?

    @__stream_announce_config.delete(event.server.id.to_s)
    save_announces
    next "#{event.user.mention} :electric_plug: Disconnected stream announcements on this server."
  end

  member_join do |event|
    ann_target = @__join_leave_announce_config[event.server.id.to_s]
    if ann_target
      ch = event.server.channels.select { |it| it.id.to_s == ann_target }.first
      if ch
        ch.send_message(Snark.snrk(event.server, '@everyone @USER@ has joined the server!', [
            '@everyone We\'ve got a new sucker! I mean, user: @USER@',
            '@everyone Oh look. Another person. Greeaaat. @USER@',
            '@everyone @USER@ is providing more blood for the Discord blood god! By joining the server, that is.',
            '@everyone Let\'s hope the new person is actually interesting this time... @USER@'
        ], {'@USER@' => event.user.mention}))
      end
    end
  end

  member_leave do |event|
    ann_target = @__join_leave_announce_config[event.server.id.to_s]
    if ann_target
      ch = event.server.channels.select { |it| it.id.to_s == ann_target }.first
      if ch
        # No snark here. Leaving is more serious.
        ch.send_message('@everyone ' + event.user.distinct + ' has left the server.')
      end
    end
  end

  playing do |event|
    # event.type 1 == streaming on Twitch
    # See http://www.rubydoc.info/gems/discordrb/Discordrb/Events/PlayingEvent
    next unless event.type == 1
    next if event.game.nil?
    game = event.game
    url = event.url

    ann_target = @__stream_announce_config[event.server.id.to_s]
    if ann_target
      ch = event.server.channels.select { |it| it.id.to_s == ann_target }.first
      if ch
        ch.send_message("#{event.user.mention} has started streaming \"#{game}\" on Twitch! #{url}")
      end
    end
  end
end