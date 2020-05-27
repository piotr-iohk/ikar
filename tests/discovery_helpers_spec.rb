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

  it "get_cert_server_path" do
    path = "/path/server/ca.crt"
    cmd = "cardano-wallet-byron serve --shutdown-handler --port 45381 --tls-ca-cert #{path}"
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

end
