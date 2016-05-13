require 'battlenet'
require 'json'
require_relative '../logging'

class BNet
  def attach_to_bot(bot, privkey)
    conf = get_config
    @current_realm = conf[@@REALM_KEY]
    Battlenet.locale = "en_GB"
    @api = Battlenet.new conf[@@REGION_KEY].intern, privkey

    attach_buckets(bot)
    attach_realm_status(bot)
  end

  private
  @@REGION_KEY = "region"
  @@REALM_KEY = "realm"

  @@REGION_DEFAULT = "eu"
  @@REALM_DEFAULT = "Argent Dawn"

  @@PVP_FACTIONS = [:alliance, :horde, :neutral]
  @@PVP_STATUS = [:idle, :populating, :active, :concluded, :unknown]

  @@WAIT_MESSAGES = [
    "Let me look that up. One moment...",
    "Consulting the oracle for you...",
    "That realm? Really? Alright. One second..."
  ]

  @current_realm = @@REALM_DEFAULT
  @api = nil

  def get_config()
    begin
      raw = File.read 'bnet.json'
      conf = JSON.parse raw
    rescue Exception => ex
      warn "Couldn't load bnet.json; assuming defaults: #{ex.message}"
      conf = {}
    end
    conf[@@REGION_KEY] = @@REGION_DEFAULT unless conf[@@REGION_KEY]
    conf[@@REALM_KEY] = @@REALM_DEFAULT unless conf[@@REALM_KEY]
    return conf
  end

  def attach_buckets(bot)
    bot.bucket :realm_status, limit: 4, time_span: 60, delay: 5
  end

  def attach_realm_status(bot)
    bot.command :realm, bucket: :realm_status do |event, *realm|
      msg = event.send_message @@WAIT_MESSAGES.sample
      rlm = @current_realm
      rlm = realm.join " " unless realm.empty?
      "#{event.user.mention} #{get_realm_status(rlm)}"
    end
  end

  def get_realm_status(realm)
    fatal "BNet API controller isn't available?!" unless @api

    begin
      realm_data = @api.realm["realms"]
      out_rlm = nil
      for rlm in realm_data
        if rlm["name"] == realm
          out_rlm = rlm
          break
        end
      end
      return "I couldn't find that realm, sorry!" unless out_rlm
      return __render_realm(out_rlm)
    rescue Battlenet::ApiException => ex
      warn "Failed to get realm status: #{ex.response}"
      return ":satellite: :boom: I couldn't work out wtf Battle.net was smoking. Try again later!"
    end
  end

  def __render_realm(realm)
    updown = "#{realm['name']} is currently "
    if realm['status']
      updown += "UP! :crossed_swords:"
    else
      updown += "DOWN! :construction:"
      return updown # Why continue if it's down?
    end

    wg = "Wintergrasp is currently held by "
    wg_data = realm['wintergrasp']
    wg += case @@PVP_FACTIONS[wg_data['controlling-faction']]
    when :alliance
      "the Alliance! "
    when :horde
      "the Horde! "
    else
      "nobody! "
    end
    wg += "Currently, the zone is"
    wg += case @@PVP_STATUS[wg_data['status']]
    when :idle
      " uncontested."
    when :populating
      " waiting for players!"
    when :active
      " at WAR! :crossed_swords:"
    when :concluded
      " just finishing a battle."
    else
      warn "Unknown Wintergrasp status: #{wg_data['status']}"
      "... Actually I don't know."
    end

    tb = "Tol-barad is currently held by "
    tb_data = realm['tol-barad']
    tb += case @@PVP_FACTIONS[tb_data['controlling-faction']]
    when :alliance
      "the Alliance! "
    when :horde
      "the Horde! "
    else
      "nobody! "
    end
    tb += "Currently, the zone is"
    tb += case @@PVP_STATUS[tb_data['status']]
    when :idle
      " uncontested."
    when :populating
      " waiting for players!"
    when :active
      " at WAR! :crossed_swords:"
    when :concluded
      " just finishing a battle."
    else
      warn "Unknown Tol-barad status: #{tb_data['status']}"
      "... Actually I don't know."
    end

    return "#{updown} #{wg} #{tb}"
  end
end
