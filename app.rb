require 'sinatra'
require 'bip_mnemonic'
require 'chartkick'
require 'cardano_wallet'
require 'sys/proctable'
require 'json2table'

require_relative 'helpers/app_helpers'
require_relative 'helpers/discovery_helpers'
require_relative './models/jormungandr'

ENV['ICARUS_PORT'] ||= '4444'
ENV['ICARUS_BIND_ADDR'] ||= '0.0.0.0'

set :port, ENV['ICARUS_PORT'].to_i
set :bind, ENV['ICARUS_BIND_ADDR']
set :root, File.dirname(__FILE__)

# enable :sessions
use Rack::Session::Pool
helpers Helpers::App
helpers Helpers::Discovery


before do
  @timeout = 600
  session[:opt] ||= {port: 8090, timeout: @timeout}
  @cw ||= CardanoWallet.new session[:opt]
  session[:opt] ||= @cw.opt
  session[:platform] ||= os
  # puts session[:opt]
end

get "/" do
  erb :index
end

post "/connect" do
  begin
    @cw = CardanoWallet.new({ port: params[:wallet_port].to_i,
                              protocol: params[:protocol],
                              cacert: params[:cacert],
                              pem: params[:pem],
                              timeout: @timeout })
  rescue
    session[:error] = "Failed to initialize CardanoWallet! (Hint: Make sure Cacert and Pem point to real files)."
  end
  session[:opt] = @cw.opt
  session[:w_connected] = is_connected? @cw
  redirect "/"
end

get "/discovery" do
  wallet_servers = Sys::ProcTable.ps.select{|p| p.cmdline.include?("cardano-wallet") if p.cmdline}
  erb :discovery, { :locals => { :wallet_servers => wallet_servers } }
end


# MISC

get "/get-pub-key" do
  wallets = @cw.shelley.wallets.list
  handle_api_err wallets, session
  params[:wid] ? wid = params[:wid] : wid = wallets.first['id']
  erb :form_get_public_key, { :locals => { :wallets => wallets,
                                          :wid => wid,
                                          :role => params[:role],
                                          :index => params[:index],
                                          :pub_key => nil
                                        } }
end

post "/get-pub-key" do
  wallets = @cw.shelley.wallets.list
  handle_api_err wallets, session

  begin
    pub_key = @cw.shelley.keys.get_public_key(params[:wid],
                                            params[:role],
                                            params[:index])
  rescue
    session[:error] = "Make sure parameters are valid. "
    redirect "/get-pub-key"
  end
  handle_api_err pub_key, session
  erb :form_get_public_key, { :locals => { :wallets => wallets,
                                          :wid => params[:wid],
                                          :role => params[:role],
                                          :index => params[:index],
                                          :pub_key => pub_key
                                        } }
end

get "/sign-metadata" do
  wallets = @cw.shelley.wallets.list
  handle_api_err wallets, session
  params[:wid] ? wid = params[:wid] : wid = wallets.first['id']
  erb :form_sign_metadata, { :locals => { :wallets => wallets,
                                          :wid => wid,
                                          :role => params[:role],
                                          :index => params[:index],
                                          :pass => params[:pass],
                                          :metadata => params[:metadata],
                                          :signed_metadata => nil
                                        } }
end

post "/sign-metadata" do
  wallets = @cw.shelley.wallets.list
  handle_api_err wallets, session
  m = parse_metadata(params[:metadata])

  begin
    signed_metadata = @cw.shelley.keys.sign_metadata(params[:wid],
                                                   params[:role],
                                                   params[:index],
                                                   params[:pass],
                                                   m
                                                  )
  rescue
    session[:error] = "Make sure parameters are valid. "
    redirect "/sign-metadata"
  end
  handle_api_err signed_metadata, session
  erb :form_sign_metadata, { :locals => { :wallets => wallets,
                                          :wid => params[:wid],
                                          :role => params[:role],
                                          :index => params[:index],
                                          :pass => params[:pass],
                                          :metadata => m,
                                          :signed_metadata => signed_metadata
                                        } }
end

