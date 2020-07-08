module Helpers
  module App
    def is_connected?(w)
      begin
        w.misc.network.information
        true
      rescue
        false
      end
    end

    def handle_api_err(r, session)
      unless r
        session[:error] = "It seems I cannot make a connection to wallet..."
        redirect "/"
      end
      unless [200, 201, 202, 204].include? r.code
        uri = r.request.last_uri
        body = r.request.options[:body]
        method = r.request.http_method.to_s.split('::').last.upcase
        msg_about_request  = "Whoops! I did:<br/>#{method} #{uri}"
        msg_about_body     = "<br/>Body: <code>#{body}</code>" if body
        msg_about_response = "<br/><br/>The response was:<br/>
                              Code = #{r.code},<br/>
                              Message = #{r.to_s}"
        session[:error] = msg_about_request + msg_about_body.to_s + msg_about_response
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

    def separator
      if os == "Windows"
        "\\"
      else
        "/"
      end
    end

    module_function :os, :separator

    # units
    def render_deleg_status(status)
      case status
      when "not_delegating" then cl = "bg-secondary"
      when "delegating" then cl = "bg-primary"
      else cl = "bg-danger"
      end
      "<div class=\"d-inline p-2 #{cl} text-white\">#{status}</div>"
    end

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
