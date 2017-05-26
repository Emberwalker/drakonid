require 'discordrb'

module Conversations

  def Conversations.numeric_conversation(arr_length, &block)
    @numeric_await.curry[arr_length][block]
  end

  private
  @numeric_await = -> max_ans, func, evt {
    msg = evt.message
    if msg.text.downcase == 'abort'
      msg.reply "#{evt.user.mention} Okay. No changes have been made."
      return true
    end

    ans = msg.text.to_i
    if ans > 0 && ans <= max_ans
      func.(evt, ans - 1)
      return true
    else
      msg.reply "#{evt.user.mention} I didn't catch that. Select a number from above, or answer 'abort' to cancel."
      return false
    end
  }

end