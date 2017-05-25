require 'json'

module JSONFiles

  def JSONFiles.load_file(fname)
    fname = "#{fname}.json"
    out = nil
    begin
      File.open fname, 'r' do |f|
        raw = f.read
        out = JSON.parse raw
        debug "Loaded #{out.size} entries from #{fname}"
      end
    rescue Exception => ex
      warn "Couldn't load #{fname}; assuming empty: #{ex.message}"
      out = {}
    end
    out
  end

  def JSONFiles.save_file(fname, struct)
    fname = "#{fname}.json"
    raw_json = JSON.pretty_generate struct
    File.open fname, mode: 'w' do |f|
      f.write raw_json
    end
  end

end