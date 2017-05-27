require 'json'
require 'discordrb'
require_relative '../logging'
require_relative '../util/utils'

module Permissions

  RANKS = Const::PERMISSION_RANKS

  @__ranks_stringified = RANKS.map { |sym| sym.to_s }
  @__global_admin = ''
  @__current_ranks = {}

  def Permissions.load_from_disk
    if File.exists? 'ranks.json'
      begin
        File.open('ranks.json') { |f|
          @__current_ranks = JSON.load f
        }
      rescue Exception => ex
        warn "Exception parsing ranks JSON: #{ex}"
      end
    end
    debug "Loaded permissions for #{@__current_ranks.length} servers."
  end

  def Permissions.save_to_disk
    raw_json = JSON.pretty_generate @__current_ranks
    File.open 'ranks.json', mode: 'w' do |f|
      f.write raw_json
    end
  end

  def Permissions.rank_exists?(rank_str)
    @__ranks_stringified.include? rank_str
  end

  def Permissions.check_permission(server, user, rank)
    return true if Permissions::check_global_administrator user
    unless RANKS.find_index rank
      raise ArgumentError "invalid rank #{rank}"
    end
    return __pm_permission_check user, rank unless server
    user_rank = nil
    serv_ranks = @__current_ranks[server.id.to_s]
    if serv_ranks
      user_rank = serv_ranks[user.id.to_s]
    end
    user_rank = :user unless user_rank
    urank = RANKS.find_index(user_rank.to_sym)
    trank = RANKS.find_index(rank)
    urank >= trank
  end

  def Permissions.__pm_permission_check(user, req_rank)
    highest_rank = :user
    @__current_ranks.each_value { |serv|
      rank = serv[user.id.to_s]
      next unless rank
      highest_rank = rank.to_sym if RANKS.find_index(highest_rank) < RANKS.find_index(rank.to_sym)
    }

    urank = RANKS.find_index(highest_rank)
    trank = RANKS.find_index(req_rank)
    urank >= trank
  end

  def Permissions.get_all_for_user(bot, user)
    out = {}
    if Permissions::check_global_administrator user
      bot.servers.each { |srv_id, _|
        out[srv_id] = :administrator
      }
      return out
    end

    @__current_ranks.each { |srv_id, srv_ranks|
      srv_ranks.each { |uid, rank|
        out[srv_id.to_i] = rank if rank != :user && uid == user.id.to_s
      }
    }
    out
  end

  def Permissions.get_all_for_user_ranked(bot, user, min_rank)
    get_all_for_user(bot, user)
        .select { |_, rank| RANKS.find_index(rank) >= RANKS.find_index(min_rank) }
        .map { |sid, _| bot.servers[sid.to_i] }
  end

  def Permissions.get_all_for_server(server)
    @__current_ranks[server.id.to_s].reject { |k, v| v == 'user' || k == '__server_name' }
  end

  def Permissions.check_global_administrator(user)
    user.id == @__global_admin
  end

  def Permissions.set_permission(server, user, new_rank)
    serv_id = server.id.to_s
    user_id = user.id.to_s
    serv_ranks = @__current_ranks[serv_id]
    serv_ranks = {} unless serv_ranks
    serv_ranks['__server_name'] = server.name
    serv_ranks[user_id] = new_rank
    @__current_ranks[serv_id] = serv_ranks
    info "Updated permissions on server \"#{server.name}\" for user \"#{user.name}\" to #{new_rank}"
    save_to_disk
  end

  def Permissions.set_global_administrator(admin_id)
    @__global_admin = admin_id.to_i
    info "Using user ID #{@__global_admin} as global administrator." unless @__global_admin == 0
  end

end