get "/settings" do
  settings = @cw.misc.settings.get
  erb :form_settings, { :locals => { :settings => settings,
                                     :pool_strategy => nil } }
end

post "/settings" do
  set = { "pool_metadata_source" => params['pool_strategy'] }
  r = @cw.misc.settings.update(set)
  handle_api_err r, session
  settings = @cw.misc.settings.get
  erb :form_settings, { :locals => { :settings => settings,
                                     :pool_strategy => params['pool_strategy'] } }
end

get "/network-params" do
  r = @cw.misc.network.parameters
  handle_api_err r, session
  erb :network_params, :locals => { :network_params => r }
end

get "/network-info" do
  r = @cw.misc.network.information
  handle_api_err r, session
  erb :network_info, :locals => { :network_info => r }
end

get "/network-clock" do
  r = @cw.misc.network.clock
  handle_api_err r, session
  erb :network_clock, :locals => { :network_clock => r }
end

get "/inspect-address" do
  erb :form_inspect_address, { :locals => { :address_details => nil, :id => nil } }
end

get "/inspect-address-now" do
  address_details = @cw.misc.utils.addresses(params[:addr_id])
  erb :form_inspect_address, { :locals => { :address_details => address_details,
                                            :id => params[:addr_id]} }
end

get "/construct-address" do
  erb :form_construct_address, { :locals => { :script => nil, :address => nil } }
end

post "/construct-address" do
  begin
    script = JSON.parse params[:script]
    address = @cw.misc.utils.post_address(script)
  rescue
    session[:error] = "Make sure the 'script' has correct JSON format."
  end
  erb :form_construct_address, { :locals => { :script => params[:script],
                                              :address => address} }
end

get "/submit-external-tx" do
  erb :form_tx_external, { :locals => { :tx => nil, :blob => nil } }
end

post "/submit-external-tx" do
  tx = @cw.misc.proxy.submit_external_transaction(params['blob'].strip)
  # handle_api_err tx, session
  erb :form_tx_external, { :locals => { :tx => tx, :blob => params['blob'] } }
end

# SHELLEY WALLETS

get "/wallets/coin-selection/delegation" do
  wallets = @cw.shelley.wallets.list
  handle_api_err wallets, session
  erb :form_coin_selection_deleg_action, { :locals => { :deleg_action => nil,
                                                        :coin_selection => nil,
                                                        :wallets => wallets } }
end

post "/wallets/coin-selection/delegation" do
  wallets = @cw.shelley.wallets.list
  handle_api_err wallets, session
  begin
    deleg_action = JSON.parse params[:deleg_action]
    coin_selection = @cw.shelley.coin_selections.random_deleg(params[:wid], deleg_action)
    # handle_api_err coin_selection, session
  rescue
    session[:error] = "Make sure the 'action' has correct JSON format."
  end
  erb :form_coin_selection_deleg_action, { :locals => { :deleg_action => params[:deleg_action],
                                                        :coin_selection => coin_selection,
                                                        :wallets => wallets } }
end

get "/wallets/coin-selection/random" do
  wallets = @cw.shelley.wallets.list
  handle_api_err wallets, session
  erb :form_coin_selection, { :locals => { :addr_amt => nil,
                                           :coin_selection => nil,
                                           :wallets => wallets } }
end

post "/wallets/coin-selection/random" do
  wallets = @cw.shelley.wallets.list
  handle_api_err wallets, session
  begin
    address_amount = params[:addr_amt].split("\n").map{|a| a.strip.split(":")}.collect{|a| {a.first.strip => a.last.strip}}
    coin_selection = @cw.shelley.coin_selections.random(params[:wid], address_amount)
  rescue ArgumentError
    session[:error] = "Make sure the input is in the form of address:amount per line."
  end
  erb :form_coin_selection, { :locals => { :addr_amt => params[:addr_amt],
                                           :coin_selection => coin_selection,
                                           :wallets => wallets } }
end

get "/wallets" do
  wallets = @cw.shelley.wallets.list
  handle_api_err wallets, session
  erb :wallets, { :locals => { :wallets => wallets } }
