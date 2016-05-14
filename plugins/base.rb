require 'discordrb'

module Base
  extend Discordrb::Commands::CommandContainer

  bucket :ping, limit: 3, time_span: 60, delay: 5

  command :ping, bucket: :ping do |event|
    "#{event.user.mention} Pong!"
  end
end
