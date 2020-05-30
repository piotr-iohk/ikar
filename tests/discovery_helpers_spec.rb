require_relative 'spec_helper'

include Helpers::Discovery

describe Helpers::Discovery do
  it "get_port - gets port if there is one" do
    cmd = "cardano-wallet serve --port 8888 --other --options"
    expect(get_port cmd).to eq 8888
  end

  it "get_port - gets nil when no port" do
    cmd = "cardano-wallet serve --random-port --other --options"
    expect(get_port cmd).to eq nil
  end

  it "get_port - gets 0 when there is --port but not specified" do
    cmd = "cardano-wallet serve --port --other --options"
    expect(get_port cmd).to eq 0
  end

  it "get_cert_server_path - no path" do
    cmd = "cardano-wallet-byron serve --shutdown-handler --port 45381"
    expect(get_cert_server_path cmd).to eq ''
  end

  it "get_cert_server_path on Linux (last)" do
    path = "/path/server/ca.crt"
    cmd = "cardano-wallet-byron serve --shutdown-handler --tls-ca-cert #{path}"
    expect(get_cert_server_path cmd).to eq path
  end

  it "get_cert_server_path on Linux (middle)" do
    path = "/path/server/ca.crt"
    cmd = "cardano-wallet-byron serve --shutdown-handler --tls-ca-cert #{path} --port 4444"
    expect(get_cert_server_path cmd).to eq path
  end

  it "get_cert_server_path - path on Windows no spaces (last)" do
    path = "\"C:\\Users\\piotr\\AppData\\Roaming\\Daedalus\\tls\\server\\ca.crt\""
    cmd = "cardano-wallet-byron serve --shutdown-handler --tls-ca-cert #{path}"
    expect(get_cert_server_path cmd).to eq path
  end

  it "get_cert_server_path - path on Windows no spaces (middle)" do
    path = "'C:\\Users\\piotr\\AppData\\Roaming\\Daedalus\\tls\\server\\ca.crt'"
    cmd = "cardano-wallet-byron serve --shutdown-handler --tls-ca-cert #{path} --database"
    expect(get_cert_server_path cmd).to eq path
  end

  it "get_cert_server_path - path on Windows with spaces (last)" do
    path = "\"C:\\Users\\piotr\\AppData\\Roaming\\Daedalus Mainnet\\tls\\server\\ca.crt\""
    cmd = "cardano-wallet-byron serve --shutdown-handler --tls-ca-cert #{path}"
    expect(get_cert_server_path cmd).to eq path
  end

  it "get_cert_server_path - path on Windows with spaces (middle)" do
    path = "'C:\\Users\\piotr\\AppData\\Roaming\\Daedalus Mainnet\\tls\\server\\ca.crt'"
    cmd = "cardano-wallet-byron serve --shutdown-handler --tls-ca-cert #{path} --database"
    expect(get_cert_server_path cmd).to eq path
  end

  it "get_cert_server_path - path on Mac (last)" do
    path = "/Users/eoaslzzcn/Library/Application Support/Daedalus Mainnet/tls/server/ca.crt"
    cmd = "cardano-wallet-byron serve --tls-ca-cert #{path}"
    expect(get_cert_server_path cmd).to eq path
  end

  it "get_cert_server_path - path on Mac (middle)" do
    path = "/Users/eoaslzzcn/Library/Application Support/Daedalus Mainnet/tls/server/ca.crt"
    cmd = "cardano-wallet-byron serve --tls-ca-cert #{path} --tls-sv-cert"
    expect(get_cert_server_path cmd).to eq path
  end

  it "guess_protocol" do
    cmd1 = "cardano-wallet-byron serve --shutdown-handler --port 45381 --tls-ca-cert /path/to/cert"
    cmd2 = "cardano-wallet-byron serve --shutdown-handler --port 45381"
    expect(guess_protocol cmd1).to eq 'https'
    expect(guess_protocol cmd2).to eq 'http'
  end

  it "guess_client_cert_path" do
    path = "/path/server/ca.crt"
    expect(guess_client_cert_path path, "client.pem").to eq "/path/client/client.pem"
  end

  it "guess_client_cert_path" do
    expect(guess_client_cert_path '', "client.pem").to eq "/client/client.pem"
  end

  it "guess_client_cert_path on Windows" do
    path = "\"C:\\Users\\piotr\\AppData\\Roaming\\Daedalus Mainnet\\tls\\server\\ca.crt\""
    expect(guess_client_cert_path(path, "client.pem", "\\")).to eq "\"C:\\Users\\piotr\\AppData\\Roaming\\Daedalus Mainnet\\tls\\client\\client.pem\""

    path = "'C:\\Users\\piotr\\AppData\\Roaming\\Daedalus Mainnet\\tls\\server\\ca.crt'"
    expect(guess_client_cert_path(path, "client.pem", "\\")).to eq "'C:\\Users\\piotr\\AppData\\Roaming\\Daedalus Mainnet\\tls\\client\\client.pem'"
  end

end
