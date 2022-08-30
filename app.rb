require 'base64'
require 'sinatra'
require 'chartkick'
require 'cardano_wallet'
require 'sys/proctable'
require 'json2table'

require_relative 'helpers/app_helpers'
require_relative 'helpers/discovery_helpers'

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
  @timeout = 3600
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
get "/get-acc-pub-key" do
  wallets = @cw.shelley.wallets.list
  handle_api_err wallets, session
  wid = params[:wid]

  erb :form_get_acc_public_key, { :locals => { :wallets => wallets,
                                          :wid => wid,
                                          :format => params[:format],
                                          :acc_pub_key => nil
                                        } }
end

post "/get-acc-pub-key" do
  wallets = @cw.shelley.wallets.list
  handle_api_err wallets, session
  acc_pub_key = @cw.shelley.keys.get_acc_public_key(params[:wid], {format: params[:format]})
  handle_api_err acc_pub_key, session
  erb :form_get_acc_public_key, { :locals => { :wallets => wallets,
                                          :wid => params[:wid],
                                          :format => params[:format],
                                          :acc_pub_key => acc_pub_key
                                        } }
end

get "/create-acc-pub-key" do
  wallets = @cw.shelley.wallets.list
  handle_api_err wallets, session
  params[:wid] ? wid = params[:wid] : wid = wallets.first['id']
  erb :form_create_acc_public_key, { :locals => { :wallets => wallets,
                                          :wid => wid,
                                          :index => params[:index],
                                          :purpose => params[:purpose],
                                          :format => params[:format],
                                          :acc_pub_key => nil
                                        } }
end

post "/create-acc-pub-key" do
  wallets = @cw.shelley.wallets.list
  handle_api_err wallets, session
  begin
    payload = { "passphrase" => params[:pass],
                "format" => params[:format]}
    payload["purpose"] = params[:purpose] if params[:purpose] != ''
    acc_pub_key = @cw.shelley.keys.create_acc_public_key(params[:wid],
                                            params[:index],
                                            payload)
  rescue
    session[:error] = "Make sure parameters are valid. "
    redirect "/get-pub-key"
  end
  handle_api_err acc_pub_key, session
  erb :form_create_acc_public_key, { :locals => { :wallets => wallets,
                                          :wid => params[:wid],
                                          :index => params[:index],
                                          :purpose => params[:purpose],
                                          :format => params[:format],
                                          :acc_pub_key => acc_pub_key
                                        } }
end

get "/get-pub-key" do
  wallets = @cw.shelley.wallets.list
  handle_api_err wallets, session
  params[:wid] ? wid = params[:wid] : wid = wallets.first['id']
  erb :form_get_public_key, { :locals => { :wallets => wallets,
                                          :wid => wid,
                                          :role => params[:role],
                                          :index => params[:index],
                                          :pub_key => nil,
                                          :hash => nil
                                        } }
end

post "/get-pub-key" do
  wallets = @cw.shelley.wallets.list
  handle_api_err wallets, session
  hash = params[:hash] == 'true' ? { hash: true } : {}

  begin
    pub_key = @cw.shelley.keys.get_public_key(params[:wid],
                                            params[:role],
                                            params[:index],
                                            hash)
  rescue
    session[:error] = "Make sure parameters are valid. "
    redirect "/get-pub-key"
  end
  handle_api_err pub_key, session
  erb :form_get_public_key, { :locals => { :wallets => wallets,
                                          :wid => params[:wid],
                                          :role => params[:role],
                                          :index => params[:index],
                                          :pub_key => pub_key,
                                          :hash => params[:hash]
                                        } }
end

get "/get-policy-key" do
  wallets = @cw.shelley.wallets.list
  handle_api_err wallets, session
  params[:wid] ? wid = params[:wid] : wid = wallets.first['id']
  erb :form_get_policy_key, { :locals => { :wallets => wallets,
                                          :wid => wid,
                                          :policy_key => nil,
                                          :hash => nil } }
end

post "/get-policy-key" do
  wallets = @cw.shelley.wallets.list
  handle_api_err wallets, session
  hash = params[:hash] == 'true' ? { hash: true } : {}
  begin
    policy_key = @cw.shelley.keys.get_policy_key(params[:wid], hash)
  rescue
    session[:error] = "Make sure parameters are valid. "
    redirect "/get-policy-key"
  end
  handle_api_err policy_key, session
  erb :form_get_policy_key, { :locals => { :wallets => wallets,
                                          :wid => params[:wid],
                                          :policy_key => policy_key,
                                          :hash => params[:hash]
                                        } }
end

get "/create-policy-id" do
  wallets = @cw.shelley.wallets.list
  handle_api_err wallets, session
  params[:wid] ? wid = params[:wid] : wid = wallets.first['id']
  erb :form_create_policy_id, { :locals => { :wallets => wallets,
                                          :wid => wid,
                                          :policy_script_template => nil,
                                          :policy_id => nil } }
end

