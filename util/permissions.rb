# frozen_string_literal: true

require 'json'
require 'discordrb'
require_relative '../util/utils'

##
# Permission handling per-server.
module Permissions
  RANKS = Const::PERMISSION_RANKS

  @__ranks_stringified = RANKS.map(&:to_s)
  @__global_admin = ''
  @__current_ranks = {}

  def self.load_from_disk
    @__current_ranks = JSONFiles.load_file 'ranks'
    debug "Loaded permissions for #{@__current_ranks.length} servers."
  end

  def self.save_to_disk
    JSONFiles.save_file 'ranks', @__current_ranks
  end

  def self.rank_exists?(rank_str)
    @__ranks_stringified.include? rank_str
  end

  def self.check_permission(server, user, rank)
    return true if Permissions.check_global_administrator user
    raise ArgumentError "invalid rank #{rank}" unless RANKS.find_index rank
    return __pm_permission_check user, rank unless server
    user_rank = nil
    serv_ranks = @__current_ranks[server.id.to_s]
    user_rank = serv_ranks[user.id.to_s] if serv_ranks
    user_rank ||= :user
    urank = RANKS.find_index(user_rank.to_sym)
    trank = RANKS.find_index(rank)
    urank >= trank
  end

  def self.__pm_permission_check(user, req_rank)
    highest_rank = :user
    @__current_ranks.each_value do |serv|
      rank = serv[user.id.to_s]
      next unless rank
      rank = rank.to_sym
      highest_rank = rank.to_sym if RANKS.find_index(highest_rank) < RANKS.find_index(rank.to_sym)
    end

    urank = RANKS.find_index(highest_rank)
    trank = RANKS.find_index(req_rank)
    urank >= trank
  end

  def self.get_all_for_user(bot, user)
    out = {}
    if Permissions.check_global_administrator user
      bot.servers.each_key do |srv_id|
        out[srv_id] = :administrator
      end
      return out
    end

    @__current_ranks.each do |srv_id, srv_ranks|
      srv_ranks.each do |uid, rank|
        out[srv_id.to_i] = rank.to_sym if rank != :user && uid == user.id.to_s
      end
    end
    out
  end

  def self.get_all_for_user_ranked(bot, user, min_rank)
    get_all_for_user(bot, user)
      .select { |_, rank| RANKS.find_index(rank) >= RANKS.find_index(min_rank) }
      .map { |sid, _| bot.servers[sid.to_i] }
  end

  def self.get_all_for_server(server)
    srv_ranks = @__current_ranks[server.id.to_s]
    if srv_ranks
      return srv_ranks.reject { |k, v| v == 'user' || k == '__server_name' }
                      .map { |k, v| [k, v.to_sym] }.to_h
    end
    {} # Blank hash for non-existant servers.
  end

  def self.check_global_administrator(user)
    user.id == @__global_admin
  end

  def self.set_permission(server, user, new_rank)
    serv_id = server.id.to_s
    user_id = user.id.to_s
    serv_ranks = @__current_ranks[serv_id]
    serv_ranks ||= {}
    serv_ranks['__server_name'] = server.name
    if new_rank == :user
      serv_ranks.delete(user_id)
    else
      serv_ranks[user_id] = new_rank
    end

    if serv_ranks.size == 1 # only __server_name
      @__current_ranks.delete(serv_id)
    else
      @__current_ranks[serv_id] = serv_ranks
    end
    info "Updated permissions on server \"#{server.name}\" for user \"#{user.name}\" to #{new_rank}"
    save_to_disk
  end

  def self.global_administrator=(admin_id)
    @__global_admin = admin_id.to_i
    info "Using user ID #{@__global_admin} as global administrator." unless @__global_admin.zero?
  end
end
