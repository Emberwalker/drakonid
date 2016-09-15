require 'battlenet'
require 'json'
require 'discordrb'
require_relative '../logging'

# noinspection RubyClassVariableUsageInspection, RubyJumpError, RubyClassVariableNamingConvention
module BNet
  extend Discordrb::Commands::CommandContainer

  def self.init(privkey)
    privkey = nil if privkey == ''
    conf = get_config
    @@current_realm = conf[@@REALM_KEY]
    @@wait_messages = conf[@@WAIT_MESSAGES_KEY]
    Battlenet.locale = 'en_GB'
    @@api = Battlenet.new conf[@@REGION_KEY].intern, privkey if privkey

    begin
      # Load data resources (required for Census)
      load_data_resources
    rescue Exception
      # ignore
    end
  end

  bucket :realm_status, limit: 4, time_span: 60, delay: 5
  bucket :showme, limit: 6, time_span: 60, delay: 2
  bucket :census, limit: 4, time_span: 60, delay: 10
  bucket :bnet_reload, limit: 1, time_span: 120, delay: 60

  command :bnet_reload, bucket: :bnet_reload do |event|
    return "#{event.user.mention} I would, but I don't seem to have any API keys. " +
        'Add those to the config and reboot the bot.' unless @@api
    event.send_message "Reloading Battle.net data resources at request of #{event.user.mention} - this may take a moment."
    begin
      loaded_resources = load_data_resources
      event.send_message "#{event.user.mention} Reload succeeded. Resources reloaded: #{loaded_resources}"
    rescue Battlenet::ApiException
      event.send_message "#{event.user.mention} Reload failed due to Battle.net API exception. Check the system logs."
    rescue Exception => ex
      event.send_message "#{event.user.mention} Reload failed due to an exception of type #{ex.class.name}. Check the system logs."
    end
  end

  command :realm, bucket: :realm_status do |event, *realm|
    return "#{event.user.mention} I'm sorry #{event.user.name}, I don't have API keys! :cry:" unless @@api
    event.send_message @@wait_messages.sample
    event.channel.start_typing
    rlm = @@current_realm
    rlm = realm.join ' ' unless realm.empty?
    "#{event.user.mention} #{get_realm_status(rlm)}"
  end

  command :showme, bucket: :showme do |event, char, *realm|
    if char == '' || !char
      event.send_message "#{event.user.mention} Show you... who? (usage: !showme <name> <realm> - realm is optional)"
      return
    end
    unless @@api
      event.send_message "#{event.user.mention} I'm sorry #{event.user.name}, I don't have API keys! :cry:"
      return
    end

    debug "showme/#{char}/#{realm.join ' '}"
    event.send_message @@wait_messages.sample
    event.channel.start_typing
    rlm = @@current_realm
    rlm = realm.join ' ' unless realm.empty?

    begin
      char_data = @@api.character rlm, char, :fields => 'appearance'
      event.send_message "#{event.user.mention} http://render-api-eu.worldofwarcraft.com/static-render/eu/#{char_data['thumbnail']}"
    rescue Battlenet::ApiException => ex
      if ex.code == 404
        event.send_message "#{event.user.mention} I couldn't find that player. Is your spelling correct?"
      else
        warn "Error fetching character data: #{ex.response}"
        event.send_message ":satellite: :boom: I couldn't work out wtf Battle.net was smoking. Try again later!"
      end
    end
  end

  command :census, bucket: :census do |event, *data|
    if data.empty?
      event.send_message "#{event.user.mention} Gather census data for whom?\n" +
        "If you want a custom realm and base rank: `!census Realm Name 9 Guild Name`\n" +
        "...Or just a custom base rank: `!census 9 Guild Name`\n" +
        "...Or if you want a whole guild on the default server (#{@@current_realm}): `!census Guild Name`"
      return
    end

    debug "census/#{data}"

    rank = 9
    realm = @@current_realm

    # Do we have a rank number?
    rank_index = data.find_index { |it| /^\d+$/ =~ it }
    if rank_index
      debug 'census/rank_provided'
      rank = data[rank_index].to_i
      unless rank_index == 0
        realm = data.take(rank_index).join(' ')
      end
      guild = data.drop(rank_index + 1).join(' ')
    else
      # Just the guild name
      debug 'census/no_rank_provided'
      guild = data.join(' ')
    end

    debug "census/rank/#{rank}/#{realm}/#{guild}"

    if realm.length < 2 || guild.length < 2
      return "I'm not sure that's a real realm or guild. Try again? (Realm or Guild name too short)"
    end

    get_census(event, realm, guild, rank)
  end

  private
  @@REGION_KEY = 'region'
  @@REALM_KEY = 'realm'
  @@WAIT_MESSAGES_KEY = 'wait_msgs'

  @@REGION_DEFAULT = 'eu'
  @@REALM_DEFAULT = 'Argent Dawn'

  @@PVP_FACTIONS = [:alliance, :horde, :neutral]
  @@PVP_STATUS = [:idle, :populating, :active, :concluded, :unknown]

  @@CHARACTER_GENDERS = {
      0 => :male,
      1 => :female
  }

  @@WAIT_MESSAGES_DEFAULT = [
      'Let me look that up. One moment...',
      'Consulting the oracle for you...',
      'Huh? You sure? Alright, fine. One second...',
      "Why would you want that? 'kay, moment..."
  ]

  @@current_realm = @@REALM_DEFAULT
  @@api = nil
  @@wait_messages = @@WAIT_MESSAGES_DEFAULT

  # API-provided data
  @race_ids = {}
  @class_ids = {}

  def self.get_config
    begin
      raw = File.read 'bnet.json'
      conf = JSON.parse raw
    rescue Exception => ex
      warn "Couldn't load bnet.json; assuming defaults: #{ex.message}"
      conf = {}
    end
    conf[@@REGION_KEY] = @@REGION_DEFAULT unless conf[@@REGION_KEY]
    conf[@@REALM_KEY] = @@REALM_DEFAULT unless conf[@@REALM_KEY]
    conf[@@WAIT_MESSAGES_KEY] = @@WAIT_MESSAGES_DEFAULT unless conf[@@WAIT_MESSAGES_KEY]
    return conf
  end

  def self.load_data_resources
    info '(Re)loading Battle.net data resources...'
    raw_races = nil
    raw_classes = nil
    begin
      raw_races = @@api.character_races
      raw_classes = @@api.character_classes
    rescue Battlenet::ApiException => ex
      warn "Failed during fetching of Battle.net data resources: #{ex}"
      raise ex
    end
    debug 'load_data_resources/download_finished'
    loaded_resources = []
    begin
      @race_ids = {}
      raw_races['races'].each do |race|
        @race_ids[race['id']] = {
            :name => race['name'],
            :mask => race['mask'],  # Just in case we need it later
            :faction => race['side'].intern
        }
      end
      loaded_resources.push('races')
      @class_ids = {}
      raw_classes['classes'].each do |cls|
        @class_ids[cls['id']] = {
            :name => cls['name'],
            :mask => cls['mask'],
            :power_type => cls['powerType']
        }
      end
      loaded_resources.push('classes')
    rescue Exception => ex
      warn "Failed during parsing of Battle.net data resources: #{ex}"
      raise ex
    end
    info "(Re)loaded Battle.net data resources #{loaded_resources}"
    return loaded_resources
  end

  def self.get_realm_status(realm)
    begin
      realm_data = @@api.realm['realms']
      out_rlm = nil
      realm_data.each { |rlm|
        if rlm['name'] == realm
          out_rlm = rlm
          break
        end
      }
      return "I couldn't find that realm, sorry!" unless out_rlm
      begin
        return __render_realm(out_rlm)
      rescue Exception => ex
        warn "Error rendering realm status: #{ex.inspect}"
        warn "Offending response: #{out_rlm}"
        return ":satellite: :boom: I've had some trouble producing that report. Sorry!"
      end
    rescue Battlenet::ApiException => ex
      warn "Failed to get realm status: #{ex.response}"
      return ":satellite: :boom: I couldn't work out wtf Battle.net was smoking. Try again later!"
    end
  end

  def self.__render_realm(realm)
    updown = "#{realm['name']} is currently "
    if realm['status']
      updown += 'UP! :crossed_swords:'
    else
      updown += 'DOWN! :construction:'
      return updown # Why continue if it's down?
    end

    wg = 'Wintergrasp is currently held by '
    wg_data = realm['wintergrasp']
    if wg_data
      wg += case @@PVP_FACTIONS[wg_data['controlling-faction']]
      when :alliance
        'the Alliance! '
      when :horde
        'the Horde! '
      else
        'nobody! '
      end
      wg += 'Currently, the zone is'
      wg += case @@PVP_STATUS[wg_data['status']]
      when :idle
        ' uncontested.'
      when :populating
        ' waiting for players!'
      when :active
        ' at WAR! :crossed_swords:'
      when :concluded
        ' just finishing a battle.'
      else
        warn "Unknown Wintergrasp status: #{wg_data['status']}"
        "... Actually I don't know."
      end
    else
      warn 'Wintergrasp data missing; skipping.'
      wg = 'Wintergrasp data is unavailable. :shield:'
    end

    tb = 'Tol-barad is currently held by '
    tb_data = realm['tol-barad']
    if tb_data
      tb += case @@PVP_FACTIONS[tb_data['controlling-faction']]
      when :alliance
        'the Alliance! '
      when :horde
        'the Horde! '
      else
        'nobody! '
      end
      tb += 'Currently, the zone is'
      tb += case @@PVP_STATUS[tb_data['status']]
      when :idle
        ' uncontested.'
      when :populating
        ' waiting for players!'
      when :active
        ' at WAR! :crossed_swords:'
      when :concluded
        ' just finishing a battle.'
      else
        warn "Unknown Tol-barad status: #{tb_data['status']}"
        "... Actually I don't know."
      end
    else
      warn "Tol'barad data missing; skipping."
      tb = "Tol'barad data is unavilable. :shield:"
    end

    return "#{updown} #{wg} #{tb}"
  end

  def self.get_census(event, realm, guild, rank)
    begin
      event.send_message @@wait_messages.sample
      guild_data = @@api.guild realm, guild, :fields => 'members'
    rescue Battlenet::ApiException => ex
      if ex.code == 404
        event.send_message "#{event.user.mention} I couldn't find that guild or realm. Battle.net said this: `#{ex.reason}`"
      else
        warn "Error fetching guild data: #{ex.response}"
        event.send_message ":satellite: :boom: I couldn't work out wtf Battle.net was smoking. Try again later!"
      end
    end

    rank_name = 'all'
    rank_name = "Rank #{rank} or less" unless rank >= 9

    event.channel.start_typing
    members = guild_data['members'].select { |member| member['rank'] <= rank }

    classes = Hash.new(0)
    races = Hash.new(0)
    genders = Hash.new(0)

    members.each do |member|
      char = member['character']
      classes[char['class']] += 1
      races[char['race']] += 1
      genders[char['gender']] += 1
    end

    total_members = members.length.to_f # Dirty hack to force decimals later
    classes = classes.to_a.sort_by! { |entry| entry[1] }.reverse
    races = races.to_a.sort_by! { |entry| entry[1] }.reverse
    genders = genders.to_a.sort_by! { |entry| entry[1] }.reverse

    classes.map! { |it| [@class_ids[it[0]][:name], it[1]] }
    races.map! { |it| [@race_ids[it[0]][:name], it[1]] }
    genders.map! { |it|
      gender_name = 'men'
      gender_name = 'women' if @@CHARACTER_GENDERS[it[0]] == :female
      [gender_name, it[1]]
    }

    if races.length > 1
      percent = ((races[0][1]/total_members) * 100).round(2)
      race_summary = "Races: The majority of the sample was #{races[0][0]} with #{races[0][1]} members (#{percent}%)\n" +
          'The other races worked out as follows; '
      __first = true
      races.drop(1).each do |race|
        percent = ((race[1]/total_members) * 100).round(2)
        race_summary += ', ' unless __first
        __first = false
        race_summary += "#{race[0]}: #{race[1]} (#{percent}%)"
      end
    else
      race_summary = "Races: All of the sample was #{races[0][0]}!"
    end

    if classes.length > 1
      percent = ((classes[0][1]/total_members) * 100).round(2)
      class_summary = "Classes: The majority of the sample was #{classes[0][0]} with #{classes[0][1]} members (#{percent}%)\n" +
          'The other classes worked out as follows; '
      __first = true
      classes.drop(1).each do |cls|
        percent = ((cls[1]/total_members) * 100).round(2)
        class_summary += ', ' unless __first
        __first = false
        class_summary += "#{cls[0]}: #{cls[1]} (#{percent}%)"
      end
    else
      class_summary = "Classes: All of the sample was #{classes[0][0]}!"
    end

    if genders.length > 1 && genders[0][1] != genders[1][1]
      percent = ((genders[0][1]/total_members) * 100).round(2)
      gender_summary = "Genders: Most of the guilds characters are #{genders[0][0]} at #{genders[0][1]} (#{percent}%). " +
          "By simple subtraction, that leaves #{genders[1][1]} #{genders[1][0]}."
    elsif genders.length > 1
      # Equals!
      gender_summary = "Genders: The guild is split down the middle as far as gender goes. \\o/ (#{genders[0][1]} of each)"
    else
      gender_summary = "Genders: All of the sample were #{genders[0][0]}! Someone needs diversity training."
    end

    event.send_message "(#{event.user.mention}) The census is in for #{guild} (#{realm}) - #{rank_name} members (#{members.length} characters)!\n" +
        race_summary + "\n" + class_summary + "\n" + gender_summary
  end
end