end

get "/wallets/:wal_id" do
  wal = @cw.shelley.wallets.get params[:wal_id]
  handle_api_err wal, session
  txs = @cw.shelley.transactions.list params[:wal_id]
  handle_api_err txs, session
  addrs = @cw.shelley.addresses.list params[:wal_id]
  handle_api_err addrs, session

  erb :wallet, { :locals => { :wal => wal, :txs => txs, :addrs => addrs} }
end

get "/wallets/:wal_id/update" do
  wal = @cw.shelley.wallets.get params[:wal_id]
  handle_api_err wal, session
  erb :form_wallet_update, { :locals => { :wal => wal } }
end

post "/wallets/:wal_id/update" do
  r = @cw.shelley.wallets.update_metadata(params[:wal_id], {name: params[:name]})
  handle_api_err r, session
  redirect "/wallets/#{params[:wal_id]}"
end

get "/wallets/:wal_id/update-pass" do
  wal = @cw.shelley.wallets.get params[:wal_id]
  handle_api_err wal, session
  erb :form_wallet_update_pass, { :locals => { :wal => wal } }
end

post "/wallets/:wal_id/update-pass" do
  r = @cw.shelley.wallets.update_passphrase(params[:wal_id],
                                          {old_passphrase: params[:old_pass],
                                           new_passphrase: params[:new_pass]})
  handle_api_err r, session
  redirect "/wallets/#{params[:wal_id]}"
end

get "/wallets-delete/:wal_id" do
  @cw.shelley.wallets.delete params[:wal_id]
  redirect "/wallets"
end

get "/wallets-create" do
  # 15-word mnemonics
  bits = bits_from_word_count '15'
  mnemonics = BipMnemonic.to_mnemonic(bits: bits, language: 'english')
  erb :form_create_wallet, { :locals => { :mnemonics => mnemonics} }
end

post "/wallets-create" do
  m = prepare_mnemonics params[:mnemonics]
  pass = params[:pass]
  name = params[:wal_name]
  pool_gap = params[:pool_gap].to_i

  wal = @cw.shelley.wallets.create({mnemonic_sentence: m,
                                  passphrase: pass,
                                  name: name,
                                  address_pool_gap: pool_gap})
  handle_api_err wal, session
  session[:wal] = wal
  handle_api_err wal, session

  redirect "/wallets/#{wal['id']}"
end

get "/wallets-create-from-pub-key" do
  # 15-word mnemonics
  erb :form_create_wallet_from_pub_key
end

post "/wallets-create-from-pub-key" do
  pub_key = params[:pub_key]
  name = params[:wal_name]
  pool_gap = params[:pool_gap].to_i
  wal = @cw.shelley.wallets.create({name: name,
                                    account_public_key: pub_key,
                                    address_pool_gap: pool_gap,
                                    })
  handle_api_err wal, session

  redirect "/wallets/#{wal['id']}"
end

get "/wallets-create-many-from-mnemonics" do
  erb :form_create_many_from_mnemonics
end

post "/wallets-create-many-from-mnemonics" do
  pass = params[:pass]
  name = params[:wal_name]
  pool_gap = params[:pool_gap].to_i
  mnemonics_array = params[:mnemonics].split("\n").map{|a| a.strip}
  mnemonics_array.each_with_index do |m,i|
    wal = @cw.shelley.wallets.create({mnemonic_sentence: m.split,
                                      passphrase: pass,
                                      name: "#{name} #{i + 1}",
                                      address_pool_gap: pool_gap})
    handle_api_err wal, session
  end
  redirect "/wallets"
end

get "/wallets-create-many" do
  erb :form_create_many
end

post "/wallets-create-many" do
  pass = params[:pass]
  name = params[:wal_name]
  pool_gap = params[:pool_gap].to_i
  how_many = params[:how_many].to_i
  bits = bits_from_word_count params[:words_count]

  1.upto how_many do |i|
    mnemonics = BipMnemonic.to_mnemonic(bits: bits, language: 'english').split
    wal = @cw.shelley.wallets.create({mnemonic_sentence: mnemonics,
                                      passphrase: pass,
                                      name: "#{name} #{i}",
                                      address_pool_gap: pool_gap})
    handle_api_err wal, session
  end
  redirect "/wallets"
