require 'json'
require_relative '../logging'
require_relative 'files'

module Snark
  SNARK_DEFAULT = false
  JSON_FILE_NAME = 'snark'
  @__server_snark = {}

  def Snark.load_from_disk
    @__server_snark = JSONFiles.load_file JSON_FILE_NAME
    debug "Loaded snark config for #{@__server_snark.length} servers. Sarcastic yay."
  end

  def Snark.save_to_disk
    JSONFiles.save_file JSON_FILE_NAME, @__server_snark
  end

  def Snark.set_server_snark(server, snark)
    return unless server
    @__server_snark[server.id.to_s] = snark
    save_to_disk
  end

  def Snark.get_server_snark(server)
    return SNARK_DEFAULT unless server
    return @__server_snark[server.id.to_s] if @__server_snark[server.id.to_s]
    return SNARK_DEFAULT
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