require 'discordrb'
require 'fuzzy_match'
require_relative '../util/permissions'
require_relative '../util/conversations'
require_relative '../util/const'
require_relative '../util/server_conf'

module SVars
  extend Discordrb::Commands::CommandContainer

  command :svars do |event, *server_raw|
    if event.server
      # Run on a server channel
      srv = event.server
    else
      # Run in PM
      server_raw = server_raw.join ' '
      srvs = Permissions.get_all_for_user(event.bot, event.user)
                 .select { |_, rank| rank == :administrator }
                 .map { |sid, _| event.bot.servers[sid.to_i] }
      next "#{event.user.mention} You aren't an administrator on any servers covered by this bot." if srvs.empty?
      if srvs.size == 1
        srv = srvs[0]
      else
        fz = FuzzyMatch.new(srvs, :read => :name)
        srv = fz.find(server_raw)
        next "#{event.user.mention} I can't find any servers close to '#{server_raw}' - check your input." unless srv
      end
    end

    next "#{event.user.mention} :warning: You don't have permission to do that on '#{srv.name}'." unless Permissions.check_permission(srv, event.user, :superuser)

    event << "#{event.user.mention} :mag: SVars for server '#{srv.name}':"
    Const::ALL_SVARS.each { |sv| event << "- #{sv.internal} (#{sv.human}): #{ServerConf.get_svar(srv, sv)}" }

    nil
  end

  command :svar do |event, op_param, *params|
    op_param.downcase!
    op = nil
    op = :set if op_param == 'set'
    op = :rm if op_param == 'rm' || op_param == 'delete'
    next unless op

    svar_param = nil
    svar_param = params[-2] if op == :set
    svar_param = params[-1] if op == :rm
    svar_param.downcase!

    srv = event.server

    unless srv
      srv_param = nil
      srv_param = params[0..-3].join ' ' if op == :set
      srv_param = params[0..-2].join ' ' if op == :rm

      srvs = Permissions.get_all_for_user_ranked(event.bot, event.user, :administrator)
      next "#{event.user.mention} :warning: You aren't an administrator on any servers covered by this bot." if srvs.empty?

      fz = FuzzyMatch.new(srvs, :read => :name)
      srv = fz.find(srv_param)
      next "#{event.user.mention} I couldn't find a matching server you have administrator access to for '#{srv_param}'." unless srv
    end

    next "#{event.user.mention} :warning: You don't have permission to do that." unless Permissions.check_permission(event.server, event.user, :administrator)

    fz = FuzzyMatch.new(Const::ALL_SVARS, :read => :internal)
    svar = fz.find(svar_param)
    next "#{event.user.mention} I couldn't find a matching SVar for '#{svar_param}'. Check available SVars with `!svars`." unless svar

    next svar_set(event, srv, svar, params[-1]) if op == :set
    next svar_rm(event, srv, svar) if op == :rm
  end

  private
  def self.svar_set(event, srv, svar, val_param)
    val_param.downcase!

    if svar.type == :bool
      val = val_param == 'true' || val_param == 'yes' || val_param == 'y'
    elsif svar.type == :int
      val = begin
        Integer(val_param)
      rescue ArgumentError
        return "#{event.user.mention} :warning: Unable to read '#{val_param}' as an integer."
      end
    else
      raise ArgumentError "Unknown svar type: #{svar.type}"
    end

    ServerConf.set(srv, svar.internal, val)
    return "#{event.user.mention} :wrench: Updated SVar #{svar.internal} (#{svar.human}) to #{val} for server '#{srv.name}'."
  end

  def self.svar_rm(event, srv, svar)
    ServerConf.delete(srv, svar.internal)

    return "#{event.user.mention} :boom: Reset SVar #{svar.internal} (#{svar.human}) to #{svar.default} for server '#{srv.name}'."
  end
end