end

get "/wallets-delete-all" do
  erb :form_del_all
end

post "/wallets-delete-all" do
  s = @cw.shelley.wallets.list
  handle_api_err s, session
  s.each do |wal|
    r = @cw.shelley.wallets.delete wal['id']
    handle_api_err r, session
  end
  redirect "/wallets"
end

get "/wallets-utxo" do
  utxo = @cw.shelley.wallets.utxo params[:wid]
  wal = @cw.shelley.wallets.get params[:wid]
  wallets = @cw.shelley.wallets.list

  erb :utxo_details, { :locals => { :wal => wal,
                                    :utxo => utxo,
                                    :wallets => wallets } }
end

get "/wallets-migrate" do
  wallets = @cw.shelley.wallets.list
  handle_api_err(wallets, session)

  erb :form_migrate, { :locals => { :wallets => wallets} }
end

post "/wallets-migrate" do
  wid_src = params[:wid_src]
  addresses = params[:addresses].split("\n").map{|a| a.strip}
  pass = params[:pass]

  r = @cw.shelley.migrations.migrate(wid_src, pass, addresses)
  handle_api_err(r, session)

  erb :show_migrated, { :locals => { transactions: r, wid_src: wid_src} }
end

get "/wallets-migration-fee" do
  wid = params[:wid]
  wallets = @cw.shelley.wallets.list
  r = @cw.shelley.migrations.cost wid

  erb :show_migration_fee, { :locals => { :migration_fee => r,
                                          :wid => wid,
                                          :wallets => wallets } }
end

# TRANSACTIONS SHELLEY
get "/rewards" do
  wid = params[:wid]
  min_withdrawal = params[:minWithdrawal]
  r = @cw.shelley.transactions.list(wid, {minWithdrawal: min_withdrawal})
  handle_api_err r, session
  # w = @cw.shelley.wallets.get wid
  # handle_api_err w, session

  erb :rewards, { :locals => { :wid => wid, :transactions => r } }
end

get "/tx-fee-to-address" do
  wallets = @cw.shelley.wallets.list
  erb :form_tx_fee_to_address, { :locals => { :wallets => wallets } }
end

get "/tx-fee-to-multi-address" do
  wallets = @cw.shelley.wallets.list
  erb :form_tx_fee_to_multi_address, { :locals => { :wallets => wallets } }
end

post "/tx-fee-to-address" do
  wid_src = params[:wid_src]

  if params[:addr_amt]
    payload = parse_addr_amt(params[:addr_amt])
  else
    amount = params[:amount]
    address = params[:address]
    payload = [{address => amount}]
  end

  case params[:withdrawal]
  when ''
    w = nil
  when 'self'
    w = 'self'
  else
    w = params[:withdrawal].split
  end
  params[:ttl] == '' ? ttl = nil : ttl = params[:ttl].to_i

  m = parse_metadata(params[:metadata])

  r = @cw.shelley.transactions.payment_fees(wid_src, payload, w, m, ttl)
  handle_api_err r, session

  erb :show_tx_fee, { :locals => { :tx_fee => r, :wallet_id => wid_src} }
end

get "/tx-to-multi-address" do
  wallets = @cw.shelley.wallets.list
  erb :form_tx_to_multi_address, { :locals => { :wallets => wallets } }
end

get "/tx-to-address" do
  wallets = @cw.shelley.wallets.list
  erb :form_tx_to_address, { :locals => { :wallets => wallets } }
end

