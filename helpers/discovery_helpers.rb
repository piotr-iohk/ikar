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
      cert_path_idx = cmd.index("--tls-ca-cert")
      cmd[cert_path_idx + 1] if cert_path_idx
    end

    def guess_protocol(wallet_cmdline)
      (wallet_cmdline.include? "--tls-ca-cert") ? "https" : "http"
    end

    # Guess client cert location based on server_path
    def guess_client_cert_path(server_path, client_cert)
      cp = server_path.split('/')[0...-2].join("/") if server_path
      cp + "/client/#{client_cert}" if cp
    end
  end
end
