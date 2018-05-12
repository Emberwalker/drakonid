# frozen_string_literal: true

require 'json'
require_relative 'files'

# Per-server configuration handling.
module ServerConf
  JSON_FILE_NAME = 'server_conf'

  @__server_confs = {}

  # Loads the server configuration from disk. Calling a second time will reload the configuration.
  def self.load_from_disk
    @__server_confs = JSONFiles.load_file JSON_FILE_NAME
  end

  # Saves the server configuration to disk.
  def self.save_to_disk
    JSONFiles.save_file JSON_FILE_NAME, @__server_confs
  end

  # Fetches a given key for a specific server by name with an optional default value.
  #
  # @param server [Discordrb::Server] the server to fetch for
  # @param key [String] the key to look up
  # @param default [nil, Object] default value if the key doesn't exist
  # @return [nil, Object] the looked up value or the default value if it doesn't exist
  def self.get(server, key, default = nil)
    return default unless server
    srv_conf = @__server_confs.fetch(server.id.to_s, {})
    srv_conf.fetch(key, default)
  end

  # Looks up the status of a given SVar for a server.
  #
  # @param server [Discordrb::Server] the server to look up for
  # @param svar [const::SVarSpec] server variable to look up
  # @return [nil, Object] the looked up value for the given server, or the SVar default if not specified for the server
  def self.get_svar(server, svar)
    get(server, svar.internal, svar.default)
  end

  # Sets a new value for a given SVar or resets an SVar to the default for a given server.
  #
  # @param server [Discordrb::Server] the server to set/clear from
  # @param key [String] the SVar name to set/clear
  # @param value [nil, Object] the new value for the SVar - pass nil to reset the SVar to default
  def self.set(server, key, value)
    return delete(server, key) if value.nil?
    srv_conf = @__server_confs.fetch(server.id.to_s, {})
    srv_conf[key] = value
    @__server_confs[server.id.to_s] = srv_conf
    save_to_disk
  end

  # Deletes the stored value for a given SVar on a server.
  #
  # @param server [Discordrb::Server] the server to clear the SVar on
  # @param key [String] the SVar name to clear
  def self.delete(server, key)
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
