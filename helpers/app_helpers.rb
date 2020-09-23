module Helpers
  module App
    def is_connected?(w)
      begin
        w.misc.network.information
        true
      rescue
        false
      end
    end

    def handle_api_err(r, session)
      unless r
        session[:error] = "It seems I cannot make a connection to wallet..."
        redirect "/"
      end
      unless [200, 201, 202, 204].include? r.code
        uri = r.request.last_uri
        body = r.request.options[:body]
        method = r.request.http_method.to_s.split('::').last.upcase
        msg_about_request  = "Whoops! I did:<br/>#{method} #{uri}"
        msg_about_body     = "<br/>Body: <code>#{body}</code>" if body
        msg_about_response = "<br/><br/>The response was:<br/>
                              Code = #{r.code},<br/>
                              Message = #{r.to_s}"
        session[:error] = msg_about_request + msg_about_body.to_s + msg_about_response
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
    def render_tx_on_wallet_page(url_path, tx, id)
      r = %Q{

        <small><b>ID: </b><a href='#{(url_path.include? "byron") ? "/byron-wallets" : "/wallets"}/#{id}/txs/#{tx['id']}'>#{tx['id']}</a></small><br/>
      }

      if tx['inserted_at']
        r += %Q{
          <small><b>Inserted at: </b></small><br/>
          <small>&nbsp;&nbsp;<b>Time: </b>#{tx['inserted_at']['time']}</small><br/>
          <small>&nbsp;&nbsp;<b>(Block: </b>#{tx['inserted_at']['block']['height']['quantity']}, </small>
          <small>&nbsp;&nbsp;<b>Epoch: </b>#{tx['inserted_at']['block']['epoch_number']}, </small>
          <small>&nbsp;&nbsp;<b>Slot: </b>#{tx['inserted_at']['block']['slot_number']})</small><br/>
        }
      end
      if tx['pending_since']
        r += %Q{
          <small><b>Pending since: </b></small><br/>
          <small>&nbsp;&nbsp;<b>Time: </b>#{tx['pending_since']['time']}</small><br/>
          <small>&nbsp;&nbsp;<b>(Block: </b>#{tx['pending_since']['block']['height']['quantity']}, </small>
          <small>&nbsp;&nbsp;<b>Epoch: </b>#{tx['pending_since']['block']['epoch_number']}, </small>
          <small>&nbsp;&nbsp;<b>Slot: </b>#{tx['pending_since']['block']['slot_number']})</small><br/>
        }
      end
      r += %Q{
          <small><b>Status: </b>#{tx['status']}</small><br/>
          <small><b>Amount: </b>#{tx['amount']['quantity'] if tx['amount']}</small><br/>
          <small><b>Direction: </b>#{tx['direction']}</small><br/>
          <small><b>Depth: </b> #{tx['depth']['quantity'].to_s + " blocks" if tx['depth']} </small><br/>
          #{"<span class='badge badge-info'>has metadata</span><br/>" if tx['metadata']}
          #{"<span class='badge badge-primary'>has withdrawal</span><br/>" if (tx['withdrawals'].size > 0)}
          <small>---</small><br/>
        }
      r
    end

    def render_tx_withdraw_and_metadata_form
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
       }
    end

    def render_danger(text)
      "<div class=\"d-inline p-2 bg-danger text-white\">#{text}</div>"
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