post "/tx-to-address" do
  wid_src = params[:wid_src]
  pass = params[:pass]

  if params[:addr_amt]
    payload = parse_addr_amt(params[:addr_amt])
  else
    amount = params[:amount]
    address = params[:address]
    payload = [{address => amount}]
  end

  case params[:withdrawal]
  when ''
    w = nil
  when 'self'
    w = 'self'
  else
    w = params[:withdrawal].split
  end
  m = parse_metadata(params[:metadata])
  params[:ttl] == '' ? ttl = nil : ttl = params[:ttl].to_i

  r = @cw.shelley.transactions.create(wid_src,
                                      pass,
                                      payload,
                                      w, m, ttl)
  handle_api_err r, session

  redirect "/wallets/#{wid_src}/txs/#{r['id']}"
end

get "/tx-between-wallets" do
  wallets = @cw.shelley.wallets.list
  erb :form_tx_between_wallets, { :locals => { :wallets => wallets } }
end

post "/tx-between-wallets" do
  wid_src = params[:wid_src]
  wid_dst = params[:wid_dst]
  pass = params[:pass]
  amount = params[:amount]
  case params[:withdrawal]
  when ''
    w = nil
  when 'self'
    w = 'self'
  else
    w = params[:withdrawal].split
  end
  m = parse_metadata(params[:metadata])
  params[:ttl] == '' ? ttl = nil : ttl = params[:ttl].to_i

  address_dst = @cw.shelley.addresses.list(wid_dst,
                                          {state: "unused"}).
                                          sample['id']
  r = @cw.shelley.transactions.create(wid_src,
                                      pass,
                                      [{address_dst => amount}],
                                      w, m, ttl)
  handle_api_err r, session

  redirect "/wallets/#{wid_src}/txs/#{r['id']}"
end

get "/wallets/:wal_id/forget-tx/:tx_to_forget_id" do
  id = params[:wal_id]
  txid = params[:tx_to_forget_id]
  r = @cw.shelley.transactions.forget(id, txid)
  handle_api_err r, session
  session[:tx_forgotten] = "Transaction #{id} was forgotten."
  redirect "/wallets/#{id}"
end

# show tx details
get "/wallets/:wal_id/txs/:tx_id" do
  wid = params[:wal_id]
  txid = params[:tx_id]
  tx = @cw.shelley.transactions.get(wid, txid)
  erb :tx_details, { :locals => { :tx => tx, :wid => wid }  }
end

# BYRON WALLETS

get "/byron-wallets/coin-selection/random" do
  wallets = @cw.byron.wallets.list
  handle_api_err wallets, session
  erb :form_coin_selection, { :locals => { :addr_amt => nil,
                                           :coin_selection => nil,
                                           :wallets => wallets } }
end

post "/byron-wallets/coin-selection/random" do
  wallets = @cw.byron.wallets.list
  handle_api_err wallets, session
  begin
    address_amount = parse_addr_amt(params[:addr_amt])
    coin_selection = @cw.byron.coin_selections.random(params[:wid], address_amount)
  rescue ArgumentError
    session[:error] = "Make sure the input is in the form of address:amount per line."
  end
  erb :form_coin_selection, { :locals => { :addr_amt => params[:addr_amt],
                                           :coin_selection => coin_selection,
                                           :wallets => wallets } }
end

get "/byron-wallets/:wal_id/bulk-address-import" do
  erb :form_byron_wallet_address_bulk_import, { :locals => { :wid => params[:wal_id] } }
end

post "/byron-wallets/:wal_id/bulk-address-import" do
  addresses = params[:addresses].split("\n").map{|a| a.strip}
  r = @cw.byron.addresses.bulk_import params[:wal_id], addresses
  handle_api_err r, session
  redirect "/byron-wallets/#{params[:wal_id]}"
end

get "/byron-wallets/:wal_id/address-import" do
  erb :form_byron_wallet_address_import, { :locals => { :wid => params[:wal_id] } }
end

post "/byron-wallets/:wal_id/address-import" do
  r = @cw.byron.addresses.import params[:wal_id], params[:address]
  handle_api_err r, session
  redirect "/byron-wallets/#{params[:wal_id]}"
end

get "/byron-wallets/:wal_id/address" do
  erb :form_byron_wallet_address, { :locals => { :wid => params[:wal_id] } }
end

