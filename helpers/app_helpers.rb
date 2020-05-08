module Helpers
  module App
    def handle_api_err(r, session)
      unless [200, 201, 202, 204].include? r.code
        # j = JSON.parse r.to_s
        session[:error] = "cardano-wallet responded with:<br/>
                          Code = #{r.code},<br/>
                          Json = #{r.to_s}"
        redirect "/"
      end
    end

    def os
      case RUBY_PLATFORM
      when /cygwin|mswin|mingw|bccwin|wince|emx/
        "Windows"
      when /darwin/
        "MacOS"
      when /linux/
        "Linux"
      else
        RUBY_PLATFORM
      end
    end

    # units
    def render_wal_status(status, wal)
      case status
      when "not_responding" then cl = "bg-danger"
      when "syncing" then cl = "bg-warning"
      when "ready" then cl = "bg-success"
      else cl = "bg-danger"
      end
      r = "<div class=\"d-inline p-2 #{cl} text-white\">#{status}</div>"
      r += ", Progress: #{wal['state']['progress']['quantity']}%" if status == "syncing"
      r
    end

    def prepare_mnemonics(mn)
      if mn.include? ","
        mn.split(",").map {|w| w.strip}
      else
        mn.split
      end
    end

    def bits_from_word_count wc
      case wc
        when '9'
          bits = 96
        when '12'
          bits = 128
        when '15'
          bits = 164
        when '18'
          bits = 196
        when '21'
          bits = 224
        when '24'
          bits = 256
        else
          raise "Non-supported no of words #{wc}!"
      end
      bits
    end
  end
end
