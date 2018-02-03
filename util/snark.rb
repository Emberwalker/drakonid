# frozen_string_literal: true

require 'json'
require_relative 'logging'
require_relative 'files'
require_relative 'server_conf'
require_relative 'const'

##
# What do you *think* this does?
module Snark
  SNARK_SVAR = Const::SVAR_USE_SNARK

  def self.set_server_snark(server, snark)
    return unless server
    ServerConf.set(server, SNARK_SVAR.internal, snark)
  end

  def self.get_server_snark(server)
    ServerConf.get(server, SNARK_SVAR.internal, SNARK_SVAR.default)
  end

  def self.snrk(server, no_snark_msg, snark_msgs, substitutions = {})
    snark = get_server_snark(server)
    return __apply_substitutions(snark_msgs.sample, substitutions) if snark
    __apply_substitutions(no_snark_msg, substitutions)
  end

  def self.__apply_substitutions(msg, substitutions)
    # Dupe string to avoid frozen issues.
    msg = msg.dup if msg.frozen?
    substitutions.each do |key, val|
      msg.gsub! key, val
    end
    msg
  end

  private_class_method :__apply_substitutions
end
