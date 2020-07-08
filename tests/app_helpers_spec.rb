require_relative 'spec_helper'

include Helpers::App

describe Helpers::App do

  it "bits_from_word_count" do
    h = {'9' => 96, '12' => 128, '15' => 164, '18' =>196, '21' => 224, '24' => 256}
    h.each do |k,v|
      expect(bits_from_word_count k).to eq v
    end

    expect{ bits_from_word_count 6 }.to raise_error "Non-supported no of words 6!"
    expect{ bits_from_word_count "haha" }.to raise_error "Non-supported no of words haha!"
  end

  it "render_deleg_status" do 
    expect(render_deleg_status("delegating")).to include "delegating"
    expect(render_deleg_status("delegating")).to include "bg-primary"
    expect(render_deleg_status("not_delegating")).to include "not_delegating"
    expect(render_deleg_status("not_delegating")).to include "bg-warning"
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
