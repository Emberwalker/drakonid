require 'json'
require_relative '../logging'

module Snark
  SNARK_DEFAULT = false
  @__server_snark = {}

  def Snark.load_from_disk
    if File.exists? 'snark.json'
      begin
        File.open('snark.json') { |f|
          @__server_snark = JSON.load f
        }
      rescue Exception => ex
        warn "Exception parsing snark JSON: #{ex}"
      end
    end
    debug "Loaded snark config for #{@__server_snark.length} servers. Sarcastic yay."
  end

  def Snark.save_to_disk
    raw_json = JSON.pretty_generate @__server_snark
    File.open 'snark.json', mode: 'w' do |f|
      f.write raw_json
    end
  end

  def Snark.set_server_snark(server, snark)
    @__server_snark[server.id.to_s] = snark
    save_to_disk
  end

  def Snark.get_server_snark(server)
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