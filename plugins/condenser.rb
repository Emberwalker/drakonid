# frozen_string_literal: true

require 'discordrb'
require 'httparty'
require 'json'
require 'time'
require_relative '../util/permissions'
require_relative '../util/snark'
require_relative '../util/files'

# Support for the Condenser link shortener (https://github.com/Emberwalker/condenser)
module Condenser
  extend Discordrb::Commands::CommandContainer

  bucket :shorten, limit: 4, time_span: 15, delay: 2
  bucket :lmeta, limit: 4, time_span: 15, delay: 2

  command :shorten, bucket: :shorten do |event, code_opt, *url_parts|
    url = url_parts.join ' '
    code = nil
    if code_opt.downcase.start_with? 'http'
      url = code_opt + url
    else
      code = code_opt
    end
    next "#{event.user.mention} Condenser isn't configured for this bot. Ask your admin for help." unless
        config_valid? && @service

    begin
      user = event.user.username
      user = event.user.display_name if event.server
      serv = 'PM'
      serv = event.server.name if event.server
      shorturl = @service.shorten(url, user, serv, code)
    rescue ArgumentError
      next "#{event.user.mention} That URL is invalid. URLs must begin with `http://` or `https://`."
    rescue CondenserException => ex
      warn "Error in shorten: #{ex.dbg}"
      next "#{event.user.mention} An error occurred: #{ex.human}"
    rescue StandardError => ex
      warn "Unhandled exception from Condenser service: #{ex}"
      next "#{event.user.mention} An unknown error occurred. Ask the bot admin for help."
    end
    next "#{event.user.mention} #{shorturl}"
  end

  command :lmeta, bucket: :lmeta do |event, code|
    next "#{event.user.mention} Condenser isn't configured for this bot. Ask your admin for help." unless
        config_valid? && @service

    begin
      meta = @service.meta(code)
    rescue CondenserException => ex
      warn "Error in meta: #{ex.dbg}"
      next "#{event.user.mention} An error occurred: #{ex.human}"
    rescue StandardError => ex
      warn "Unhandled exception from Condenser service: #{ex}"
      next "#{event.user.mention} An unknown error occurred. Ask the bot admin for help."
    end
    event << "#{event.user.mention} Metadata for code #{code.upcase}:"
    event << "- Full URL: #{meta[:url]}"
    event << "- Created by: `#{meta[:owner]}`"
    # rubocop:disable Style/FormatStringToken
    event << "- Created at: `#{meta[:time].strftime('%d/%m/%y %H:%M:%S')}`"
    # rubocop:enable Style/FormatStringToken
    event << "- User-defined metadata: `#{meta[:meta]}`" if meta[:meta]
  end

  command :ldel, bucket: :shorten do |event, code|
    next "#{event.user.mention} Condenser isn't configured for this bot. Ask your admin for help." unless
        config_valid? && @service
    next "#{event.user.mention} :warning: You don't have permission for this command (superuser or above)" unless
        Permissions.check_permission(event.server, event.user, :superuser)

    begin
      ret = @service.del(code)
    rescue CondenserException => ex
      warn "Error in del: #{ex.dbg}"
      next "#{event.user.mention} An error occurred: #{ex.human}"
    rescue StandardError => ex
      warn "Unhandled exception from Condenser service: #{ex}"
      next "#{event.user.mention} An unknown error occurred. Ask the bot admin for help."
    end

    next "#{event.user.mention} Code '#{code.upcase}' did not exist." if ret[:status].casecmp('noexist').zero?
    next "#{event.user.mention} Code '#{code.upcase}' deleted."
  end

  def self.load_from_disk
    @conf = JSONFiles.load_file JSON_FILE_NAME
    update_httparty_service
  end

  @server_key = 'server'
  @api_key = 'api_key'
  @conf = {}
  @service = nil

  JSON_FILE_NAME = 'condenser'

  def self.config_valid?
    @conf[@server_key] && @conf[@api_key]
  end

  def self.update_httparty_service
    @service = nil
    @service = CondenserService.new(@conf[@server_key], @conf[@api_key]) if config_valid?
  end

  ##
  # HTTParty service for Condenser.
  class CondenserService
    include HTTParty

    default_timeout 10
    ssl_ca_file 'cacert.pem'
    headers 'User-Agent' => 'Drakonid (Discord.rb/HTTParty)'
    headers 'Content-Type' => 'application/json'
    headers 'Accept' => 'application/json'

    def initialize(server, key)
      self.class.headers 'X-API-Key' => key
      self.class.base_uri server
    end

    def shorten(url, username, server, code = nil)
      validation_url = url.downcase
      raise ArgumentError unless validation_url.start_with?('http://', 'https://')
      opts = { url: url, meta: "Submitted via Drakonid by #{username} (via #{server})" }
      opts['code'] = code if code
      resp = self.class.post('/api/shorten', body: JSON(opts))
      retcode = resp.response.code

      if retcode == '401'
        raise CondenserException.new('invalid API key; ask an admin to check the config!',
                                     '401 Unauthorized')
      elsif retcode == '409'
        raise CondenserException.new("code #{code} already exists. Delete it and try again, or try another shortcode.",
                                     '409 Conflict (Key in Use)')
      end

      unless retcode == '200'
        raise CondenserException.new("unknown error - what does #{retcode} mean?", "HTTP code != 200: #{retcode}")
      end

      resp['short_url']
    end

    def meta(code)
      resp = self.class.get("/api/meta/#{code}")
      retcode = resp.response.code
      raise CondenserException.new('code doesn\'t exist, check your spelling.', '404 Not Found') if retcode == '404'
      raise CondenserException.new("unknown error - what does #{retcode} mean?", "HTTP code != 200: #{retcode}") unless
          retcode == '200'
      {
        url: resp['full_url'],
        owner: resp['meta']['owner'],
        time: Time.parse(resp['meta']['time']),
        meta: resp['meta']['user_meta']
      }
    end

    def del(code)
      resp = self.class.post('/api/delete', body: JSON(code: code))
      retcode = resp.response.code
      raise CondenserException.new('invalid API key; ask an admin to check the config!', '401 Unauthorized') if
          retcode == '401'
      raise CondenserException.new("unknown error - what does #{retcode} mean?", "HTTP code != 200: #{retcode}") unless
          retcode == '200'
      {
        status: resp['status'],
        code: resp['code']
      }
    end
  end

  ##
  # An error thrown by Condenser.
  class CondenserException < StandardError
    def initialize(human_readable, debug)
      @human = human_readable
      @dbg = debug
      super(debug)
    end

    attr_reader :human
    attr_reader :dbg
  end
end
