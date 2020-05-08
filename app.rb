require 'sinatra'
require 'bip_mnemonic'
require 'chartkick'

require_relative 'helpers/app_helpers'
require_relative './models/wallet_backend'
require_relative './models/jormungandr'

set :port, 4444
set :bind, '0.0.0.0'
set :root, File.dirname(__FILE__)

# enable :sessions
use Rack::Session::Pool
helpers Helpers::App

def show_session
  session.each_with_key do |k,v|
    puts "#{k} => #{v}"
  end
end

def prepare_mnemonics(mn)
  if mn.include? "["
    mn
  elsif mn.include? ","
    mn.split(",").map {|w| w.strip}
  else
    mn.split
  end
end

def handle_api_err(r, session)
  unless [200, 201, 202, 204].include? r.code
    # j = JSON.parse r.to_s
    session[:error] = "Wallet backend responded with:<br/>
                      Code = #{r.code},<br/>
                      Json = #{r.to_s}"
    redirect "/"
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
  end
  bits
end

get "/" do
  session[:wallet_port] ||= "8090"
  session[:jorm_port] ||= "8080"
  session[:platform] ||= os
  erb :index, { :locals => session }
end

post "/connect" do
  session[:wallet_port] = params["wallet_port"]
  session[:jorm_port] = params["jorm_port"]

  w = NewWalletBackend.new session[:wallet_port]
  j = Jormungandr.new session[:jorm_port]
  session[:w_connected] = w.is_connected?
  session[:j_connected] = j.is_connected?
  redirect "/"
end

# SHELLEY WALLETS

get "/wallets" do
  w = NewWalletBackend.new session[:wallet_port]
  r = w.wallets
  handle_api_err r, session
  wallets = r
  erb :wallets, { :locals => { :wallets => wallets } }
end

get "/wallets/:wal_id" do
  w = NewWalletBackend.new session[:wallet_port]
  wal = w.wallet params[:wal_id]
  handle_api_err wal, session
  txs = w.transactions params[:wal_id]
  handle_api_err txs, session
  addrs = w.addresses params[:wal_id]
  handle_api_err addrs, session

  erb :wallet, { :locals => { :wal => wal, :txs => txs, :addrs => addrs} }
end

get "/wallets/:wal_id/update" do
  w = NewWalletBackend.new session[:wallet_port]
  wal = w.wallet params[:wal_id]
  handle_api_err wal, session
  erb :form_wallet_update, { :locals => { :wal => wal } }
end

post "/wallets/:wal_id/update" do
  w = NewWalletBackend.new session[:wallet_port]
  r = w.wallet_update params[:wal_id], params[:name]
  handle_api_err r, session
  redirect "/wallets/#{params[:wal_id]}"
end

get "/wallets/:wal_id/update-pass" do
  w = NewWalletBackend.new session[:wallet_port]
  wal = w.wallet params[:wal_id]
  handle_api_err wal, session
  erb :form_wallet_update_pass, { :locals => { :wal => wal } }
end

post "/wallets/:wal_id/update-pass" do
  w = NewWalletBackend.new session[:wallet_port]
  r = w.wallet_update_pass params[:wal_id], params[:old_pass], params[:new_pass]
  handle_api_err r, session
  redirect "/wallets/#{params[:wal_id]}"
end

get "/wallets-delete/:wal_id" do
  w = NewWalletBackend.new session[:wallet_port]
  w.delete params[:wal_id]
  redirect "/wallets"
end

get "/wallets-create" do
  # 15-word mnemonics
  session[:mnemonics] = BipMnemonic.to_mnemonic(bits: 164, language: 'english')
  erb :form_create_wallet, { :locals => session }
end

post "/wallets-create" do
  w = NewWalletBackend.new session[:wallet_port]
  m = prepare_mnemonics params[:mnemonics]
  pass = params[:pass]
  name = params[:wal_name]
  pool_gap = params[:pool_gap].to_i

  wal = w.create_wallet(m, pass, name, pool_gap)
  handle_api_err wal, session
  session[:wal] = wal
  handle_api_err wal, session

  redirect "/wallets/#{wal['id']}"
end

