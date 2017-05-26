require 'json'
require_relative 'files'

module ServerConf

  JSON_FILE_NAME = 'server_conf'

  @__server_confs = {}

  def ServerConf.load_from_disk
    @__server_confs = JSONFiles.load_file JSON_FILE_NAME
  end

  def ServerConf.save_to_disk
    JSONFiles.save_file JSON_FILE_NAME, @__server_confs
  end

  def ServerConf.get(server, key, default = nil)
    srv_conf = @__server_confs.fetch(server.id.to_s, {})
    srv_conf.fetch(key, default)
  end

  def ServerConf.get_svar(server, svar)
    get(server, svar.internal, svar.default)
  end

  def ServerConf.set(server, key, value)
    return delete(server, key) if value.nil?
    srv_conf = @__server_confs.fetch(server.id.to_s, {})
    srv_conf[key] = value
    @__server_confs[server.id.to_s] = srv_conf
    save_to_disk
  end

  def ServerConf.delete(server, key)
    srv_conf = @__server_confs.fetch(server.id.to_s, {})
    srv_conf.delete(key)

    if srv_conf.empty?
      @__server_confs.delete(server.id.to_s)
    else
      @__server_confs[server.id.to_s] = srv_conf
    end

    save_to_disk
  end

end