# frozen_string_literal: true

require 'discordrb'
require 'fuzzy_match'
require_relative '../util/permissions'
require_relative '../util/snark'
require_relative '../util/conversations'

# noinspection RubyStringKeysInHashInspection
module Base
  extend Discordrb::Commands::CommandContainer

  command :stop do |event|
    if Permissions.check_global_administrator event.user
      event.send_message "#{event.user.mention} Shutting down..."
      event.bot.stop
      next
    end
    "#{event.user.mention} You don't have permission to do that."
  end

  command :permset do |event, *inp|
    next "#{event.user.mention} Pardon? (`!permset @user rank`)" if inp.size < 2
    rank_raw = inp[-1].downcase
    usr_raw = inp[0..-2].join ' '
    next "#{event.user.mention} That permission level doesn't exist." unless Permissions.rank_exists? rank_raw
    rank = rank_raw.to_sym
    next permset_pm(event, usr_raw, rank) if event.channel.private?

    next "#{event.user.mention} :warning: You don't have permission to do that." unless
        Permissions.check_permission(event.server, event.user, :administrator)
    mentions = event.message.mentions
    # rubocop:disable Style/GuardClause
    if mentions.length == 1
      Permissions.set_permission event.server, mentions[0], rank
      next "#{event.user.mention} :wrench: Updated permissions for user #{mentions[0].mention} to rank #{rank}."
    else
      next __find_and_add_rank(event.user, event.server, event.server.members, usr_raw, rank)
    end
    # rubocop:enable Style/GuardClause
  end

  def self.permset_pm(event, usr_raw, rank)
    # Get servers the user has admin rights on
    admin_servers = Permissions.get_all_for_user(event.bot, event.user)
                               .select { |_, v| v == :administrator }
                               .map { |k, _| k }
                               .sort
    return "#{event.user.mention} You aren't an administrator on any servers covered by this bot." if
        admin_servers.empty?

    if admin_servers.size == 1
      srv = event.bot.servers[admin_servers[0]]
      # If user ID to set perms, do it.
      usr_id = usr_raw.to_i
      if usr_id.positive?
        target_user = srv.member(usr_id)
        if target_user.nil?
          return "#{event.user.mention} I can't find the user ID #{usr_id} on the server you are administrator " \
                 "of (#{srv.name})"
        end
        Permissions.set_permission(srv, target_user, rank)
        return "#{event.user.mention} :wrench: Updated permissions for user #{target_user.display_name} to " \
               "rank #{rank} on server #{srv.name}."
      end
      # User is probably a string - nick or name.
      return __find_and_add_rank(event.user, srv, srv.members, usr_raw, rank, true)
    else
      # List servers, prep await.
      srvs = admin_servers.map { |key| event.bot.servers[key] }
      event << "#{event.user.mention} There's #{srvs.size} servers you could be referring to. Answer with the " \
               "number before the correct one (or 'abort' to cancel):"
      srvs.each_with_index do |srv_i, i|
        event << "#{i + 1} - #{srv_i.name}"
      end
      # We cache the member lists as fetching them inexplicably fails in the await.
      member_lists = srvs.map(&:members)

      reply_func = Conversations.numeric_conversation(srvs.size) do |evt, ans|
        srv = srvs[ans]
        members = member_lists[ans]
        evt.message.reply __find_and_add_rank(evt.user, srv, members, usr_raw, rank, true)
      end

      # noinspection SpellCheckingInspection
      event.message.await("permset_#{event.user.name}", &reply_func)
      return nil
    end
  end

  command :permlist do |event, *params|
    srv = event.server
    unless srv
      srvs = Permissions.get_all_for_user_ranked(event.bot, event.user, :superuser)
      next "#{event.user.mention} You aren't a superuser on any servers covered by this bot." if srvs.empty?
      srv = srvs[0]
      unless srvs.size == 1
        next "#{event.user.mention} Which server do you want to list? (PM usage: `!permlist Server Name`)" if
            params.empty?

        fz = FuzzyMatch.new(srvs, read: :name)
        srv = fz.find(params.join(' '))
        unless srv
          next "#{event.user.mention} I couldn't find any servers similar to '#{params.join(' ')}' - Check your input."
        end
      end
    end

    next "#{event.user.mention} :warning: You don't have permission to do that on '#{srv.name}'." unless
        Permissions.check_permission(srv, event.user, :superuser)

    perms = Permissions.get_all_for_server(srv)
    next "#{event.user.mention} There are no permissions defined for server '#{srv.name}'." if perms.empty?
    event << "#{event.user.mention} Permissions for server '#{srv.name}':"

    perms = perms.sort_by { |uid, rank| [Permissions::RANKS.find_index(rank), uid.to_i] }
    perms.each do |uid, rank|
      member = srv.members.select { |m| m.id == uid.to_i }.first
      next unless member
      event << "- #{member.display_name}: #{rank}"
    end

    nil
  end

  def self.__find_and_add_rank(requester, srv, members, usr_raw, rank, render_server = false)
    fz = FuzzyMatch.new(members, read: :display_name)
    res = fz.find(usr_raw)
    if res.nil?
      # Try raw names, NOT nicks
      fz = FuzzyMatch.new(members, read: :username)
      res = fz.find(usr_raw)
    end
    srv_text = ''
    srv_text = " on server '#{srv.name}'" if render_server
    if res.nil?
      return "#{requester.mention} Who? I can't find anyone similar enough to '#{usr_raw}'#{srv_text}. Maybe try " \
             'with an @ mention?'
    end

    Permissions.set_permission srv, res, rank
    "#{requester.mention} :wrench: Updated permissions for user #{res.display_name} to rank #{rank}#{srv_text}."
  end

  command :snarkpls do |event|
    next "#{event.user.mention} :warning: You don't have permission to do that." unless
        Permissions.check_permission(event.server, event.user, :superuser)
    next "#{event.user.mention} This has to be run in a server channel." if event.channel.private?

    Snark.set_server_snark(event.server, true)
    next Snark.snrk(event.server, '@USER@ Snark enabled.', [
                      '@USER@ Pff. Fine. Expect much sarcasm from now on...',
                      '@USER@ Yes sir/ma\'am, I respect your authority. For now.',
                      '@USER@ It\'s on now. I hope you\'re happy.'
                    ], '@USER@' => event.user.mention)
  end

  command :wehatefun do |event|
    next "#{event.user.mention} :warning: You don't have permission to do that." unless
        Permissions.check_permission(event.server, event.user, :superuser)
    next "#{event.user.mention} This has to be run in a server channel." if event.channel.private?

    Snark.set_server_snark(event.server, false)
    next "#{event.user.mention} Snark disabled."
  end
end