get "/wallets-create-from-pub-key" do
  # 15-word mnemonics
  erb :form_create_wallet_from_pub_key, { :locals => session }
end

post "/wallets-create-from-pub-key" do

  w = NewWalletBackend.new session[:wallet_port]
  pub_key = params[:pub_key]
  name = params[:wal_name]
  pool_gap = params[:pool_gap].to_i
  wal = w.create_wallet_from_pub_key(pub_key, name, pool_gap)
  handle_api_err wal, session

  redirect "/wallets/#{wal['id']}"
end



get "/wallets-create-many" do
  erb :form_create_many
end

post "/wallets-create-many" do
  w = NewWalletBackend.new session[:wallet_port]
  pass = params[:pass]
  name = params[:wal_name]
  pool_gap = params[:pool_gap].to_i
  how_many = params[:how_many].to_i
  bits = bits_from_word_count params[:words_count]

  1.upto how_many do |i|
    mnemonics = BipMnemonic.to_mnemonic(bits: bits, language: 'english').split
    wal = w.create_wallet(mnemonics, pass, "#{name} #{i}", pool_gap)
    handle_api_err wal, session
  end
  redirect "/wallets"
end

get "/wallets-delete-all" do
  erb :form_del_all, { :locals => session }
end

post "/wallets-delete-all" do
  w = NewWalletBackend.new session[:wallet_port]
  w.wallets.each do |wal|
    r = w.delete wal['id']
    handle_api_err r, session
  end
  redirect "/wallets"
end

get "/wallets/:wal_id/utxo" do
  w = NewWalletBackend.new session[:wallet_port]
  utxo = w.get_utxo params[:wal_id]
  wal = w.wallet params[:wal_id]
  erb :utxo_details, { :locals => { :wal => wal, :utxo => utxo } }
end

# TRANSACTIONS SHELLEY

post "/tx-fee-to-address" do
  wid_src = params[:wid_src]
  amount = params[:amount]
  address = params[:address]

  w = NewWalletBackend.new session[:wallet_port]
  r = w.payment_fees(amount, address, wid_src)
  handle_api_err r, session

  erb :show_tx_fee, { :locals => { :tx_fee => r, :wallet_id => wid_src} }
end

get "/tx-fee-to-address" do
  w = NewWalletBackend.new session[:wallet_port]
  wallets = w.wallets
  erb :form_tx_fee_to_address, { :locals => { :wallets => wallets } }
end

get "/tx-to-address" do
  w = NewWalletBackend.new session[:wallet_port]
  wallets = w.wallets
  erb :form_tx_to_address, { :locals => { :wallets => wallets } }
end

post "/tx-to-address" do
  wid_src = params[:wid_src]
  pass = params[:pass]
  amount = params[:amount]
  address = params[:address]

  w = NewWalletBackend.new session[:wallet_port]
  r = w.create_transaction(amount, address, pass, wid_src)
  handle_api_err r, session

  redirect "/wallets/#{wid_src}/txs/#{r['id']}"
end

get "/tx-between-wallets" do
  w = NewWalletBackend.new session[:wallet_port]
  wallets = w.wallets
  erb :form_tx_between_wallets, { :locals => { :wallets => wallets } }
end

post "/tx-between-wallets" do
  wid_src = params[:wid_src]
  wid_dst = params[:wid_dst]
  pass = params[:pass]
  amount = params[:amount]

  w = NewWalletBackend.new session[:wallet_port]
  address_dst = w.addresses_unused(wid_dst).sample['id']
  r = w.create_transaction(amount, address_dst, pass, wid_src)
  handle_api_err r, session

  redirect "/wallets/#{wid_src}/txs/#{r['id']}"
end

get "/wallets/:wal_id/forget-tx/:tx_to_forget_id" do
  w = NewWalletBackend.new session[:wallet_port]
  id = params[:wal_id]
  txid = params[:tx_to_forget_id]
  r = w.forget_transaction id, txid
  handle_api_err r, session
  session[:forgotten] = txid
  redirect "/wallets/#{id}"
end

