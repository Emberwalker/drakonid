# Misc fixes for third-party code - yay monkey-patching!
# Following code is copied from Discordrb but patched where marked.

module Discordrb
  class Channel
    # For bulk_delete checking
    TWO_WEEKS = 86_400 * 14

    # Deletes a list of messages on this channel using bulk delete
    def bulk_delete(ids, strict = false)
      min_snowflake = IDObject.synthesise(Time.now - TWO_WEEKS)

      ids.reject! do |e|
        next unless e < min_snowflake

        message = "Attempted to bulk_delete message #{e} which is too old (min = #{min_snowflake})"
        raise ArgumentError, message if strict
        Discordrb::LOGGER.warn(message)
        Discordrb::LOGGER.warn('FIXME: Monkeypatch in patches.rb (Discordrb::Channel#bulk_delete). Submit patch upstream!')
       #vvvvv This is where we patch - Discordrb returns false, which tells reject to KEEP the item. Change to true.
        true
      end

      API::Channel.bulk_delete_messages(@bot.token, @id, ids)
    end
  end
end