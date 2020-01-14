require 'sinatra'
require 'bip_mnemonic'
require 'chartkick'

require_relative './models/wallet_backend'
require_relative './models/jormungandr'

set :port, 4444
set :bind, '0.0.0.0'
set :root, File.dirname(__FILE__)

# enable :sessions
use Rack::Session::Pool

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
    j = JSON.parse r.to_s
    session[:error] = "Something went wrong! 
                       Wallet backend responded with: 
                       #{j}"
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
  session[:wallets] = r
  erb :wallets, { :locals => session }  
end

get "/wallets/:wal_id" do
  w = NewWalletBackend.new session[:wallet_port]
  session[:wal] = w.wallet params[:wal_id]
  session[:txs] = w.transactions params[:wal_id]
  session[:addrs] = w.addresses params[:wal_id]
  session[:delegation_fee] = w.fee_stake_pools params[:wal_id]
  erb :wallet, { :locals => session }  
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

get "/wallets-create-many" do
  erb :form_create_many, { :locals => session } 
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
  session[:utxo] = w.get_utxo params[:wal_id]
  session[:wal] = w.wallet params[:wal_id]
  erb :utxo_details, { :locals => session }
end

# TRANSACTIONS SHELLEY

get "/tx-to-address" do
  w = NewWalletBackend.new session[:wallet_port]
  session[:wallets] = w.wallets
  erb :form_tx_to_address, { :locals => session }
end

post "/tx-to-address" do
  wid_src = params[:wid_src]
  pass = params[:pass]
  amount = params[:amount]
  address = params[:address]
  
  w = NewWalletBackend.new session[:wallet_port]
  r = w.create_transaction(amount, address, pass, wid_src)
  handle_api_err r, session
  
  session[:tx] = r
  session[:wid] = wid_src
  redirect "/wallets/#{wid_src}/txs/#{r['id']}"
end

get "/tx-between-wallets" do
  w = NewWalletBackend.new session[:wallet_port]
  session[:wallets] = w.wallets
  erb :form_tx_between_wallets, { :locals => session }
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
  
  session[:tx] = r
  session[:wid] = wid_src
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

get "/byron-wallets" do
  w = NewWalletBackend.new session[:wallet_port]
  session[:wallets] = w.byron_wallets
  erb :wallets, { :locals => session }  
end

get "/byron-wallets/:wal_id" do
  w = NewWalletBackend.new session[:wallet_port], params[:wal_id]
  session[:wal] = w.byron_wallet params[:wal_id]
  session[:txs] = w.byron_transactions params[:wal_id]
  
  erb :wallet, { :locals => session }  
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
  session[:wal] = w.byron_wallet wal['id'] if wal['id']
  handle_api_err wal, session

  erb :wallet, { :locals => session }   
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
  session[:wallets] = w.wallets
  session[:byron_wallets] = w.byron_wallets
  erb :form_migrate_byron, { :locals => session }
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

# MISC 

get "/network-info" do
  w = NewWalletBackend.new session[:wallet_port]
  r = w.network_information
  handle_api_err r, session
  session[:network_info] = r
  erb :network_info, {:locals => session}
end

get "/network-stats" do
  j = Jormungandr.new session[:jorm_port]
  w = NewWalletBackend.new session[:wallet_port]
  
  session[:jorm_stats] = j.get_node_stats if j.is_connected?
  session[:jorm_settings] = j.get_settings if j.is_connected?
  session[:network_info] = w.network_information if w.is_connected?
  handle_api_err session[:network_info], session
  erb :network_stats, {:locals => session}
  
end

# JORMUNGANDR

get "/jorm-stats" do
  j = Jormungandr.new session[:jorm_port]
  session[:jorm_stats] = j.get_node_stats
  session[:jorm_settings] = j.get_settings
  erb :jorm_stats, { :locals => session }
end
