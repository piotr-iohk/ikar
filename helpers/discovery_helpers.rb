module Helpers
  module Discovery
    # Get port from wallet_cmdline
    # @param wallet_cmdline [String]
    # @returns port [Int or nil]
    def get_port(wallet_cmdline)
      cmd = wallet_cmdline.split
      port_idx = cmd.index("--port")
      cmd[port_idx + 1].to_i if port_idx
    end

    def get_cert_server_path(wallet_cmdline)
      cmd = wallet_cmdline.split
      id = cmd.index("--tls-ca-cert")
      size = cmd.size
      res = ''
      i = 1

      if id
        res = cmd[id + i]
        until (id + i == size - 1) || (cmd[id + i + 1].start_with? "--") do
          res += " #{cmd[id + i + 1]}"
          i += 1
        end
        res = res.strip
      end
      res
    end

    def guess_protocol(wallet_cmdline)
      (wallet_cmdline.include? "--tls-ca-cert") ? "https" : "http"
    end

    # Guess client cert location based on server_path
    def guess_client_cert_path(server_path, client_cert, s = App.separator)
      if server_path
        suffix = ''
        suffix = "\"" if server_path.start_with?("\"")
        suffix = "'" if server_path.start_with?("'")
        cp = server_path.split(s)[0...-2].join(s)
      end
      cp + "#{s}client#{s}#{client_cert}#{suffix}" if cp
    end
  end
end
