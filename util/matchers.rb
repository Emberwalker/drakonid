

require 'fuzzy_match'

##
# Matching and searching helpers.
module Matchers
  ##
  # Picks a user from a list of possible users. Passing an event is optional, but will enable @Mention look up.
  def self.get_user_from_message(user_str, candidate_users, event = nil)
    return event.message.mentions[0] unless event&.message&.mentions&.empty?

    # Try with current nickname first
    fz = FuzzyMatch.new(candidate_users, read: :display_name)
    user = fz.find(user_str)
    return user if user

    fz = FuzzyMatch.new(candidate_users, read: :username)
    fz.find(user_str)
  end
end