post "/byron-wallets/:wal_id/address" do
  r = @cw.byron.addresses.create(params[:wal_id],
                                {passphrase: params[:pass],
                                 address_index: params[:idx].to_i})
  handle_api_err r, session
  redirect "/byron-wallets/#{params[:wal_id]}"
end

get "/byron-wallets/:wal_id/update" do
  wal = @cw.byron.wallets.get params[:wal_id]
  handle_api_err wal, session
  erb :form_wallet_update, { :locals => { :wal => wal } }
end

post "/byron-wallets/:wal_id/update" do
  r = @cw.byron.wallets.update_metadata(params[:wal_id], {name: params[:name]})
  handle_api_err r, session
  redirect "/byron-wallets/#{params[:wal_id]}"
end

get "/byron-wallets/:wal_id/update-pass" do
  wal = @cw.byron.wallets.get params[:wal_id]
  handle_api_err wal, session
  erb :form_wallet_update_pass, { :locals => { :wal => wal } }
end

post "/byron-wallets/:wal_id/update-pass" do
  r = @cw.byron.wallets.update_passphrase(params[:wal_id],
                                          {old_passphrase: params[:old_pass],
                                           new_passphrase: params[:new_pass]})
  handle_api_err r, session
  redirect "/byron-wallets/#{params[:wal_id]}"
end

get "/byron-wallets-utxo" do
  utxo = @cw.byron.wallets.utxo params[:wid]
  wal = @cw.byron.wallets.get params[:wid]
  wallets = @cw.byron.wallets.list

  handle_api_err utxo, session
  handle_api_err wal, session
  erb :utxo_details, { :locals => { :wal => wal,
                                    :utxo => utxo,
                                    :wallets => wallets } }
end

get "/byron-wallets" do
  wallets = @cw.byron.wallets.list
  handle_api_err wallets, session
  erb :wallets, { :locals => { :wallets => wallets } }
end

get "/byron-wallets/:wal_id" do
  wallet = @cw.byron.wallets.get params[:wal_id]
  txs = @cw.byron.transactions.list params[:wal_id]
  handle_api_err wallet, session
  handle_api_err txs, session
  addrs = @cw.byron.addresses.list params[:wal_id]
  # Addresses for byron not implemented in Shelley
  # Therefore workaround not to raise error
  if addrs.code != 200
    addrs = nil
  else
    handle_api_err addrs, session
  end

  erb :wallet, { :locals => {:wal => wallet, :txs => txs, :addrs => addrs} }
end

get "/byron-wallets-delete/:wal_id" do
  d = @cw.byron.wallets.delete params[:wal_id]
  handle_api_err d, session

  redirect "/byron-wallets"
end

get "/byron-wallets-create" do
  # 12-word mnemonics
  bits = bits_from_word_count '12'
  mnemonics = BipMnemonic.to_mnemonic(bits: bits, language: 'english')
  erb :form_create_wallet, { :locals => { :mnemonics => mnemonics} }
end

post "/byron-wallets-create" do
  m = prepare_mnemonics params[:mnemonics]
  pass = params[:pass]
  name = params[:wal_name]
  style = params[:style]

  wal = @cw.byron.wallets.create({name: "#{name} (#{style})",
                                  style: style,
                                  passphrase: pass,
                                  mnemonic_sentence: m})
  handle_api_err wal, session

  redirect "/byron-wallets/#{wal['id']}"
end

get "/byron-wallets-create-many-from-mnemonics" do
  erb :form_create_many_from_mnemonics
end

post "/byron-wallets-create-many-from-mnemonics" do
  pass = params[:pass]
  name = params[:wal_name]
  style = params[:style]
  mnemonics_array = params[:mnemonics].split("\n").map{|a| a.strip}
  mnemonics_array.each_with_index do |m,i|
    wal = @cw.byron.wallets.create({name: "#{name} (#{style}) #{i + 1}",
                                    style: style,
                                    passphrase: pass,
                                    mnemonic_sentence: m.split})
    handle_api_err wal, session
  end
  redirect "/byron-wallets"
end

get "/byron-wallets-create-many" do
  erb :form_create_many
end