# show tx details
get "/wallets/:wal_id/txs/:tx_id" do
  w = NewWalletBackend.new session[:wallet_port]
  session[:wid] = params[:wal_id]
  session[:tx] = w.transactions(params[:wal_id]).select{ |tx| tx['id'] == params[:tx_id]}[0]
  erb :tx_details, { :locals => session }
end

# BYRON WALLETS

get "/byron-wallets/:wal_id/address" do
  w = NewWalletBackend.new session[:wallet_port]
  # r = w.byron_address_create params[:wal_id] ,params[:pass], params[:idx]
  # handle_api_err r, session
  erb :form_byron_wallet_address, { :locals => { :wid => params[:wal_id] } }
end

post "/byron-wallets/:wal_id/address" do
  w = NewWalletBackend.new session[:wallet_port]
  r = w.byron_address_create params[:wal_id] ,params[:pass], params[:idx]
  handle_api_err r, session
  redirect "/byron-wallets/#{params[:wal_id]}"
end

get "/byron-wallets/:wal_id/update" do
  w = NewWalletBackend.new session[:wallet_port]
  wal = w.byron_wallet params[:wal_id]
  handle_api_err wal, session
  erb :form_wallet_update, { :locals => { :wal => wal } }
end

post "/byron-wallets/:wal_id/update" do
  w = NewWalletBackend.new session[:wallet_port]
  r = w.byron_wallet_update params[:wal_id], params[:name]
  handle_api_err r, session
  redirect "/byron-wallets/#{params[:wal_id]}"
end

get "/byron-wallets/:wal_id/update-pass" do
  w = NewWalletBackend.new session[:wallet_port]
  wal = w.byron_wallet params[:wal_id]
  handle_api_err wal, session
  erb :form_wallet_update_pass, { :locals => { :wal => wal } }
end

post "/byron-wallets/:wal_id/update-pass" do
  w = NewWalletBackend.new session[:wallet_port]
  r = w.byron_wallet_update_pass params[:wal_id], params[:old_pass], params[:new_pass]
  handle_api_err r, session
  redirect "/byron-wallets/#{params[:wal_id]}"
end

get "/byron-wallets/:wal_id/utxo" do
  w = NewWalletBackend.new session[:wallet_port]
  utxo = w.byron_get_utxo params[:wal_id]
  wal = w.byron_wallet params[:wal_id]
  erb :utxo_details, { :locals => { :wal => wal, :utxo => utxo } }
end

get "/byron-wallets" do
  w = NewWalletBackend.new session[:wallet_port]
  session[:wallets] = w.byron_wallets
  erb :wallets, { :locals => session }
end

get "/byron-wallets/:wal_id" do
  w = NewWalletBackend.new session[:wallet_port], params[:wal_id]
  wallet = w.byron_wallet params[:wal_id]
  txs = w.byron_transactions params[:wal_id]
  handle_api_err wallet, session
  handle_api_err txs, session
  addrs = w.byron_addresses params[:wal_id]
  if addrs.code != 200
    addrs = nil
  else
    handle_api_err addrs, session
  end


  erb :wallet, { :locals => {:wal => wallet, :txs => txs, :addrs => addrs} }
end

get "/byron-wallets-delete/:wal_id" do
  w = NewWalletBackend.new session[:wallet_port], params[:wal_id]
  w.byron_delete params[:wal_id]
  redirect "/byron-wallets"
end

get "/byron-wallets-create" do
  # 12-word mnemonics
  session[:mnemonics] = BipMnemonic.to_mnemonic(bits: 128, language: 'english')
  erb :form_create_wallet, { :locals => session }
end

post "/byron-wallets-create" do
  w = NewWalletBackend.new session[:wallet_port]
  m = prepare_mnemonics params[:mnemonics]
  pass = params[:pass]
  name = params[:wal_name]
  style = params[:style]

  wal = w.create_byron_wallet(style, m, pass, "#{name} (#{style})")
  handle_api_err wal, session

  redirect "/byron-wallets/#{wal['id']}"
end

get "/byron-wallets-create-many" do
  erb :form_create_many, { :locals => session }
end

