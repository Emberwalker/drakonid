# frozen_string_literal: true

require 'chronic'

##
# Natural language time helpers.
module Chronology

  # Converts a user-provided string input into a time forward/back from now.
  #
  # @param str [String] the user-provided string
  # @param look_back [Boolean] true to look back in time, false to look forward
  # @param span_strategy [Symbol] For possible choices see {Chronic::Parser#guess}.
  # @returns [Chronic::Span, Object, nil] a time span, concrete time (value of {Chronic.time_class}) or nil if string
  #   could not be parsed.
  def self.get_time_after_now(str, look_back = false, span_strategy = :end)
    parser = Chronic::Parser.new options: {
      guess: false,
      context: look_back ? :past : :future,
      # This forces it to use proper dates (DD/MM/YY), not stupid American ones (MM/DD/YY - WHY!?)
      endian_precedence: %i[little middle]
    }
    guess = nil

    # Try sticking a 'in' on the front e.g. "in" + "5 hours"
    time = parser.parse 'in ' + str
    return time if time.is_a? Chronic.time_class
    guess = parser.guess time, span_strategy if time.is_a? Chronic::Span

    # Try directly e.g. "January 1st 2018"
    time = parser.parse str
    return time if time.is_a? Chronic.time_class
    guess = parser.guess time, span_strategy if time.is_a? Chronic::Span

    guess
  end
end