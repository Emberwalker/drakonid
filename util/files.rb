# frozen_string_literal: true

require 'json'

##
# JSON configuration loading/saving.
module JSONFiles

  # Loads a JSON configuration/state file from disk.
  #
  # @param fname [String] file name/path to open
  # @return [Object] The parsed JSON object
  def self.load_file(fname)
    fname = "#{fname}.json"
    out = nil
    begin
      File.open fname, 'r' do |f|
        raw = f.read
        out = JSON.parse raw
        debug "Loaded #{out.size} entries from #{fname}"
      end
    rescue StandardError => ex
      warn "Couldn't load #{fname}; assuming empty: #{ex.message}"
      out = {}
    end
    out
  end

  # Saves an object to a JSON configuration/state file on disk.
  #
  # @param fname [String] file name/path to write to
  # @param struct [Object] object to serialize
  def self.save_file(fname, struct)
    fname = "#{fname}.json"
    raw_json = JSON.pretty_generate struct
    File.open fname, mode: 'w' do |f|
      f.write raw_json
    end
  end
end
