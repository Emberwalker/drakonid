require 'discordrb'
require_relative '../util/../util/permissions'
require_relative '../util/files'

module Quotes
  extend Discordrb::Commands::CommandContainer

  JSON_FILE_NAME = 'quotes'
  ALIAS_JSON_FILE_NAME = 'quotes_aliases'
  @__quotes = {}
  @__aliases = {}

  def self.load_quotes
    @__quotes = JSONFiles.load_file JSON_FILE_NAME
    @__aliases = JSONFiles.load_file ALIAS_JSON_FILE_NAME
  end

  def self.save_quotes
    JSONFiles.save_file JSON_FILE_NAME, @__quotes
    JSONFiles.save_file ALIAS_JSON_FILE_NAME, @__aliases
  end

  command :quote do |event, *params|
    next if params.size == 0
    p0 = params[0].downcase
    if params.size == 1
      # 'list' or a category
      if p0 == 'list' || p0 == 'ls'
        # List all categories (with aliases)
        categories = @__quotes.map { |k, _| k }
                         .map { |k| [k, @__aliases
                                            .select {|_, av| av == k}
                                            .map {|ak, _| ak}] }.to_h
        next "#{event.user.mention} No categories to list!" if categories.size == 0
        event << "#{event.user.mention} Quote categories:"
        categories.each { |k, v|
          alias_str = ''
          alias_str = " (aliased as: #{v.join(', ')})" if v.size > 0
          event << "- #{k}#{alias_str}"
        }
      elsif p0 == 'reload'
        # Reload all from disk
        next "#{event.user.mention} :warning: You don't have permission to do that." unless Permissions.check_permission(event.server, event.user, :administrator)

        load_quotes
        next "#{event.user.mention} :card_box: Reloaded quotes and aliases from disk."
      else
        # Pick a random quote from the category if it exists
        category = @__quotes[p0]
        category = @__quotes[@__aliases[p0]] unless category
        next "#{event.user.mention} :mag: I don't know the category '#{p0}'." unless category
        next ":speech_left: #{p0}: \"#{category.sample}\""
      end
    else
      # Subcommands
      if p0 == 'add' && params.size >= 3
        next "#{event.user.mention} :warning: You don't have permission to do that." unless Permissions.check_permission(event.server, event.user, :superuser)
        cname = params[1].downcase
        quote = params[2..-1].join ' '

        # Try for a directly-named category
        category = @__quotes[cname]
        # ... else try to find an alias. Failing that, a blank array.
        unless category
          c_alias = @__aliases[cname]
          cname = c_alias if c_alias
          category = @__quotes[cname]
        end
        category = [] unless category

        category << quote
        @__quotes[cname] = category
        save_quotes

        next "#{event.user.mention} Added quote to the '#{cname}' category!"
      elsif p0 == 'alias' && params.size >= 3
        next "#{event.user.mention} :warning: You don't have permission to do that." unless Permissions.check_permission(event.server, event.user, :superuser)
        cname = params[1].downcase
        target_alias = params[2].downcase

        # Check the target category exists
        unless @__quotes[cname]
          c_alias = @__aliases[cname]
          cname = c_alias if c_alias
        end
        next "#{event.user.mention} :mag: I can't find the category '#{cname}' to alias to." unless @__quotes[cname]
        next "#{event.user.mention} A category or alias called '#{target_alias}' already exists!" if @__quotes[target_alias] || @__aliases[target_alias]

        @__aliases[target_alias] = cname
        save_quotes

        next "#{event.user.mention} '#{target_alias}' added as an alias for '#{cname}'."
      end
    end
    nil # In case a block above does not call 'next'
  end
end