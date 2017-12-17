#!/usr/bin/env ruby
# frozen_string_literal: true

#
# Windows launch stub (to load libsodium)
#

::RBNACL_LIBSODIUM_GEM_LIB_PATH = File.join(__dir__, 'libsodium.dll')

require_relative 'drakonid'