post "/byron-wallets-create-many" do
  w = NewWalletBackend.new session[:wallet_port]
  pass = params[:pass]
  name = params[:wal_name]
  how_many = params[:how_many].to_i
  style = params[:style]
  bits = bits_from_word_count params[:words_count]

  1.upto how_many do |i|
    mnemonics = BipMnemonic.to_mnemonic(bits: bits, language: 'english').split
    wal = w.create_byron_wallet(style, mnemonics, pass, "#{name} (#{style}) #{i}")
    handle_api_err wal, session
  end
  redirect "/byron-wallets"
end

get "/byron-wallets-delete-all" do
  erb :form_del_all, { :locals => session }
end

post "/byron-wallets-delete-all" do
  w = NewWalletBackend.new session[:wallet_port]
  w.byron_wallets.each do |wal|
    r = w.byron_delete wal['id']
    handle_api_err r, session
  end
  redirect "/byron-wallets"
end

get "/byron-wallets-migrate" do
  w = NewWalletBackend.new session[:wallet_port]
  wallets = w.wallets
  handle_api_err(wallets, session)
  byron_wallets = w.byron_wallets
  handle_api_err(byron_wallets, session)

  erb :form_migrate_byron, { :locals => { :wallets => wallets, :byron_wallets => byron_wallets} }
end

get "/byron-wallets-migration-fee/:wal_id" do
  w = NewWalletBackend.new session[:wallet_port]
  wid = params[:wal_id]
  r = w.migration_cost_byron_wallet wid
  handle_api_err(r, session)
  erb :show_migration_fee, { :locals => { :migration_fee => r, :wallet_id => wid} }
end

post "/byron-wallets-migrate" do
  wid_src = params[:wid_src]
  wid_dst = params[:wid_dst]
  pass = params[:pass]

  w = NewWalletBackend.new session[:wallet_port]
  r = w.migrate_byron_wallet(wid_src, wid_dst, pass)
  handle_api_err(r, session)

  session[:txs] = r
  session[:wid_src] = wid_src
  session[:wid_dst] = wid_dst
  erb :byron_migrated, { :locals => session }
end

get "/byron-wallets/:wal_id/txs/:tx_id" do
  w = NewWalletBackend.new session[:wallet_port]
  session[:wid] = params[:wal_id]
  session[:tx] = w.byron_transactions(params[:wal_id]).select{ |tx| tx['id'] == params[:tx_id]}[0]
  erb :tx_details, { :locals => session }
end

get "/byron-wallets/:wal_id/forget-tx/:tx_to_forget_id" do
  w = NewWalletBackend.new session[:wallet_port]
  id = params[:wal_id]
  txid = params[:tx_to_forget_id]
  r = w.byron_forget_transaction id, txid
  handle_api_err r, session
  session[:forgotten] = txid
  redirect "/byron-wallets/#{id}"
end

# TRANSACTIONS BYRON

post "/byron-tx-fee-to-address" do
  wid_src = params[:wid_src]
  amount = params[:amount]
  address = params[:address]

  w = NewWalletBackend.new session[:wallet_port]
  r = w.byron_payment_fees(amount, address, wid_src)
  handle_api_err r, session

  erb :show_tx_fee, { :locals => { :tx_fee => r, :wallet_id => wid_src} }
end

get "/byron-tx-fee-to-address" do
  w = NewWalletBackend.new session[:wallet_port]
  wallets = w.byron_wallets
  erb :form_tx_fee_to_address, { :locals => { :wallets => wallets } }
end

get "/byron-tx-to-address" do
  w = NewWalletBackend.new session[:wallet_port]
  wallets = w.byron_wallets
  erb :form_tx_to_address, { :locals => { :wallets => wallets } }
end

post "/byron-tx-to-address" do
  wid_src = params[:wid_src]
  pass = params[:pass]
  amount = params[:amount]
  address = params[:address]

  w = NewWalletBackend.new session[:wallet_port]
  r = w.byron_create_transaction(amount, address, pass, wid_src)
  handle_api_err r, session

  redirect "/byron-wallets/#{wid_src}/txs/#{r['id']}"
end

get "/byron-tx-between-wallets" do
  w = NewWalletBackend.new session[:wallet_port]
  session[:wallets] = w.byron_wallets
  erb :form_tx_between_wallets, { :locals => session }
end