post "/byron-wallets-create-many" do
  pass = params[:pass]
  name = params[:wal_name]
  how_many = params[:how_many].to_i
  style = params[:style]
  bits = bits_from_word_count params[:words_count]

  1.upto how_many do |i|
    mnemonics = BipMnemonic.to_mnemonic(bits: bits, language: 'english').split
    wal = @cw.byron.wallets.create({name: "#{name} (#{style}) #{i}",
                                    style: style,
                                    passphrase: pass,
                                    mnemonic_sentence: mnemonics})
    handle_api_err wal, session
  end
  redirect "/byron-wallets"
end

get "/byron-wallets-delete-all" do
  erb :form_del_all
end

post "/byron-wallets-delete-all" do
  b = @cw.byron.wallets.list
  handle_api_err b, session
  b.each do |wal|
    r = @cw.byron.wallets.delete wal['id']
    handle_api_err r, session
  end
  redirect "/byron-wallets"
end

get "/byron-wallets-migrate" do
  wallets = @cw.byron.wallets.list
  handle_api_err(wallets, session)

  erb :form_migrate, { :locals => { :wallets => wallets} }
end

post "/byron-wallets-migrate" do
  wid_src = params[:wid_src]
  addresses = params[:addresses].split("\n").map{|a| a.strip}
  pass = params[:pass]

  r = @cw.byron.migrations.migrate(wid_src, pass, addresses)
  handle_api_err(r, session)

  erb :show_migrated, { :locals => { transactions: r, wid_src: wid_src} }
end

get "/byron-wallets-migration-fee" do
  wid = params[:wid]
  wallets = @cw.byron.wallets.list
  r = @cw.byron.migrations.cost wid

  erb :show_migration_fee, { :locals => { :migration_fee => r,
                                          :wid => wid,
                                          :wallets => wallets } }
end

# TRANSACTIONS BYRON

get "/byron-wallets/:wal_id/txs/:tx_id" do
  wid = params[:wal_id]
  tx = @cw.byron.transactions.get(params[:wal_id], params[:tx_id])
  erb :tx_details, { :locals => { :tx => tx, :wid => wid }  }
end

get "/byron-wallets/:wal_id/forget-tx/:tx_to_forget_id" do
  id = params[:wal_id]
  txid = params[:tx_to_forget_id]
  r = @cw.byron.transactions.forget id, txid
  handle_api_err r, session
  session[:tx_forgotten] = "Transaction #{id} was forgotten."
  redirect "/byron-wallets/#{id}"
end

get "/byron-tx-fee-to-address" do
  wallets = @cw.byron.wallets.list
  erb :form_tx_fee_to_address, { :locals => { :wallets => wallets } }
end

post "/byron-tx-fee-to-address" do
  wid_src = params[:wid_src]
  amount = params[:amount]
  address = params[:address]

  r = @cw.byron.transactions.payment_fees(wid_src, [{address => amount}])
  handle_api_err r, session

  erb :show_tx_fee, { :locals => { :tx_fee => r, :wallet_id => wid_src} }
end

get "/byron-tx-to-address" do
  wallets = @cw.byron.wallets.list
  erb :form_tx_to_address, { :locals => { :wallets => wallets } }
end

post "/byron-tx-to-address" do
  wid_src = params[:wid_src]
  pass = params[:pass]
  amount = params[:amount]
  address = params[:address]

  r = @cw.byron.transactions.create(wid_src, pass, [{address => amount}])
  handle_api_err r, session

  redirect "/byron-wallets/#{wid_src}/txs/#{r['id']}"
end

# MNEMONICS

get "/gen-mnemonics" do
  erb :form_gen_mnemonics, { :locals => {:mnemonics => nil,
                                         :words_count => nil } }
end

post "/gen-mnemonics" do
  bits = bits_from_word_count params[:words_count]
  words_count = params[:words_count]
  mnemonics = BipMnemonic.to_mnemonic(bits: bits, language: 'english')
  erb :form_gen_mnemonics, { :locals => {:mnemonics => mnemonics,
                                         :words_count => words_count } }
