require_relative 'spec_helper'

include Helpers::App

describe Helpers::App do

  it "parse_addr_amt" do
    addr_amt = "addr1:1\naddr2:2\naddr3:3"
    res = [{:address=>"addr1", :amount=>{:quantity=>1, :unit=>"lovelace"}},
           {:address=>"addr2", :amount=>{:quantity=>2, :unit=>"lovelace"}},
           {:address=>"addr3", :amount=>{:quantity=>3, :unit=>"lovelace"}}]
    expect(parse_addr_amt(addr_amt)).to eq res
  end

  it "parse_assets" do
    assets = "pol1:ass1:1\npol2:ass2:2\npol3:ass3:3"
    res = [{"asset_name"=>"ass1", "policy_id"=>"pol1", "quantity"=>1},
           {"asset_name"=>"ass2", "policy_id"=>"pol2", "quantity"=>2},
           {"asset_name"=>"ass3", "policy_id"=>"pol3", "quantity"=>3}]
    expect(parse_assets(assets)).to eq res
  end

  it "mnemonic_sentence" do
    h = {'9' => 96, '12' => 128, '15' => 164, '18' =>196, '21' => 224, '24' => 256}
    h.each do |k,_|
      expect(mnemonic_sentence k).to satisfy {|m| m.split.size == k.to_i}
    end

    expect{ mnemonic_sentence 6 }.to raise_error "Non-supported no of words 6! Supported are [\"9\", \"12\", \"15\", \"18\", \"21\", \"24\"]"
    expect{ mnemonic_sentence "haha" }.to raise_error "Non-supported no of words haha! Supported are [\"9\", \"12\", \"15\", \"18\", \"21\", \"24\"]"
  end

  it "render_deleg_status" do
    expect(render_deleg_status("delegating")).to include "delegating"
    expect(render_deleg_status("delegating")).to include "bg-primary"
    expect(render_deleg_status("not_delegating")).to include "not_delegating"
    expect(render_deleg_status("not_delegating")).to include "bg-secondary"
  end

  it "render_wal_status" do
    progress = "4444"
    wal = {'state' => {'progress' => {'quantity' => progress}}}
    t1a = render_wal_status("not_responding", wal).include? "not_responding"
    t1b = render_wal_status("not_responding", wal).include? progress
    t2a = render_wal_status("syncing", wal).include? "syncing"
    t2b = render_wal_status("syncing", wal).include? progress
    t3a = render_wal_status("ready", wal).include? "ready"
    t3b = render_wal_status("ready", wal).include? progress
    t4a = render_wal_status("unknown", wal).include? "unknown"
    t4b = render_wal_status("unknown", wal).include? progress
    expect(t1a).to eq true
    expect(t1b).to eq false
    expect(t2a).to eq true
    expect(t2b).to eq true
    expect(t3a).to eq true
    expect(t3b).to eq false
    expect(t4a).to eq true
    expect(t4b).to eq false
  end

  it "prepare_mnemonics" do
    t1 = "word word word"
    t2 = "word, word, word"
    expected = ["word", "word", "word"]
    expect(prepare_mnemonics t1).to eq expected
    expect(prepare_mnemonics t2).to eq expected
  end

end
