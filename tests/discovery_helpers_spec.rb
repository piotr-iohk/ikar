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
end
