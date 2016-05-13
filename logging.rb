#!/bin/false
# Logging helpers

# Log ALL the things?
DEBUG = true

# Logs a fatal error and crashes out
def fatal(msg)
  puts "!! #{msg}"
  exit -1
end

def warn(msg)
  puts "** #{msg}"
end

def info(msg)
  puts ">> #{msg}"
end

def debug(msg)
  puts "?? #{msg}" if DEBUG
end
