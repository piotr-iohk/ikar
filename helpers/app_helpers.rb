module Helpers
  module App
    def version
      'v2020-11-26'
    end

    def is_connected?(w)
      begin
        w.misc.network.information
        true
      rescue
        false
      end
    end

    def generate_curl(response, label = 'curl')
      uri = response.request.last_uri
      body = response.request.options[:body]
      headers = response.request.options[:headers]
      method = response.request.http_method.to_s.split('::').last.upcase
      #certs
      certs = ""
      certs += "<br/>--cert #{session[:opt][:pem]} \\" unless session[:opt][:pem] == ''
      certs += "<br/>--cacert #{session[:opt][:cacert]} \\" unless  session[:opt][:cacert] == ''

      #headers
      headers_curled = ""
      if headers
        headers.each do |k,v|
          headers_curled += "<br/>-H \"#{k}: #{v}\" \\"
        end
      end
      curl = %Q{
                  curl -X #{method} #{uri} \\
                  #{"<br/>-d '" + body + "' \\" if body}
                  #{certs}
                  #{headers_curled}
                }
      curl = curl.strip.delete_suffix!("\\")
      %Q{
        <details>
          <summary>#{label}</summary>
            <code>
              #{curl}
            </code>
        </details>
       }
    end

    def generate_raw_response(resp_json, label = "Response")
      %Q{
        <details>
          <summary>#{label}</summary>
            <code>
              #{JSON.parse resp_json}
            </code>
        </details>
      }
    end

    def curl_and_response(res, curl_label = "curl", res_label = "Response")
      %Q{
        <small>#{generate_curl(res, curl_label)}</small>
        <small>#{generate_raw_response(res.to_s, res_label)}</small>
       }
    end

    def response2table(response)
      unless response
        session[:error] = %Q{ Got nothing from the wallet, either I cannot
                               connect or the request was somewhat wrong...
                            }
        redirect "/"
      end

      code = response.code
      r = ''

      case code
      when 500, 501 then
        r += render_danger(response.to_s)
        r += generate_curl(response)
      else
        table_options = {
            table_style: "border: 1px solid black; max-width: 600px;",
            table_class: "table table-striped table-hover table-condensed table-bordered",
            table_attributes: "border=1"
            }

        r += Json2table::get_html_table(response.to_s, table_options)
        r += generate_curl(response)
        r += generate_raw_response(response.to_json)
      end
      r
    end

    def parse_addr_amt(addr_amt)
      addr_amt.split("\n").map{|a| a.strip.split(":")}.collect{|a| {a.first.strip => a.last.strip}}
    end

    def parse_metadata(metadata)
      begin
        metadata == '' ? nil : YAML.load(metadata)
      rescue
        session[:error] = "Make sure metadata is a valid JSON. "
        redirect "/"
      end
    end

    def handle_api_err(r, session)
      unless r
        session[:error] = %Q{ Got nothing from the wallet, either I cannot
                               connect or the request was somewhat wrong...
                            }
        redirect "/"
      end
      unless [200, 201, 202, 204].include? r.code
        uri = r.request.last_uri
        body = r.request.options[:body]
        method = r.request.http_method.to_s.split('::').last.upcase
        session[:error] = %Q{
                  Whoops! I did:<br/>#{method} #{uri}
                  #{"<br/>Body: <code>" + body + "</code>" if body}
                  <br/>#{generate_curl(r)}
                  <br/><br/>The response was:<br/>
                  Code = #{r.code},<br/>
                  Message = #{r.to_s}
         }
        redirect "/"
      end
    end

    def os
      case RUBY_PLATFORM
      when /cygwin|mswin|mingw|bccwin|wince|emx/
        "Windows"
      when /darwin/
        "MacOS"
      when /linux/
        "Linux"
      else
        RUBY_PLATFORM
      end
    end

    def separator
      if os == "Windows"
        "\\"
      else
        "/"
      end
    end

    module_function :os, :separator

    # units
    def has_metadata_badge
      "<span class='badge badge-info'>has metadata</span><br/>"
    end

    def has_withdrawal_badge
      "<span class='badge badge-primary'>has withdrawal</span><br/>"
    end

    def show_tx_badges(tx)
      case tx['status']
      when "pending" then alert = "warning"
      when "in_ledger" then alert = "success"
      when "expired" then alert = "danger"
      end

      r = %Q{ <div class='row'>
                <div>&nbsp;&nbsp;&nbsp;
                  <span class='badge badge-#{alert}'>#{tx['status']}</span>
                </div>
             }
      if tx['metadata']
        r += %Q{<div>&nbsp;#{has_metadata_badge}</div>}
      end
      if (tx['withdrawals'].size > 0)
        r += %Q{<div>&nbsp;#{has_withdrawal_badge}</div>}
      end
      r += %Q{</div>}

      r
    end

    def render_addr_amt
      %Q{
        <div class="form-group">
          <label for="addr_amt">Address : Amount</label>
          <textarea class="form-control" name="addr_amt" id="addr_amt" rows="5"></textarea>
          <small id="help" class="form-text text-muted">

            <details>
              <summary><i>address:amount</i> per line.</summary>
              <code>
                Testnet:<br/><br/>
  37btjrVyb4KF6KtvXYUxDHqjAwfKAuDzP71UEuG6vh87rjstvB8o1Muu6KaeGAF8xZro63Zc5VAYNnQtcci4vT8jhLuNtwku9x1YgS18LHFAhxxTi8:1000000
  <br/>2cWKMJemoBakujqtRy1FT978A3dLJcc1vXKzGTxxhsShkRL8YDUreEje2GqaC3en5TtCc:1000000
  <br/>addr1qrvc39e0lampjjpg0z65z0pccjvpg502c738s3kyam755rhl0dw5r75vk42mv3ykq8vyjeaanvpytg79xqzymqy5acmqjdm7lg:1000000
  <br/><br/>Mainnet:<br/><br/>
  addr1q95vgw8r27wtsm7efxulnh6mx6r6fh6q35p4pv6zr4eraef7y5xc6cr99fsj8w0hqksgwv3enatmz9ulpp6zn2kuskaqmqda5n:1000000
  <br/>addr1qxxkaq0d3c739xf0gdj0jdf0rel7azpqkskn8y6c5fusvue7y5xc6cr99fsj8w0hqksgwv3enatmz9ulpp6zn2kuskaqarfnmd:1000000

              </code>
            </details>

          </small>
        </div>
       }
    end

    def render_tx_on_wallet_page(url_path, tx, id)
      r = %Q{

        <small><b>ID: </b><a href='#{(url_path.include? "byron") ? "/byron-wallets" : "/wallets"}/#{id}/txs/#{tx['id']}'>#{tx['id']}</a></small><br/>
        #{show_tx_badges(tx)}
      }
      if tx['inserted_at']
        r += %Q{
          <small><b>Inserted at: </b></small><br/>
          <small>&nbsp;&nbsp;<b>Time: </b>#{tx['inserted_at']['time']}</small><br/>
          <small>&nbsp;&nbsp;<b>(Block: </b>#{tx['inserted_at']['height']['quantity']}, </small>
          <small>&nbsp;&nbsp;<b>Epoch: </b>#{tx['inserted_at']['epoch_number']}, </small>
          <small>&nbsp;&nbsp;<b>Slot: </b>#{tx['inserted_at']['slot_number']})</small><br/>
        }
      end
      if tx['pending_since']
        r += %Q{
          <small><b>Pending since: </b></small><br/>
          <small>&nbsp;&nbsp;<b>Time: </b>#{tx['pending_since']['time']}</small><br/>
          <small>&nbsp;&nbsp;<b>(Block: </b>#{tx['pending_since']['height']['quantity']}, </small>
          <small>&nbsp;&nbsp;<b>Epoch: </b>#{tx['pending_since']['epoch_number']}, </small>
          <small>&nbsp;&nbsp;<b>Slot: </b>#{tx['pending_since']['slot_number']})</small><br/>
        }
      end
      r += %Q{
          <small><b>Status: </b>#{tx['status']}</small><br/>
          <small><b>Amount: </b>#{tx['amount']['quantity'] if tx['amount']}</small><br/>
          <small><b>Direction: </b>#{tx['direction']}</small><br/>
          <small><b>Depth: </b> #{tx['depth']['quantity'].to_s + " blocks" if tx['depth']} </small><br/>
          <small>---</small><br/>
        }
      r
    end

    def render_tx_shelley_form_part
      %q{

        <div class="form-group">
          <label class="form-check-label" for="withdrawal">Use rewards in transaction</label>
          <input type="text" class="form-control" class="form-check-input" id="withdrawal"
                name="withdrawal"
                placeholder="self or mnemonics">
          <small id="help" class="form-text text-muted">Use: 'self' for self withdrawal or mnemonic sentence for external one.</small>
        </div>

        <div class="form-group">
          <label class="form-check-label" for="metadata">Attach metadata</label>
          <textarea class="form-control" name="metadata" id="metadata" rows="4"></textarea>
          <small id="help" class="form-text text-muted">
            <details>
              <summary>Examplary metadata</summary>
                <code>
                {
                   "0":{
                      "string":"cardano"
                   },
                   "1":{
                      "int":14
                   },
                   "2":{
                      "bytes":"2512a00e9653fe49a44a5886202e24d77eeb998f"
                   },
                   "3":{
                      "list":[
                         {
                            "int":14
                         },
                         {
                            "int":42
                         },
                         {
                            "string":"1337"
                         }
                      ]
                   },
                   "4":{
                      "map":[
                         {
                            "k":{
                               "string":"key"
                            },
                            "v":{
                               "string":"value"
                            }
                         },
                         {
                            "k":{
                               "int":14
                            },
                            "v":{
                               "int":42
                            }
                         }
                      ]
                   }
                }
                </code>
            </details>
          </small>
        </div>

        <div class="form-group">
          <label class="form-check-label" for="ttl">Time-to-live</label>
          <input type="text" class="form-control" class="form-check-input" id="ttl"
                name="ttl"
                placeholder="TTL in seconds">
          <small id="help" class="form-text text-muted">Transaction TTL in seconds.</small>
        </div>
       }
    end

    def render_danger(text)
      "<span class='badge badge-danger'>#{text}</span>"
    end

    def render_success(text)
      "<span class='badge badge-success'>#{text}</span>"
    end

    def render_deleg_status(status)
      case status
      when "not_delegating" then cl = "bg-secondary"
      when "delegating" then cl = "bg-primary"
      else cl = "bg-danger"
      end
      "<div class=\"d-inline p-2 #{cl} text-white\">#{status}</div>"
    end

    def render_wal_status(status, wal)
      case status
      when "not_responding" then cl = "bg-danger"
      when "syncing" then cl = "bg-warning"
      when "ready" then cl = "bg-success"
      else cl = "bg-danger"
      end
      r = "<div class=\"d-inline p-2 #{cl} text-white\">#{status}</div>"
      r += ", Progress: #{wal['state']['progress']['quantity']}%" if status == "syncing"
      r
    end

    def general_status(status)
      case status
      when "syncing" then cl = "warning"
      when "ready" then cl = "success"
      else cl = "danger"
      end
      %Q{ <span class="badge badge-#{cl}"> #{status} </span>}
    end

    def prepare_mnemonics(mn)
      if mn.include? ","
        mn.split(",").map {|w| w.strip}
      else
        mn.split
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
        else
          raise "Non-supported no of words #{wc}!"
      end
      bits
    end

  end
end