post "/byron-tx-between-wallets" do
  wid_src = params[:wid_src]
  wid_dst = params[:wid_dst]
  pass = params[:pass]
  amount = params[:amount]

  w = NewWalletBackend.new session[:wallet_port]
  address_dst = w.addresses_unused(wid_dst).sample['id']
  r = w.create_transaction(amount, address_dst, pass, wid_src)
  handle_api_err r, session

  session[:tx] = r
  session[:wid] = wid_src
  redirect "/wallets/#{wid_src}/txs/#{r['id']}"
end

# MNEMONICS

get "/gen-mnemonics" do
  erb :form_gen_mnemonics, { :locals => session }
end

post "/gen-mnemonics" do
  bits = bits_from_word_count params[:words_count]
  session[:words_count] = params[:words_count]
  session[:mnemonics] = BipMnemonic.to_mnemonic(bits: bits, language: 'english')
  erb :form_gen_mnemonics, { :locals => session }
end

# STAKE-POOLS

get "/stake-pools" do
  w = NewWalletBackend.new session[:wallet_port]
  r = w.get_stake_pools
  handle_api_err r, session
  session[:stake_pools] = r
  erb :stake_pools, { :locals => session }
end

get "/stake-pools-join" do
  w = NewWalletBackend.new session[:wallet_port]
  session[:stake_pools] = w.get_stake_pools
  session[:wallets] = w.wallets
  erb :form_join_quit_sp, { :locals => session }
end

post "/stake-pools-join" do
  sp_id = params['spid']
  w_id = params['wid']
  pass = params['pass']
  w = NewWalletBackend.new session[:wallet_port]
  r = w.join_stake_pool sp_id, pass, w_id
  handle_api_err r, session
  redirect "/wallets/#{w_id}/txs/#{r['id']}"
end

get "/stake-pools-quit" do
  w = NewWalletBackend.new session[:wallet_port]
  session[:stake_pools] = w.get_stake_pools
  session[:wallets] = w.wallets
  erb :form_join_quit_sp, { :locals => session }
end

post "/stake-pools-quit" do
  sp_id = params['spid']
  w_id = params['wid']
  pass = params['pass']
  w = NewWalletBackend.new session[:wallet_port]
  r = w.quit_stake_pool sp_id, pass, w_id
  handle_api_err r, session
  redirect "/wallets/#{w_id}/txs/#{r['id']}"
end

get "/stake-pools-fee/:wal_id" do
  w = NewWalletBackend.new session[:wallet_port]
  wid = params['wal_id']
  r = w.fee_stake_pools wid
  handle_api_err r, session

  erb :show_delegation_fee, { :locals => { :delegation_fee => r, :wallet_id => wid} }
end

# MISC

get "/network-params" do
  erb :form_network_params
end

post "/network-params" do
  w = NewWalletBackend.new session[:wallet_port]
  r = w.network_parameters params['epoch_number']
  handle_api_err r, session
  erb :network_params, :locals => { :network_params => r }
end

get "/network-info" do
  w = NewWalletBackend.new session[:wallet_port]
  r = w.network_information
  handle_api_err r, session
  session[:network_info] = r
  erb :network_info, :locals => { :network_info => r }
end

get "/network-clock" do
  w = NewWalletBackend.new session[:wallet_port]
  r = w.network_clock
  handle_api_err r, session
  erb :network_clock, :locals => { :network_clock => r }
end

get "/network-stats" do
  j = Jormungandr.new session[:jorm_port]
  w = NewWalletBackend.new session[:wallet_port]

  my = Hash.new
  my[:jorm_stats] = j.get_node_stats if j.is_connected?
  my[:jorm_settings] = j.get_settings if j.is_connected?
  my[:network_info] = w.network_information if w.is_connected?
  my[:network_params] = w.network_parameters("latest") if w.is_connected?
  handle_api_err my[:network_info], session
  erb :network_stats, :locals => { :my => my }

end

# JORMUNGANDR

get "/jorm-stats" do
  j = Jormungandr.new session[:jorm_port]
  session[:jorm_stats] = j.get_node_stats
  session[:jorm_settings] = j.get_settings
  erb :jorm_stats, { :locals => session }
end
