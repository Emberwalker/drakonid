require 'json'
require_relative '../logging'
require_relative 'files'
require_relative 'server_conf'
require_relative 'const'

module Snark
  SNARK_SVAR = Const::SVAR_USE_SNARK

  def Snark.set_server_snark(server, snark)
    return unless server
    ServerConf.set(server, SNARK_SVAR.internal, snark)
  end

  def Snark.get_server_snark(server)
    ServerConf.get(server, SNARK_SVAR.internal, SNARK_SVAR.default)
  end

  def Snark.snrk(server, no_snark_msg, snark_msgs, substitutions = {})
    snark = get_server_snark(server)
    if snark
      return __apply_substitutions(snark_msgs.sample, substitutions)
    else
      return __apply_substitutions(no_snark_msg, substitutions)
    end
  end

  private
  def Snark.__apply_substitutions(msg, substitutions)
    substitutions.each do |key, val|
      msg.gsub! key, val
    end
    return msg
  end
end