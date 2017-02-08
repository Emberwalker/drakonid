require 'json'
require 'discordrb'
require_relative '../logging'

module Permissions

  RANKS = [
      :user,
      :superuser,
      :administrator
  ]

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
