require 'discordrb'
require 'json'
require_relative '../util/permissions'
require_relative '../util/snark'

# noinspection RubyStringKeysInHashInspection
module Utils
  extend Discordrb::Commands::CommandContainer
  extend Discordrb::EventContainer

  @__announce_config = {}

  def self.load_announces
    begin
      File.open 'announces.json', 'r' do |f|
        raw = f.read
        @__announce_config = JSON.parse raw
      end
    rescue Exception => ex
      warn "Couldn't load announces.json; assuming empty: #{ex.message}"
      @__announce_config = {}
    end
  end

  def self.save_announces
    raw_json = JSON.pretty_generate @__announce_config
    File.open 'announces.json', mode: 'w' do |f|
      f.write raw_json
    end
  end

  bucket :ping, limit: 3, time_span: 60, delay: 5

  command :ping, bucket: :ping do |event|
    "#{event.user.mention} Pong!"
  end

  command :ann_set do |event|
    next "#{event.user.mention} :warning: You don't have permission to do that." unless Permissions.check_permission(event.server, event.user, :administrator)
    next "#{event.user.mention} This has to be run in a server channel. PMs or group chats are invalid targets." if event.channel.private?
    sid = event.server.id.to_s
    cid = event.channel.id.to_s
    @__announce_config[sid] = cid
    save_announces
    next "#{event.user.mention} :mega: New member announcement channel set to #{event.channel.mention}."
  end

  command :ann_del do |event|
    next "#{event.user.mention} :warning: You don't have permission to do that." unless Permissions.check_permission(event.server, event.user, :administrator)
    next "#{event.user.mention} This has to be run in a server channel." if event.channel.private?

    @__announce_config.delete(event.server.id.to_s)
    save_announces
    next "#{event.user.mention} :electric_plug: Disconnected announcements on this server."
  end

  command :rmhist do |event, amount|
    next "#{event.user.mention} :warning: You don't have permission to do that." unless Permissions.check_permission(event.server, event.user, :superuser)
    next "#{event.user.mention} This has to be run in a server channel." if event.channel.private?
    amount = amount.to_i + 1  # Add 1 to account for the request itself.
    next "#{event.user.mention} Amount of messages to delete must be a number between 1 and 99." if amount < 2 || amount > 100
    event.channel.prune(amount)
    next "#{event.user.mention} has cleared up to #{amount - 1} messages from the channel. Older messages (2 weeks or older) have not been touched."
  end

  member_join do |event|
    ann_target = @__announce_config[event.server.id.to_s]
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
    ann_target = @__announce_config[event.server.id.to_s]
    if ann_target
      ch = event.server.channels.select { |it| it.id.to_s == ann_target }.first
      if ch
        # No snark here. Leaving is more serious.
        ch.send_message('@everyone ' + event.user.nick + ' has left the server.')
      end
    end
  end
end
