# frozen_string_literal: true

require 'discordrb'

##
# Have a conversation with your users.
module Conversations
  def self.numeric_conversation(arr_length, &block)
    @numeric_await.curry[arr_length][block]
  end

  @numeric_await = lambda { |max_ans, func, evt|
    msg = evt.message
    if msg.text.casecmp('abort').zero?
      msg.reply "#{evt.user.mention} Okay. No changes have been made."
      next true
    end

    ans = msg.text.to_i
    if ans.positive? && ans <= max_ans
      func.call(evt, ans - 1)
      next true
    else
      msg.reply "#{evt.user.mention} I didn't catch that. Select a number from above, or answer 'abort' to cancel."
      next false
    end
  }
end
