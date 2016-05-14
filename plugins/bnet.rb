require 'battlenet'
require 'json'
require 'discordrb'
require_relative '../logging'

module BNet
  extend Discordrb::Commands::CommandContainer

  def self.init(privkey)
    privkey = nil if privkey == ""
    conf = get_config
    @@current_realm = conf[@@REALM_KEY]
    Battlenet.locale = "en_GB"
    @@api = Battlenet.new conf[@@REGION_KEY].intern, privkey if privkey
  end

  bucket :realm_status, limit: 4, time_span: 60, delay: 5
  bucket :showme, limit: 6, time_span: 60, delay: 2

  command :realm, bucket: :realm_status do |event, *realm|
    return "#{event.user.mention} I'm sorry #{event.user.name}, I don't have API keys! :cry:" unless @@api
    msg = event.send_message @@WAIT_MESSAGES.sample
    rlm = @@current_realm
    rlm = realm.join " " unless realm.empty?
    "#{event.user.mention} #{get_realm_status(rlm)}"
  end

  command :showme, bucket: :showme do |event, char, *realm|
    if char == "" || !char
      event.send_message "#{event.user.mention} Show you... who? (usage: !showme <name> <realm> - realm is optional)"
      return
    end
    if !@@api
      event.send_message "#{event.user.mention} I'm sorry #{event.user.name}, I don't have API keys! :cry:"
      return
    end

    debug "showme/#{char}/#{realm.join " "}"
    event.send_message @@WAIT_MESSAGES.sample
    rlm = @@current_realm
    rlm = realm.join " " unless realm.empty?

    begin
      char_data = @@api.character rlm, char, :fields => "appearance"
      event.send_message "#{event.user.mention} http://render-api-eu.worldofwarcraft.com/static-render/eu/#{char_data["thumbnail"]}"
    rescue Battlenet::ApiException => ex
      if ex.code == 404
        event.send_message "#{event.user.mention} I couldn't find that player. Is your spelling correct?"
      else
        warn "Error fetching character data: #{ex.response}"
        event.send_message ":satellite: :boom: I couldn't work out wtf Battle.net was smoking. Try again later!"
      end
    end
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
    "Huh? You sure? Alright, fine. One second...",
    "Why would you want that? \'kay, moment..."
  ]

  @@current_realm = @@REALM_DEFAULT
  @@api = nil

  def self.get_config()
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

  def self.get_realm_status(realm)
    begin
      realm_data = @@api.realm["realms"]
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

  def self.__render_realm(realm)
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