end

# STAKE-POOLS

get "/stake-pools-list-wid/:wid" do
  w = @cw.shelley.wallets.get(params[:wid])
  handle_api_err w, session
  balance = w['balance']['available']['quantity']
  redirect "/stake-pools-list?stake=#{balance}"
end

get "/stake-pools-list" do
  stake_pools = @cw.shelley.stake_pools.list({stake: params[:stake]})
  handle_api_err stake_pools, session
  view_action = @cw.shelley.stake_pools.view_maintenance_actions
  handle_api_err view_action, session
  settings = @cw.misc.settings.get
  handle_api_err settings, session
  erb :stake_pools, { :locals => { :stake_pools => stake_pools,
                                   :last_gc => view_action['gc_stake_pools'],
                                   :metadata_source => settings['pool_metadata_source']
                                 } }
end

get "/stake-pools-maintenance" do
  last_gc = @cw.shelley.stake_pools.view_maintenance_actions
  handle_api_err last_gc, session
  erb :form_maintenance_actions, { :locals => { :action => nil,
                                                :last_gc => last_gc
                                 } }
end

post "/stake-pools-maintenance" do
  a = @cw.shelley.stake_pools.trigger_maintenance_actions({ maintenance_action: params[:action] })
  handle_api_err a, session
  last_gc = @cw.shelley.stake_pools.view_maintenance_actions
  handle_api_err last_gc, session
  erb :form_maintenance_actions, { :locals => { :action => params[:action],
                                                :last_gc => last_gc
                                 } }
end

get "/stake-pools-join" do
  if params[:wid]
    w = @cw.shelley.wallets.get(params[:wid])
    handle_api_err w, session
    balance = w['balance']['available']['quantity']
  else
    balance = 1
  end
  stake_pools = @cw.shelley.stake_pools.list({stake: balance})
  handle_api_err stake_pools, session
  wallets = @cw.shelley.wallets.list
  handle_api_err wallets, session
  erb :form_join_quit_sp, { :locals => { :wallets => wallets,
                                         :stake_pools => stake_pools } }
end

post "/stake-pools-join" do
  sp_id = params['spid']
  w_id = params['wid']
  pass = params['pass']
  r = @cw.shelley.stake_pools.join(sp_id, w_id, pass)
  handle_api_err r, session
  redirect "/wallets/#{w_id}/txs/#{r['id']}"
end

get "/stake-pools-quit" do
  wallets = @cw.shelley.wallets.list
  handle_api_err wallets, session
  erb :form_join_quit_sp, { :locals => { :wallets => wallets,
                                         :stake_pools => nil} }
end

post "/stake-pools-quit" do
  w_id = params['wid']
  pass = params['pass']
  r = @cw.shelley.stake_pools.quit(w_id, pass)
  handle_api_err r, session
  redirect "/wallets/#{w_id}/txs/#{r['id']}"
end

get "/stake-pools-fee" do
  wid = params['wid']
  r = @cw.shelley.stake_pools.delegation_fees wid if wid
  wallets = @cw.shelley.wallets.list

  erb :show_delegation_fee, { :locals => { :delegation_fee => r,
                                           :wid => wid,
                                           :wallets => wallets } }
end

# JORMUNGANDR

post "/connect-jorm" do
  session[:jorm_port] = params["jorm_port"]
  j = Jormungandr.new session[:jorm_port]
  session[:j_connected] = j.is_connected?
  redirect "/wallet-jorm-stats"
end

get "/wallet-jorm-stats" do
  session[:jorm_port] ||= "8080"

  j = Jormungandr.new session[:jorm_port]
  session[:j_connected] = j.is_connected?

  my = Hash.new
  my[:jorm_stats] = j.get_node_stats if j.is_connected?
  my[:jorm_settings] = j.get_settings if j.is_connected?
  my[:network_info] = @cw.misc.network.information if is_connected?(@cw)
  my[:network_params] = @cw.misc.network.parameters if is_connected?(@cw)

  erb :wallet_jorm_stats, :locals => { :my => my }

end
