# frozen_string_literal: true

require 'discordrb'
require 'fuzzy_match'
require_relative '../util/utils'

##
# Keeping the peace.
module Disciplinary
  extend Discordrb::Commands::CommandContainer
  extend Discordrb::EventContainer

  # default duration of 15 minutes
  SLEEP_DURATION = 15 * 60
  DEFAULT_DURATION = 604_800 # 1 week
  JSON_FILE_NAME = 'disciplinary'
  CURRENT_PUNISHMENTS_KEY = 'current'
  ROLE_IDS_KEY = 'roles'
  @state_mutex = Thread::Mutex.new
  @state = { ROLE_IDS_KEY => {}, CURRENT_PUNISHMENTS_KEY => {} }
  @bot = nil
  @inited = false

  def self.init(bot)
    return if @inited
    @inited = true
    @bot = bot
    @state.merge! JSONFiles.load_file(JSON_FILE_NAME)
    @worker_thread = Thread.new do
      loop do
        check_for_expired
        sleep SLEEP_DURATION
      end
    end
  end

  def self.with_state_rw
    @state_mutex.synchronize do
      ret = yield
      JSONFiles.save_file JSON_FILE_NAME, @state
      return ret
    end
  end

  def self.with_state_r
    @state_mutex.synchronize do
      return yield
    end
  end

  def self.check_for_expired
    # Gather expired entries
    todo = Hash.new { |h, k| h[k] = [] }
    with_state_rw do
      @state[CURRENT_PUNISHMENTS_KEY].each_key do |server_id|
        punishments = @state[CURRENT_PUNISHMENTS_KEY][server_id.to_s]
        punishments.each_key do |uid|
          if Time.now > Time.at(punishments[uid].to_i)
            todo[server_id].push uid
            punishments.delete uid
          end
        end
        @state[CURRENT_PUNISHMENTS_KEY].delete server_id.to_s if punishments.empty?
      end
    end

    # Clear expired roles from users
    changed_entries = 0
    todo.each_key do |server_id|
      role_id = with_state_r { @state[ROLE_IDS_KEY][server_id.to_s] }
      server = @bot.servers[server_id.to_i]
      unless server
        debug "Invalid server in expired data - was a server removed? #{server_id}"
        next
      end
      todo[server_id].each do |uid|
        begin
          server.member(uid)&.remove_role(role_id)
        rescue Discordrb::Errors::NoPermission => ex
          info "disc/expiry: Remove role failed: No permission. Skipping server. #{ex}"
          break
        end
      end
      changed_entries += todo[server_id].length
    end

    info "Cleared #{changed_entries} disciplinary entries." unless changed_entries.zero?
    changed_entries
  end

  private_class_method :init, :with_state_rw, :with_state_r, :check_for_expired

  # Init the module once Discord is ready.
  ready do |evt|
    init evt.bot
  end

  command :disc do |event, *raw_msg_parts|
    if event.server
      # On a server
      srv = event.server
      rank = ServerConf.get(srv, Const::SVAR_DISC_ALLOW_SU) ? :superuser : :administrator
      next "#{event.user.mention} :warning: You don't have permission to do that." unless
        Permissions.check_permission(srv, event.user, rank)
      next "#{event.user.mention} :warning: No username/nick provided. Who are you wanting?" if
        raw_msg_parts.length.zero?

      member = Matchers.get_user_from_message raw_msg_parts[0], srv.members, event
      next "#{event.user.mention} :mag: I couldn't find anyone with the name '#{raw_msg_parts[0]}'." unless member
      time_msg = nil
      time_msg = raw_msg_parts[1..-1].join(' ') if raw_msg_parts.length > 1
    else
      # In PM
      next "#{event.user.mention} :warning: You need to specify a server *and* name at minimum for this command." unless
        raw_msg_parts.length >= 2

      possible_srvs = Permissions.get_all_for_user_ranked(event.bot, event.user, :superuser)
      possible_srvs.select! do |reject_srv|
        min_rank = ServerConf.get(reject_srv, Const::SVAR_DISC_ALLOW_SU) ? :superuser : :administrator
        Permissions.check_permission(reject_srv, event.user, min_rank)
      end
      next "#{event.user.mention} :warning: You don't have permission for this command on any servers." if
        possible_srvs.empty?

      if possible_srvs.length == 1
        srv = possible_srvs[0]
      else
        srv_name = raw_msg_parts[0]
        fz = FuzzyMatch.new(possible_srvs, read: :name)
        srv = fz.find(srv_name)
        next "#{event.user.mention} :warning: No server matching '#{srv_name}' that you have access to." unless srv
      end

      user_name = raw_msg_parts[1]
      member = Matchers.get_user_from_message(user_name, srv.members, event)
      next "#{event.user.mention} :mag: I can't find anyone called '#{user_name}' on #{srv.name}." unless member

      time_msg = nil
      time_msg = raw_msg_parts[2..-1].join(' ') if raw_msg_parts.length > 2
    end

    expires = Time.now + DEFAULT_DURATION
    expires = Chronology.get_time_after_now(time_msg) if time_msg
    unless expires
      next "#{event.user.mention} :interrobang: I don't understand the time period '#{time_msg}'. " \
               "Try a natural time, like '1 week' or '1st of January'."
    end
    next "#{event.user.mention} :hourglass: I'd need a time machine to apply that time!" if Time.now > expires

    role_id = with_state_r { @state[ROLE_IDS_KEY][srv.id.to_s] }
    next "#{event.user.mention} Disciplinary roles aren't configured on this server." unless role_id
    role = srv.role(role_id)
    next "#{event.user.mention} Disciplinary role on this server has been deleted. Set a new one with !drole." unless
      role

    with_state_rw do
      @state[CURRENT_PUNISHMENTS_KEY][srv.id.to_s] = {} unless @state[CURRENT_PUNISHMENTS_KEY][srv.id.to_s]
      @state[CURRENT_PUNISHMENTS_KEY][srv.id.to_s][member.id] = expires
    end

    begin
      member.add_role(role)
    rescue Discordrb::Errors::NoPermission => ex
      info "disc: Add role failed: No permission. #{ex}"
      next "#{event.user.mention} :boom: The bot doesn't have permission to do that. Check your server permissions."
    end

    next "#{event.user.mention} :zap: Role set on #{member.display_name} (#{srv.name}) - it will expire at #{expires}."
  end

  command :drole do |event, *raw_msg_parts|
    if event.server
      # On a server
      srv = event.server
      next "#{event.user.mention} :warning: You don't have permission to do that." unless
        Permissions.check_permission(srv, event.user, :administrator)
      next "#{event.user.mention} :warning: You need to provide a role name for this command." if
        raw_msg_parts.length.zero?
      role_name = raw_msg_parts.join ' '
    else
      # In PM
      next "#{event.user.mention} :warning: You need to provide a role name *and* server name for this command." if
        raw_msg_parts.length.zero? || raw_msg_parts.length == 1

      role_name = raw_msg_parts[0..-2].join ' '
      srv_name = raw_msg_parts[-1]

      possible_srvs = Permissions.get_all_for_user_ranked(event.bot, event.user, :administrator)
      next "#{event.user.mention} :warning: You don't have permission for this command on any servers." if
        possible_srvs.empty?

      if possible_srvs.length == 1
        srv = possible_srvs[0]
      else
        fz = FuzzyMatch.new(possible_srvs, read: :name)
        srv = fz.find(srv_name)
        next "#{event.user.mention} :warning: No server matching '#{srv_name}' that you have access to." unless srv
      end
    end

    fz = FuzzyMatch.new(srv.roles, read: :name)
    role = fz.find(role_name)
    next "#{event.user.mention} :mag: Couldn't find a role matching '#{role_name}' - Check it exists." unless role

    with_state_rw do
      @state[ROLE_IDS_KEY][srv.id.to_s] = role.id
    end

    # noinspection SpellCheckingInspection
    debug "drole: #{srv.id} (#{srv.name}) -> #{role.id} (#{role.name})"
    next "#{event.user.mention} :passport_control: Disciplinary role set to #{role.name} for #{srv.name}."
  end

  command :dsweep do |event|
    next "#{event.user.mention} :warning: You don't have permission to do that." unless
      Permissions.check_global_administrator event.user
    changed = check_for_expired
    next "#{event.user.mention} :cloud_tornado: Sweep completed; #{changed} entries cleared."
  end
end