post "/create-policy-id" do
  wallets = @cw.shelley.wallets.list
  handle_api_err wallets, session
  begin
    policy_script_template = JSON.parse(params[:mint_policy_script].strip)
  rescue
    policy_script_template = params[:mint_policy_script]
  end
  policy_id = @cw.shelley.keys.create_policy_id(params[:wid], policy_script_template)
  handle_api_err policy_id, session
  erb :form_create_policy_id, { :locals => { :wallets => wallets,
                                          :wid => params[:wid],
                                          :policy_script_template => params[:mint_policy_script],
                                          :policy_id => policy_id } }
end

get "/create-policy-key" do
  wallets = @cw.shelley.wallets.list
  handle_api_err wallets, session
  params[:wid] ? wid = params[:wid] : wid = wallets.first['id']
  erb :form_create_policy_key, { :locals => { :wallets => wallets,
                                          :wid => wid,
                                          :pass => 'Secure Passphrase',
                                          :policy_key => nil,
                                          :hash => nil } }
end

post "/create-policy-key" do
  wallets = @cw.shelley.wallets.list
  handle_api_err wallets, session
  hash = params[:hash] == 'true' ? { hash: true } : {}
  begin
    policy_key = @cw.shelley.keys.create_policy_key(params[:wid], params[:pass], hash)
  rescue
    session[:error] = "Make sure parameters are valid. "
    redirect "/create-policy-key"
  end
  handle_api_err policy_key, session
  erb :form_create_policy_key, { :locals => { :wallets => wallets,
                                          :wid => params[:wid],
                                          :pass => params[:pass],
                                          :policy_key => policy_key,
                                          :hash => params[:hash] } }
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

get "/smash-health-check" do
  (params[:url] == '' or params[:url].nil?) ? q = {} : q = {url: params[:url]}
  health_check = @cw.misc.utils.smash_health(q)
  smash = @cw.misc.settings.get['pool_metadata_source']
  erb :form_smash_health_check, { :locals => { :health_check => health_check, :smash => smash } }
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

get "/block-header" do
  r = @cw.misc.node.block_header
  handle_api_err r, session
  erb :block_header, :locals => { :block_header => r }
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
  serialized_tx = Base64.decode64(params['blob'].strip)
  r = @cw.misc.proxy.submit_external_transaction(serialized_tx)
  handle_api_err r, session

  erb :form_tx_external, { :locals => { :tx => r, :blob => params['blob'].strip } }
end

# SHARED WALLETS
get "/shared-get-acc-pub-key" do
  wallets = @cw.shared.wallets.list
  handle_api_err wallets, session
  wid = params[:wid]

  erb :form_get_acc_public_key, { :locals => { :wallets => wallets,
                                          :wid => wid,
                                          :format => params[:format],
                                          :acc_pub_key => nil
                                        } }
end

post "/shared-get-acc-pub-key" do
  wallets = @cw.shared.wallets.list
  handle_api_err wallets, session
  acc_pub_key = @cw.shared.keys.get_acc_public_key(params[:wid], {format: params[:format]})
  handle_api_err acc_pub_key, session
  erb :form_get_acc_public_key, { :locals => { :wallets => wallets,
                                          :wid => params[:wid],
                                          :format => params[:format],
                                          :acc_pub_key => acc_pub_key
                                        } }
end

get "/shared-create-acc-pub-key" do
  wallets = @cw.shared.wallets.list
  handle_api_err wallets, session
  # params[:wid] ? wid = params[:wid] : wid = wallets.first['id']
  wid = params[:wid]

  erb :form_create_acc_public_key, { :locals => { :wallets => wallets,
                                          :wid => wid,
                                          :index => params[:index],
                                          :format => params[:format],
                                          :acc_pub_key => nil
                                        } }
end

post "/shared-create-acc-pub-key" do
  wallets = @cw.shared.wallets.list
  handle_api_err wallets, session
  begin
    payload = { "passphrase" => params[:pass],
                "format" => params[:format]}
    acc_pub_key = @cw.shared.keys.create_acc_public_key(params[:wid],
                                            params[:index],
                                            payload)
  rescue
    session[:error] = "Make sure parameters are valid. "
    redirect "/shared-create-acc-pub-key"
  end
  handle_api_err acc_pub_key, session
  erb :form_create_acc_public_key, { :locals => { :wallets => wallets,
                                          :wid => params[:wid],
                                          :index => params[:index],
                                          :format => params[:format],
                                          :acc_pub_key => acc_pub_key
                                        } }
end

get "/shared-get-pub-key" do
  wallets = @cw.shared.wallets.list
  handle_api_err wallets, session
  # params[:wid] ? wid = params[:wid] : wid = wallets.first['id']
  wid = params[:wid]
  erb :form_get_public_key, { :locals => { :wallets => wallets,
                                          :wid => wid,
                                          :role => params[:role],
                                          :index => params[:index],
                                          :pub_key => nil,
                                          :hash => nil
                                        } }
end

post "/shared-get-pub-key" do
  wallets = @cw.shared.wallets.list
  handle_api_err wallets, session
  hash = params[:hash] == 'true' ? { hash: true } : {}
  begin
    pub_key = @cw.shared.keys.get_public_key(params[:wid],
                                            params[:role],
                                            params[:index],
                                            hash)
  rescue
    session[:error] = "Make sure parameters are valid. "
    redirect "/shared-get-pub-key"
  end
  handle_api_err pub_key, session
  erb :form_get_public_key, { :locals => { :wallets => wallets,
                                          :wid => params[:wid],
                                          :role => params[:role],
                                          :index => params[:index],
                                          :pub_key => pub_key,
                                          :hash => params[:hash]
                                        } }
