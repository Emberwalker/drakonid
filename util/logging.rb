# frozen_string_literal: true

# Logging helpers

##
# Logging metadata
module Logging
  # Log ALL the things?
  @debug = true

  def self.debug?
    @debug
  end

  def self.debug=(dbg)
    @debug = dbg
  end
end

# Logs a fatal error and crashes out
def fatal(msg)
  puts "!! #{msg}"
  exit(-1)
end

def warn(msg)
  puts "** #{msg}"
end

def info(msg)
  puts ">> #{msg}"
end

def debug(msg)
  puts "?? #{msg}" if Logging.debug?
end
