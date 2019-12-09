require 'httparty'

class Jormungandr
  include HTTParty
  attr_accessor :port
  
  def initialize(port)
    @port = port
    @api = "http://localhost:#{port}/api/v0"
  end
  
  def is_connected?
    begin
      get_node_stats
      true
    rescue
      false
    end
  end
  
  def get_node_stats
    self.class.get("#{@api}/node/stats")
  end
  
  def get_settings
    self.class.get("#{@api}/settings")
  end
  
  def get_stake
    self.class.get("#{@api}/stake")
  end
  
  def get_stake_pools
    self.class.get("#{@api}/stake_pools")
  end
  
  def get_message_logs
    self.class.get("#{@api}/fragment/logs")
  end
  
  def get_leaders_logs
    self.class.get("#{@api}/leaders/logs")
  end
end