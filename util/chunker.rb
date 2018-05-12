# frozen_string_literal: true

# Splits long messages into Discord-sized chunks, from a sequence of many small atomic messages.
class Chunker
  MAX_MESSAGE_LENGTH = 1024

  attr_reader :messages

  def initialize
    @messages = []
  end

  def <<(msg)
    raise ArgumentError('Message too long!') if msg.size > MAX_MESSAGE_LENGTH
    @messages.push msg
  end

  def chunk
    curr_str = ''
    out = []

    @messages.each do |msg|
      if msg.size + curr_str.size > MAX_MESSAGE_LENGTH
        out.push curr_str
        curr_str = ''
      end
      curr_str += "#{msg}\n"
    end

    out.push curr_str unless curr_str == ''
    out
  end

  def send(respondable)
    chunk.each { |ch| respondable.send_message ch }
  end
end