end

get "/shared-wallets/:wal_id/patch-payment" do
  wal = @cw.shared.wallets.get params[:wal_id]
  handle_api_err wal, session

  erb :form_shared_wallet_patch, { :locals => { :wal => wal } }
end

post "/shared-wallets/:wal_id/patch-payment" do
  up = @cw.shared.wallets.update_payment_script(params[:wal_id],
                                                params[:cosigner],
                                                params[:acc_pub_key])
  handle_api_err up, session

  redirect "/shared-wallets/#{params[:wal_id]}"
end

get "/shared-wallets/:wal_id/patch-delegation" do
  wal = @cw.shared.wallets.get params[:wal_id]
  handle_api_err wal, session

  erb :form_shared_wallet_patch, { :locals => { :wal => wal} }
end

post "/shared-wallets/:wal_id/patch-delegation" do
  up = @cw.shared.wallets.update_delegation_script(params[:wal_id],
                                                   params[:cosigner],
                                                   params[:acc_pub_key])
  handle_api_err up, session

  redirect "/shared-wallets/#{params[:wal_id]}"
end

get "/shared-wallets" do
  wallets = @cw.shared.wallets.list
  handle_api_err wallets, session
  erb :shared_wallets, { :locals => { :wallets => wallets } }
end

get "/shared-wallets/:wal_id" do
  wal = @cw.shared.wallets.get params[:wal_id]
  handle_api_err wal, session
  # txs = @cw.shelley.transactions.list params[:wal_id]
  # handle_api_err txs, session
  addrs = @cw.shared.addresses.list params[:wal_id]
  handle_api_err addrs, session

  erb :shared_wallet, { :locals => { :wal => wal, :txs => nil, :addrs => addrs} }
end

get "/shared-wallets-delete/:wal_id" do
  @cw.shared.wallets.delete params[:wal_id]
  redirect "/shared-wallets"
end

get "/shared-wallets-delete-all" do
  erb :form_del_all
end

post "/shared-wallets-delete-all" do
  s = @cw.shared.wallets.list
  handle_api_err s, session
  s.each do |wal|
    r = @cw.shared.wallets.delete wal['id']
    handle_api_err r, session
  end
  redirect "/shared-wallets"
end

get "/shared-wallets-create-from-pub-key" do
  erb :form_create_wallet_from_pub_key
end

post "/shared-wallets-create-from-pub-key" do
  name = params[:wal_name]
  pub_key = params[:pub_key]
  account_index = params[:account_index]
  begin
    payment_script_template = JSON.parse(params[:payment_script_template].strip)
  rescue
    session[:error] = "Make sure the 'payment_script_template' has correct JSON format."
    redirect '/shared-wallets-create-from-pub-key'
  end
  payload = {name: name,
             account_public_key: pub_key,
             account_index: account_index,
             payment_script_template: payment_script_template
             }
  if params[:delegation_script_template] != ''
    begin
      delegation_script_template = JSON.parse(params[:delegation_script_template].strip)
    rescue
      session[:error] = "Make sure the 'delegation_script_template' has correct JSON format."
      redirect '/shared-wallets-create-from-pub-key'
    end
    payload[:delegation_script_template] = delegation_script_template
  end
  wal = @cw.shared.wallets.create(payload)
  handle_api_err wal, session

  redirect "/shared-wallets/#{wal['id']}"
end

get "/shared-wallets-create" do
  # 24-word mnemonics
  mnemonics = mnemonic_sentence(24)
  erb :form_create_wallet, { :locals => { :mnemonics => mnemonics} }
end

post "/shared-wallets-create" do
  m = prepare_mnemonics params[:mnemonics]
  pass = params[:pass]
  name = params[:wal_name]
  account_index = params[:account_index]
  begin
    payment_script_template = JSON.parse(params[:payment_script_template].strip)
  rescue
    session[:error] = "Make sure the 'payment_script_template' has correct JSON format."
    redirect '/shared-wallets-create'
  end
  payload = { mnemonic_sentence: m,
              passphrase: pass,
              name: name,
              account_index: account_index,
              payment_script_template: payment_script_template
              }
  if params[:delegation_script_template] != ''
    begin
      delegation_script_template = JSON.parse(params[:delegation_script_template].strip)
    rescue
      session[:error] = "Make sure the 'delegation_script_template' has correct JSON format."
      redirect '/shared-wallets-create'
    end
    payload[:delegation_script_template] = delegation_script_template
  end

  wal = @cw.shared.wallets.create(payload)
  handle_api_err wal, session
  session[:wal] = wal
  handle_api_err wal, session

  redirect "/shared-wallets/#{wal['id']}"
end

