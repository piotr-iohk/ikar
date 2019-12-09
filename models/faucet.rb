require 'httparty'

class Faucet
  include HTTParty

  def get_monies(faucet_url, address)
    self.class.post("#{faucet_url}/#{address}")
  end

end
