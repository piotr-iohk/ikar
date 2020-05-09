require_relative 'spec_helper'

Capybara.app = Sinatra::Application
# Capybara.default_driver = :selenium
# Capybara.server = :webrick

include Helpers::App

describe 'Using App', type: :feature do
  it "I can see my platform" do
    visit "/"
    expect(page).to have_text os
  end

  it "I can generate mnemonics" do
    visit "/gen-mnemonics"
    [9, 12, 15, 21, 24].each do |wc|
      find("select option[value='#{wc}']").select_option
      click_button "Generate"
      gen_wc = all("textarea").first.text.split.size
      expect(wc).to eq gen_wc
    end
  end

  it "I can connect to cardano-wallet" do
    visit "/"
    click_button "Connect"
    expect(page).to have_css("img[src*='usb-connected']")
  end

  describe "Network" do
    before(:each) do
      connect
    end

    it "I can check /network/information" do
      click_link "Network"
      click_link "Network Information"
      expect(page).to have_text "Network information"
    end

    it "I can check /network/clock" do
      click_link "Network"
      click_link "Network Clock"
      expect(page).to have_text "Network clock"
    end

    it "I can check /network/parameters" do
      click_link "Network"
      click_link "Network Parameters"
      click_button "Get Network Params"
      expect(page).to have_text "Network parameters"
    end
  end

  describe "Byron wallets" do
    before(:each) do
      connect
    end

    after(:each) do
      delete_all
    end

    ['random', 'trezor', 'ledger', 'icarus'].each do |style|
      it "I can create wallet #{style}" do
        create_byron_wallet(style)
        expect(page).to have_link("My Test Wallet (#{style})")
        visit "/byron-wallets"
        expect(page).to have_text("Byron wallets: 1")
      end
    end

    it "I can create many" do
      how_many = 3
      visit "/byron-wallets-create-many"
      find("#how_many").set how_many
      click_button "Create"
      expect(page).to have_text("Byron wallets: #{how_many}")
    end

    it "I can gen address" do
      create_byron_wallet "random"
      expect(page).to have_link("My Test Wallet (random)")
      click_link "Generate address"
      click_button "Gen address"
      expect(page).to have_link("My Test Wallet (random)")
    end

  end

  describe "Shelley wallets" do
    before(:each) do
      connect
    end

    it "Not implemented" do
      visit "/wallets"
      expect(page).to have_text "not_implemented"
    end
  end

  describe "Stake pools" do
    before(:each) do
      connect
    end

    it "Not implemented" do
      visit "/stake-pools"
      expect(page).to have_text "not_implemented"
    end
  end
end
