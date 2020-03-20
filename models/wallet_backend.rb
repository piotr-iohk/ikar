require 'httparty'

class NewWalletBackend
  include HTTParty
  attr_accessor :wid, :port

  def initialize(port, id = "0")
    @wid = id
    @port = port
    @api = "http://localhost:#{@port}/v2"
  end

  def is_connected?
    begin
      network_information
      true
    rescue
      false
    end
  end

  def network_information
    self.class.get("#{@api}/network/information")
  end

  def network_clock
    self.class.get("#{@api}/network/clock")
  end

  def network_parameters(epoch_num)
    self.class.get("#{@api}/network/parameters/#{epoch_num}")
  end

  def get_utxo(wid)
    self.class.get("#{@api}/wallets/#{wid}/statistics/utxos")
  end

  def force_resync(wid, slot_num, epoch_num)
    resync("wallets", wid, slot_num, epoch_num)
  end

  def byron_force_resync(wid, slot_num, epoch_num)
    resync("byron-wallets", wid, slot_num, epoch_num)
  end

  def resync(ep, wid, slot_num, epoch_num)
    self.class.put("#{@api}/#{ep}/#{wid}/tip",
    :body => { :slot_number => slot_num.to_i,
               :epoch_number => epoch_num.to_i  }.to_json,
    :headers => { 'Content-Type' => 'application/json' } )
  end


  def fee_stake_pools(wid)
    self.class.get("#{@api}/wallets/#{wid}/delegation-fees")
  end

  def get_stake_pools
    self.class.get("#{@api}/stake-pools")
  end

  def join_stake_pool(sp_id, passphrase, id = @wid)
    self.class.put("#{@api}/stake-pools/#{sp_id}/wallets/#{id}",
    :body => { :passphrase => passphrase }.to_json,
    :headers => { 'Content-Type' => 'application/json' } )
  end

  def quit_stake_pool(sp_id, passphrase, id = @wid)
    self.class.delete("#{@api}/stake-pools/#{sp_id}/wallets/#{id}",
    :body => { :passphrase => passphrase }.to_json,
    :headers => { 'Content-Type' => 'application/json' } )
  end

  def create_transaction(amount, address, passphrase, id = @wid)
    amount = amount.to_i
    self.class.post("#{@api}/wallets/#{id}/transactions",
    :body => { :payments =>
                   [ { :address => address,
                       :amount => { :quantity => amount,
                                    :unit => 'lovelace' }
                     }
                   ],
               :passphrase => passphrase
             }.to_json,
    :headers => { 'Content-Type' => 'application/json' } )
  end

  def forget_transaction(wid, txid)
    self.class.delete("#{@api}/wallets/#{wid}/transactions/#{txid}")
  end

  def create_wallet(mnemonics, passphrase, name, pool_gap = 20)
    self.class.post("#{@api}/wallets",
    :body => { :name => name,
               :mnemonic_sentence => mnemonics,
               :passphrase => passphrase,
               :address_pool_gap => pool_gap
             }.to_json,
    :headers => { 'Content-Type' => 'application/json' } )
  end

  def create_wallet_from_pub_key(pub_key, name, pool_gap = 20)
    self.class.post("#{@api}/wallets",
    :body => { :name => name,
               :account_public_key => pub_key,
               :address_pool_gap => pool_gap
             }.to_json,
    :headers => { 'Content-Type' => 'application/json' } )
  end

  def wallets
    self.class.get("#{@api}/wallets")
  end

  def wallets_ids
    wallets.map { |w| w['id'] }
  end

  def wallet (id = @wid)
    self.class.get("#{@api}/wallets/#{id}")
  end

  def wallet_balance (id = @wid)
    wallet(id)['balance']['available']['quantity']
  end

  def addresses (id = @wid, q = "")
    self.class.get("#{@api}/wallets/#{id}/addresses#{q}")
  end

  def addresses_used (id = @wid)
    addresses(id, "?state=used")
  end

  def addresses_unused (id = @wid)
    addresses(id, "?state=unused")
  end

  def delete (id = @wid)
    self.class.delete("#{@api}/wallets/#{id}")
  end

  def transactions (id = @wid, q = "")
    self.class.get("#{@api}/wallets/#{id}/transactions#{q}")
  end

  # BYRON

  def byron_forget_transaction(wid, txid)
    self.class.delete("#{@api}/byron-wallets/#{wid}/transactions/#{txid}")
  end

  def migrate_byron_wallet(srcWid, dstWid, passphrase)
    self.class.post("#{@api}/byron-wallets/#{srcWid}/migrations/#{dstWid}",
      :body => { :passphrase => passphrase }.to_json,
      :headers => { 'Content-Type' => 'application/json' } )
  end

  def migration_cost_byron_wallet(srcWid)
    self.class.get("#{@api}/byron-wallets/#{srcWid}/migrations" )
  end

  def create_byron_wallet(style, mnemonics, passphrase, name)
    styles = ["random", "icarus", "trezor", "ledger"]
    err = "Invalid wallet style: #{style}, valid styles are: #{styles}"
    raise err unless styles.include? style

    self.class.post("#{@api}/byron-wallets",
    :body => { :name => name,
               :style => style,
               :mnemonic_sentence => mnemonics,
               :passphrase => passphrase
             }.to_json,
    :headers => { 'Content-Type' => 'application/json' } )
  end

  def byron_wallets
    self.class.get("#{@api}/byron-wallets")
  end

  def byron_wallets_ids
    byron_wallets.map { |w| w['id'] }
  end

  def byron_wallet (id = @wid)
    self.class.get("#{@api}/byron-wallets/#{id}")
  end

  def byron_delete (id = @wid)
    self.class.delete("#{@api}/byron-wallets/#{id}")
  end

  def byron_transactions (id = @wid, q = "")
    self.class.get("#{@api}/byron-wallets/#{id}/transactions#{q}")
  end

  def byron_create_transaction(amount, address, passphrase, id)
    amount = amount.to_i
    self.class.post("#{@api}/byron-wallets/#{id}/transactions",
    :body => { :payments =>
                   [ { :address => address,
                       :amount => { :quantity => amount,
                                    :unit => 'lovelace' }
                     }
                   ],
               :passphrase => passphrase
             }.to_json,
    :headers => { 'Content-Type' => 'application/json' } )
  end

end

class String
    def is_i?
       /\A[-+]?\d+\z/ === self
    end
end

# w = NewWalletBackend.new "8090"
# id = "307bf05a10316a7cd4d07690b731e2e0fa37b531"
# amount = 90000000000
# address = "addr1sk7cjynnqpamfnls5nnlvdr3duehy99dv3pce6yemulq42zpr039s2crfyp"
# passphrase = "Secure Passphrase"
#
# pp w.create_transaction amount, address, passphrase, id
