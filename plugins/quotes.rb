require 'discordrb'
require_relative '../util/utils'

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
    if event.server && !ServerConf.get_svar(event.server, Const::SVAR_ALLOW_QUOTES)
      next unless Permissions.check_permission(event.server, event.user, :superuser)
    end

    next if params.size == 0
    p0 = params[0].downcase
    if params.size == 1
      # 'list' or a category
      if p0 == 'list' || p0 == 'ls'
        next list_categories(event)
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
        next add_quote(event, params)
      elsif p0 == 'alias' && params.size >= 3
        next add_alias(event, params)
      elsif (p0 == 'ls' || p0 == 'list') && params.size >= 2
        next "#{event.user.mention} :warning: You don't have permission to do that." unless Permissions.check_permission(event.server, event.user, :superuser)
        cname = params[1].downcase
        category = @__quotes[cname]
        category = @__quotes[@__aliases[cname]] unless category
        next "#{event.user.mention} :mag: I don't know the category '#{cname}'." unless category

        chunker = Chunker.new
        chunker << "#{event.user.mention} Quotes in category '#{cname}':"
        category.each { |q| chunker << "- \"#{q}\"" }
        chunker.send(event)
      elsif (p0 == 'rm' || p0 == 'delete') && params.size >= 2
        next rm_quote(event, params)
      end
    end
    nil # In case a block above does not call 'next'
  end

  private
  def self.list_categories(event)
    # List all categories (with aliases)
    categories = @__quotes.map { |k, _| k }
                     .map { |k| [k, @__aliases
                                        .select {|_, av| av == k}
                                        .map {|ak, _| ak}] }.to_h
    return "#{event.user.mention} No categories to list!" if categories.size == 0
    event << "#{event.user.mention} Quote categories:"
    categories.each { |k, v|
      alias_str = ''
      alias_str = " (aliased as: #{v.join(', ')})" if v.size > 0
      event << "- #{k}#{alias_str}"
    }
    nil
  end

  def self.add_quote(event, params)
    return "#{event.user.mention} :warning: You don't have permission to do that." unless Permissions.check_permission(event.server, event.user, :superuser)
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

    return "#{event.user.mention} Added quote to the '#{cname}' category!"
  end

  def self.add_alias(event, params)
    return "#{event.user.mention} :warning: You don't have permission to do that." unless Permissions.check_permission(event.server, event.user, :superuser)
    cname = params[1].downcase
    target_alias = params[2].downcase

    # Check the target category exists
    unless @__quotes[cname]
      c_alias = @__aliases[cname]
      cname = c_alias if c_alias
    end
    return "#{event.user.mention} :mag: I can't find the category '#{cname}' to alias to." unless @__quotes[cname]
    return "#{event.user.mention} A category or alias called '#{target_alias}' already exists!" if @__quotes[target_alias] || @__aliases[target_alias]

    @__aliases[target_alias] = cname
    save_quotes

    return "#{event.user.mention} '#{target_alias}' added as an alias for '#{cname}'."
  end

  def self.rm_quote(event, params)
    return "#{event.user.mention} :warning: You don't have permission to do that." unless Permissions.check_permission(event.server, event.user, :superuser)

    cname = params[1].downcase
    category = @__quotes[cname]
    unless category
      c_alias = @__aliases[cname]
      cname = c_alias if c_alias
      category = @__quotes[cname]
    end
    return "#{event.user.mention} :mag: I don't know the category '#{cname}'." unless category

    chunker = Chunker.new
    chunker << "#{event.user.mention} Listing quotes in category '#{cname}' - Reply with the number of the quote to delete, or 'abort' to cancel:"
    category.each_with_index { |quote, i| chunker << "#{i + 1}. \"#{quote}\"" }
    chunker.send(event)

    await_func = Conversations.numeric_conversation(category.size) { |evt, ans|
      quote = category[ans]
      msg = evt.message
      unless @__quotes[cname]
        msg.reply "#{evt.user.mention} The category seems to have disappeared between the start of the session and now. Try again."
        return true
      end
      @__quotes[cname].delete(quote)
      msg.reply "#{evt.user.mention} Quote #{ans + 1} (\"#{quote}\") deleted from category '#{cname}'."

      if @__quotes[cname].size == 0
        @__quotes.delete(cname)
        @__aliases.reject! { |_, v| v == cname }
        msg.reply "#{evt.user.mention} Category '#{cname}' exhausted. Removing category and matching aliases."
      end

      save_quotes
    }

    event.message.await("rmquote_#{event.user.name}", &await_func)
    return nil
  end
end