class Base
  def attach_to_bot(bot)
    attach_buckets(bot)
    attach_ping(bot)
  end

  private
  def attach_buckets(bot)
    bot.bucket :ping, limit: 3, time_span: 60, delay: 5
  end

  def attach_ping(bot)
    bot.command :ping, bucket: :ping do |event|
      "#{event.user.mention} Pong!"
    end
  end
end