# SHELLEY WALLETS
get "/wallets-get-assets" do
  wallets = @cw.shelley.wallets.list
  handle_api_err(wallets, session)

  erb :form_assets_get, { :locals => { :wallets => wallets,
                                       :asset_name => params[:asset_name],
                                       :policy_id => params[:policy_id],
                                       :asset => nil } }
end

post "/wallets-get-assets" do
  wallets = @cw.shelley.wallets.list
  handle_api_err(wallets, session)

  asset_name = (params[:asset_name] == '') ? nil : params[:asset_name].strip
  policy_id = (params[:policy_id] == '') ? nil : params[:policy_id].strip
  begin
    asset = @cw.shelley.assets.get(params[:wid], policy_id, asset_name)
  rescue
    session[:error] = "Make sure policy ID or asset name do not contain spaces."
  end

  erb :form_assets_get, { :locals => { :wallets => wallets,
                                       :asset_name => asset_name,
                                       :policy_id => policy_id,
                                       :asset => asset } }
end

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
                                           :assets => nil,
                                           :withdrawal => nil,
                                           :metadata => nil,
                                           :coin_selection => nil,
                                           :wallets => wallets } }
end

post "/wallets/coin-selection/random" do
  wallets = @cw.shelley.wallets.list
  handle_api_err wallets, session

  payload = prepare_payload(params)
  case params[:withdrawal]
  when ''
    w = nil
  when 'self'
    w = 'self'
  else
    w = params[:withdrawal].split
  end
  m = parse_metadata(params[:metadata])

  coin_selection = @cw.shelley.coin_selections.random(params[:wid], payload, w, m)

  erb :form_coin_selection, { :locals => { :addr_amt => params[:addr_amt],
                                           :assets => params[:assets],
                                           :withdrawal => params[:withdrawal],
                                           :metadata => params[:metadata],
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

get "/wallets/:wal_id/update-pass-mnem" do
  wal = @cw.shelley.wallets.get params[:wal_id]
  handle_api_err wal, session
  erb :form_wallet_update_pass_mnem, { :locals => { :wal => wal } }
end

post "/wallets/:wal_id/update-pass-mnem" do
  m = prepare_mnemonics params[:mnemonic_sentence]
  r = @cw.shelley.wallets.update_passphrase(params[:wal_id],
                                          {mnemonic_sentence: m,
                                           new_passphrase: params[:new_pass]})
  handle_api_err r, session
  redirect "/wallets/#{params[:wal_id]}"
end

get "/wallets-delete/:wal_id" do
  @cw.shelley.wallets.delete params[:wal_id]
  redirect "/wallets"
end

get "/wallets-create" do
  # 24-word mnemonics
  mnemonics = mnemonic_sentence(24)
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

  1.upto how_many do |i|
    mnemonics = mnemonic_sentence(params[:words_count]).split
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
  utxo_snapshot = @cw.shelley.wallets.utxo_snapshot params[:wid]
  wal = @cw.shelley.wallets.get params[:wid]
  wallets = @cw.shelley.wallets.list

  erb :utxo_details, { :locals => { :wal => wal,
                                    :utxo => utxo,
                                    :utxo_snapshot => utxo_snapshot,
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

get "/wallets-migration-plan" do
  wid = params[:wid]
  wallets = @cw.shelley.wallets.list

  erb :show_migration_plan, { :locals => { :migration_plan => nil,
                                          :addresses => nil,
                                          :wid => wid,
                                          :wallets => wallets } }
end

post "/wallets-migration-plan" do
  wid = params[:wid]
  addresses = params[:addresses].split("\n").map{|a| a.strip}
  wallets = @cw.shelley.wallets.list
  r = @cw.shelley.migrations.plan(wid, addresses)
  handle_api_err(r, session)

  erb :show_migration_plan, { :locals => { :migration_plan => r,
                                          :addresses => params[:addresses],
                                          :wid => wid,
                                          :wallets => wallets } }
end

# TRANSACTIONS SHELLEY

get "/decode-tx-shelley" do
  wallets = @cw.shelley.wallets.list
  handle_api_err wallets, session

  erb :form_tx_new_decode, {:locals => { :wallets => wallets,
                                         :tx => nil,
                                         :serialized_tx => nil } }
end

post "/decode-tx-shelley" do
  wallets = @cw.shelley.wallets.list
  handle_api_err wallets, session
  serialized_tx = params[:serialized_tx].strip
  tx = @cw.shelley.transactions.decode(params[:wid], serialized_tx)
  handle_api_err tx, session

  erb :form_tx_new_decode, {:locals => { :wallets => wallets,
                                         :tx => tx,
                                         :serialized_tx => serialized_tx } }
end

get "/balance-tx-shelley" do
  wallets = @cw.shelley.wallets.list
  handle_api_err wallets, session

  erb :form_tx_new_balance, {:locals => { :wallets => wallets } }
end

post "/sign-balanced-tx-shelley" do
  wid = params[:wid]
  begin
    payload = JSON.parse(params[:payload].strip)
  rescue
    session[:error] = "Make sure the 'payload' has correct JSON format."
    redirect '/balance-tx-shelley'
  end
  tx = @cw.shelley.transactions.balance(wid,
                                       payload)
  handle_api_err tx, session

  decoded_tx = @cw.shelley.transactions.decode(wid, tx['transaction'])
  handle_api_err decoded_tx, session

  erb :form_tx_new_sign, {:locals => { :tx => tx,
                                       :wid => wid,
                                       :decoded_tx => decoded_tx } }
end

# Decode shared
get "/decode-tx-shared" do
  wallets = @cw.shared.wallets.list
  handle_api_err wallets, session

  erb :form_tx_new_decode, {:locals => { :wallets => wallets,
                                         :tx => nil,
                                         :serialized_tx => nil } }
end

post "/decode-tx-shared" do
  wallets = @cw.shared.wallets.list
  handle_api_err wallets, session
  serialized_tx = params[:serialized_tx].strip
  tx = @cw.shared.transactions.decode(params[:wid], serialized_tx)
  handle_api_err tx, session

  erb :form_tx_new_decode, {:locals => { :wallets => wallets,
                                         :tx => tx,
                                         :serialized_tx => serialized_tx } }
end

# Construct shared
get "/construct-tx-shared" do
  wallets = @cw.shared.wallets.list
  handle_api_err wallets, session

  erb :form_tx_new_construct, {:locals => { :wallets => wallets, :tx => nil } }
end

post "/construct-tx-shared" do
  wid = params[:wid]

  if params[:payments_check]
    case params[:payments_mode]
    when 'single_output', 'multi_output'
      payload = prepare_payload_new_tx(params)
    when 'between_wallets'
      wid_dst = params[:wid_dst]
      amount = params[:amount_wallet]
      address_dst = @cw.shared.addresses.list(wid_dst,
                                              {state: "unused"}).
                                              first['id']
      if params[:assets_wallet] == ''
        payload = [ { "address": address_dst,
                      "amount": { "quantity": amount.to_i, "unit": "lovelace" }
                    }
                  ]
      else
        assets = parse_assets(params[:assets_wallet])
        payload = [ { "address": address_dst,
                      "amount": { "quantity": amount.to_i, "unit": "lovelace" },
                      "assets": assets
                    }
                  ]
      end
    end
  end

  if params[:withdrawals_check]
    case params[:withdrawal]
    when ''
      withdrawal = nil
    when 'self'
      withdrawal = 'self'
    else
      withdrawal = params[:withdrawal].split
    end
  end

  if params[:metadata_check]
    metadata = parse_metadata(params[:metadata])
  end

  if params[:delegations_check]
    case params[:delegation_action]
    when 'join'
      delegations = [
          { 'join' =>
            { 'pool' => params[:pool_id],
              'stake_key_index' => params[:stake_key_id]
            }
          }
      ]
    when 'quit'
      delegations = [
          { 'quit' =>
            { 'stake_key_index' => params[:stake_key_id]
            }
          }
      ]
    end
  end
  if params[:mint_check]
    mint = {}
    if params[:mint_action] == 'mint'
      addr = params[:mint_receiving_address].strip
      if addr.empty?
        mint[:operation] = {
            'mint' => { 'quantity' => params[:mint_amount].to_i }
        }
      else
        mint[:operation] = {
            'mint' => { 'receiving_address' => addr,
                        'quantity' => params[:mint_amount].to_i }
        }
      end
    end
    if params[:mint_action] == 'burn'
      mint[:operation] = {
          'burn' => { 'quantity' => params[:mint_amount].to_i }
      }
    end

    # policy script is either script or just string specifying cosigner
    begin
      script = JSON.parse(params[:mint_policy_script].strip)
    rescue
      script = params[:mint_policy_script]
    end
    mint[:policy_script_template] = script

    if params[:mint_hex] == 'true'
      mint[:asset_name] = params[:mint_asset_name]
    else
      # Encode mint_asset_name to hex
      mint[:asset_name] = params[:mint_asset_name].unpack("H*").first
    end
    mint_burn = [mint]
  end

  if params[:validity_interval_check]
    validity_interval = {}

    if params[:invalid_before_specified]
      validity_interval["invalid_before"] = {
        "quantity" => params[:invalid_before].to_i,
        "unit" => params[:invalid_before_unit]
      }
    end

    if params[:invalid_hereafter_specified]
      validity_interval["invalid_hereafter"] = {
        "quantity" => params[:invalid_hereafter].to_i,
        "unit" => params[:invalid_hereafter_unit]
      }
    end

  end

  tx = @cw.shared.transactions.construct(wid,
                                         payload,
                                         withdrawal,
                                         metadata,
                                         delegations,
                                         mint_burn,
                                         validity_interval)
  handle_api_err tx, session
  decoded_tx = @cw.shared.transactions.decode(wid, tx['transaction'])
  handle_api_err decoded_tx, session
  erb :form_tx_new_sign, {:locals => { :tx => tx,
                                       :wid => wid,
                                       :decoded_tx => decoded_tx } }
end

# Construct Shelley
get "/construct-tx-shelley" do
  wallets = @cw.shelley.wallets.list
  handle_api_err wallets, session

  erb :form_tx_new_construct, {:locals => { :wallets => wallets, :tx => nil } }
end

post "/construct-tx-shelley" do
  wid = params[:wid]

  if params[:payments_check]
    case params[:payments_mode]
    when 'single_output', 'multi_output'
      payload = prepare_payload_new_tx(params)
    when 'between_wallets'
      wid_dst = params[:wid_dst]
      amount = params[:amount_wallet]
      address_dst = @cw.shelley.addresses.list(wid_dst,
                                              {state: "unused"}).
                                              first['id']
      if params[:assets_wallet] == ''
        payload = [ { "address": address_dst,
                      "amount": { "quantity": amount.to_i, "unit": "lovelace" }
                    }
                  ]
      else
        assets = parse_assets(params[:assets_wallet])
        payload = [ { "address": address_dst,
                      "amount": { "quantity": amount.to_i, "unit": "lovelace" },
                      "assets": assets
                    }
                  ]
      end
    end
  end

  if params[:withdrawals_check]
    case params[:withdrawal]
    when ''
      withdrawal = nil
    when 'self'
      withdrawal = 'self'
    else
      withdrawal = params[:withdrawal].split
    end
  end

  if params[:metadata_check]
    metadata = parse_metadata(params[:metadata])
  end

  if params[:delegations_check]
    case params[:delegation_action]
    when 'join'
      delegations = [
          { 'join' =>
            { 'pool' => params[:pool_id],
              'stake_key_index' => params[:stake_key_id]
            }
          }
      ]
    when 'quit'
      delegations = [
          { 'quit' =>
            { 'stake_key_index' => params[:stake_key_id]
            }
          }
      ]
    end
  end
  if params[:mint_check]
    mint = {}
    if params[:mint_action] == 'mint'
      addr = params[:mint_receiving_address].strip
      if addr.empty?
        mint[:operation] = {
            'mint' => { 'quantity' => params[:mint_amount].to_i }
        }
      else
        mint[:operation] = {
            'mint' => { 'receiving_address' => addr,
                        'quantity' => params[:mint_amount].to_i }
        }
      end
    end
    if params[:mint_action] == 'burn'
      mint[:operation] = {
          'burn' => { 'quantity' => params[:mint_amount].to_i }
      }
    end

    # policy script is either script or just string specifying cosigner
    begin
      script = JSON.parse(params[:mint_policy_script].strip)
    rescue
      script = params[:mint_policy_script]
    end
    mint[:policy_script_template] = script

    if params[:mint_hex] == 'true'
      mint[:asset_name] = params[:mint_asset_name]
    else
      # Encode mint_asset_name to hex
      mint[:asset_name] = params[:mint_asset_name].unpack("H*").first
    end
    mint_burn = [mint]
  end

  if params[:validity_interval_check]
    validity_interval = {}

    if params[:invalid_before_specified]
      validity_interval["invalid_before"] = {
        "quantity" => params[:invalid_before].to_i,
        "unit" => params[:invalid_before_unit]
      }
    end

    if params[:invalid_hereafter_specified]
      validity_interval["invalid_hereafter"] = {
        "quantity" => params[:invalid_hereafter].to_i,
        "unit" => params[:invalid_hereafter_unit]
      }
    end

  end

  tx = @cw.shelley.transactions.construct(wid,
                                         payload,
                                         withdrawal,
                                         metadata,
                                         delegations,
                                         mint_burn,
                                         validity_interval)
  handle_api_err tx, session
  decoded_tx = @cw.shelley.transactions.decode(wid, tx['transaction'])
  handle_api_err decoded_tx, session
  erb :form_tx_new_sign, {:locals => { :tx => tx,
                                       :wid => wid,
                                       :decoded_tx => decoded_tx } }
end

post "/sign-tx-shelley" do
  wid = params[:wid]
  tx = @cw.shelley.transactions.sign(wid,
                                     params[:pass],
                                     params[:transaction])
  handle_api_err tx, session

  decoded_tx = @cw.shelley.transactions.decode(wid, tx['transaction'])
  handle_api_err decoded_tx, session

  erb :form_tx_new_submit, {:locals => { :tx => tx,
                                         :wid => wid,
                                         :decoded_tx => decoded_tx } }
end

post "/submit-tx-shelley" do
  wid = params['wid']
  serialized_tx = params['transaction']
  r = @cw.shelley.transactions.submit(wid, serialized_tx)
  handle_api_err r, session

  tx = @cw.shelley.transactions.get(wid, r['id'], {"simple-metadata" => true})
  handle_api_err tx, session

  erb :tx_details, { :locals => { :tx => tx, :wid => wid}  }
end

get "/submit-tx-standalone-shelley" do
  wid = params['wid']
  wallets = @cw.shelley.wallets.list
  handle_api_err wallets, session

  erb :form_tx_new_submit_standalone, { :locals => { :wallets => wallets,
                                                     :wid => wid,
                                                     :serialized_tx => nil}  }
end

post "/submit-tx-standalone-shelley" do
  wid = params['wid']
  serialized_tx = params['transaction'].strip
  r = @cw.shelley.transactions.submit(wid, serialized_tx)
  handle_api_err r, session

  tx = @cw.shelley.transactions.get(wid, r['id'], {"simple-metadata" => true})
  handle_api_err tx, session

  erb :tx_details, { :locals => { :tx => tx, :wid => wid}  }
end

get "/wallets-transactions" do
  query = toListTransactionsQuery(params)
  r = @cw.shelley.transactions.list(params[:wid], query)
  handle_api_err r, session

  wallets = @cw.shelley.wallets.list
  handle_api_err wallets, session

  erb :transactions, { :locals => { :wallets => wallets,
                                    :transactions => r,
                                    :query => query } }
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

  payload = prepare_payload(params)

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

  payload = prepare_payload(params)

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

  erb :tx_details, { :locals => { :tx => r, :wid => wid_src }  }
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
  if params[:assets] == ''
    payload = [{address_dst => amount}]
  else
    assets = parse_assets(params[:assets])
    payload = [ { "address": address_dst,
                  "amount": { "quantity": amount.to_i, "unit": "lovelace" },
                  "assets": assets
                }
              ]
  end

  r = @cw.shelley.transactions.create(wid_src,
                                      pass,
                                      payload,
                                      w, m, ttl)
  handle_api_err r, session

  erb :tx_details, { :locals => { :tx => r, :wid => wid_src }  }
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
  tx = @cw.shelley.transactions.get(wid, txid, {"simple-metadata" => true})
  handle_api_err tx, session

  erb :tx_details, { :locals => { :tx => tx, :wid => wid }  }
end

# BYRON WALLETS

get "/byron-wallets-get-assets" do
  wallets = @cw.byron.wallets.list
  handle_api_err(wallets, session)

  erb :form_assets_get, { :locals => { :wallets => wallets,
                                       :asset_name => params[:asset_name],
                                       :policy_id => params[:policy_id],
                                       :asset => nil } }
end

post "/byron-wallets-get-assets" do
  wallets = @cw.byron.wallets.list
  handle_api_err(wallets, session)

  asset_name = (params[:asset_name] == '') ? nil : params[:asset_name].strip
  policy_id = (params[:policy_id] == '') ? nil : params[:policy_id].strip
  begin
    asset = @cw.byron.assets.get(params[:wid], policy_id, asset_name)
  rescue
    session[:error] = "Make sure policy ID or asset name do not contain spaces."
  end

  erb :form_assets_get, { :locals => { :wallets => wallets,
                                       :asset_name => asset_name,
                                       :policy_id => policy_id,
                                       :asset => asset } }
end

get "/byron-wallets/coin-selection/random" do
  wallets = @cw.byron.wallets.list
  handle_api_err wallets, session
  erb :form_coin_selection, { :locals => { :addr_amt => nil,
                                           :assets => nil,
                                           :withdrawal => nil,
                                           :metadata => nil,
                                           :coin_selection => nil,
                                           :wallets => wallets } }
end

post "/byron-wallets/coin-selection/random" do
  wallets = @cw.byron.wallets.list
  handle_api_err wallets, session
  payload = prepare_payload(params)
  coin_selection = @cw.byron.coin_selections.random(params[:wid], payload)
  erb :form_coin_selection, { :locals => { :addr_amt => params[:addr_amt],
                                           :assets => params[:assets],
                                           :withdrawal => nil,
                                           :metadata => nil,
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
  utxo_snapshot = @cw.byron.wallets.utxo_snapshot params[:wid]
  wal = @cw.byron.wallets.get params[:wid]
  wallets = @cw.byron.wallets.list

  handle_api_err utxo, session
  handle_api_err wal, session
  erb :utxo_details, { :locals => { :wal => wal,
                                    :utxo => utxo,
                                    :utxo_snapshot => utxo_snapshot,
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
  mnemonics = mnemonic_sentence(12)
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

get "/byron-wallets-create-from-pub-key" do
  erb :form_create_wallet_from_pub_key
end

post "/byron-wallets-create-from-pub-key" do
  pub_key = params[:pub_key]
  name = params[:wal_name]
  pool_gap = params[:pool_gap].to_i
  wal = @cw.byron.wallets.create({name: name,
                                  account_public_key: pub_key,
                                  address_pool_gap: pool_gap,
                                  })
  handle_api_err wal, session

  redirect "/byron-wallets/#{wal['id']}"
end

get "/byron-wallets-create-from-xprv" do
  erb :form_create_wallet_from_xprv
end

post "/byron-wallets-create-from-xprv" do
  begin
    payload = JSON.parse(params[:payload].strip)
    payload[:style] = "random"
    wal = @cw.byron.wallets.create(payload)
    handle_api_err wal, session
  rescue
    session[:error] = "Make sure the 'payload' has correct JSON format."
    redirect "/byron-wallets-create-from-xprv"
  end

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

  1.upto how_many do |i|
    mnemonics = mnemonic_sentence(params[:words_count]).split
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

get "/byron-wallets-migration-plan" do
  wid = params[:wid]
  wallets = @cw.byron.wallets.list

  erb :show_migration_plan, { :locals => { :migration_plan => nil,
                                          :addresses => nil,
                                          :wid => wid,
                                          :wallets => wallets } }
end

post "/byron-wallets-migration-plan" do
  wid = params[:wid]
  addresses = params[:addresses].split("\n").map{|a| a.strip}
  wallets = @cw.byron.wallets.list
  r = @cw.byron.migrations.plan(wid, addresses)
  handle_api_err(r, session)

  erb :show_migration_plan, { :locals => { :migration_plan => r,
                                          :addresses => params[:addresses],
                                          :wid => wid,
                                          :wallets => wallets } }
end

# TRANSACTIONS BYRON
get "/construct-tx-byron" do
  wallets = @cw.byron.wallets.list
  handle_api_err wallets, session

  erb :form_tx_new_construct, {:locals => { :wallets => wallets, :tx => nil } }
end

post "/construct-tx-byron" do
  wid = params[:wid]
  if params[:payments_check]
    case params[:payments_mode]
    when 'single_output', 'multi_output'
      payload = prepare_payload_new_tx(params)
    end
  end

  if params[:metadata_check]
    metadata = parse_metadata(params[:metadata])
  end

  if params[:validity_interval_check]
    validity_interval = {}

    if params[:invalid_before_specified]
      validity_interval["invalid_before"] = {
        "quantity" => params[:invalid_before].to_i,
        "unit" => params[:invalid_before_unit]
      }
    end

    if params[:invalid_hereafter_specified]
      validity_interval["invalid_hereafter"] = {
        "quantity" => params[:invalid_hereafter].to_i,
        "unit" => params[:invalid_hereafter_unit]
      }
    end

  end

  r = @cw.byron.transactions.construct(wid,
                                       payload,
                                       metadata,
                                       mint = nil,
                                       validity_interval)
  handle_api_err r, session

  erb :form_tx_new_sign, {:locals => { :tx => r, :wid => wid } }
end

post "/sign-tx-byron" do
  wid = params[:wid]
  r = @cw.byron.transactions.sign(wid,
                                    params[:pass],
                                    params[:transaction])
  handle_api_err r, session
  erb :form_tx_new_submit, {:locals => { :tx => r, :wid => wid } }
end

post "/submit-tx-byron" do
  wid = params['wid']
  serialized_tx = params['transaction']
  r = @cw.byron.transactions.submit(wid, serialized_tx)
  handle_api_err r, session

  tx = @cw.byron.transactions.get(wid, r['id'])
  handle_api_err tx, session

  erb :tx_details, { :locals => { :tx => tx, :wid => wid}  }
end

get "/byron-wallets-transactions" do
  query = toListTransactionsQuery(params)
  r = @cw.byron.transactions.list(params[:wid], query)
  handle_api_err r, session

  wallets = @cw.byron.wallets.list
  handle_api_err wallets, session

  erb :transactions, { :locals => { :wallets => wallets,
                                    :transactions => r,
                                    :query => query } }
end

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

get "/byron-tx-fee-to-multi-address" do
  wallets = @cw.byron.wallets.list
  erb :form_tx_fee_to_multi_address, { :locals => { :wallets => wallets } }
end

post "/byron-tx-fee-to-address" do
  wid_src = params[:wid_src]
  payload = prepare_payload(params)

  r = @cw.byron.transactions.payment_fees(wid_src, payload)
  handle_api_err r, session

  erb :show_tx_fee, { :locals => { :tx_fee => r, :wallet_id => wid_src} }
end

get "/byron-tx-to-address" do
  wallets = @cw.byron.wallets.list
  erb :form_tx_to_address, { :locals => { :wallets => wallets } }
end

get "/byron-tx-to-multi-address" do
  wallets = @cw.byron.wallets.list
  erb :form_tx_to_multi_address, { :locals => { :wallets => wallets } }
end

post "/byron-tx-to-address" do
  wid_src = params[:wid_src]
  pass = params[:pass]

  payload = prepare_payload(params)

  r = @cw.byron.transactions.create(wid_src, pass, payload)
  handle_api_err r, session

  erb :tx_details, { :locals => { :tx => r, :wid => wid_src }  }
end

# MNEMONICS

get "/gen-mnemonics" do
  erb :form_gen_mnemonics, { :locals => {:mnemonics => nil,
                                         :words_count => nil } }
end

post "/gen-mnemonics" do
  mnemonics = mnemonic_sentence(params[:words_count])
  erb :form_gen_mnemonics, { :locals => {:mnemonics => mnemonics,
                                         :words_count => params[:words_count] } }
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

  erb :tx_details, { :locals => { :tx => r, :wid => w_id }  }
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

  erb :tx_details, { :locals => { :tx => r, :wid => w_id }  }
end

get "/stake-pools-fee" do
  wid = params['wid']
  r = @cw.shelley.stake_pools.delegation_fees wid if wid
  wallets = @cw.shelley.wallets.list

  erb :show_delegation_fee, { :locals => { :delegation_fee => r,
                                           :wid => wid,
                                           :wallets => wallets } }
end

get "/stake-keys" do
  wid = params['wid']
  r = @cw.shelley.stake_pools.list_stake_keys wid if wid
  wallets = @cw.shelley.wallets.list

  erb :show_stake_keys, { :locals => { :stake_keys => r,
                                           :wid => wid,
                                           :wallets => wallets } }
end
