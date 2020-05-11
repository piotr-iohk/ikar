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

    it "I can import address" do
      mnemonics = ["faculty", "banner", "purity", "fox", "little", "clever",
                   "announce", "culture", "light", "frown", "anchor", "found"]
      addresses = ["37btjrVyb4KECAbGSZucHRWZnbfDs1qu5E6WLQsJDVMGKwqySd84oUXLtjoUfRYqQ2S4bcYBLMSCizhyZ13rdV1A8BJsMfyKnqWJjPq83uhaFPBMDo",
                   "37btjrVyb4KBSA8djaLN6RQRLjMeKPsrPEMAXGt8PmeEdiRSbXHK8RGDdCxhtcWQmeLwnc4EAvNkq4xikTmjkoxrEo8orMQbAwJMwk6mbddJemacwu",
                   "37btjrVyb4KEBL6ars22ro737YYqXg6ax8jR8AoGu1ER24iQN2zhDA253MsrjE15CTkVKqCUE3XDxfzKWsTGwdBG2QJs2B9u9VAfDbBBwhqDr6EEpL"]

      create_byron_wallet "random", {mnemonics: mnemonics}
      expect(page).to have_link("My Test Wallet (random)")
      (addresses * 2).each do |addr|
        click_link "Import address"
        find("#address").set addr
        click_button "Import address"
        expect(page).to have_link("My Test Wallet (random)")
      end

      expect(find("#addresses_total").text).to eq addresses.size.to_s
      expect(find("#addresses_unused").text).to eq addresses.size.to_s

    end

    it "I can see UTxO" do
      create_byron_wallet "random"
      expect(page).to have_link("My Test Wallet (random)")
      click_link "UTxO"
      expect(page).to have_link("go back to wallet")
    end

    it "I can see Migration Fee" do
      create_byron_wallet "random"
      click_link "Migration Fee"
      expect(page).to have_text "nothing_to_migrate"
    end

    it "I cannot Migrate" do
      create_byron_wallet "random"
      click_link "Migrate"
      expect(page).to have_text "not_implemented"
    end

    it "I could check migration fee - if I had money" do
      address = "37btjrVyb4KEpFyPXAJjJib9FeBRNH8oT4abThrXGQTAmrb2LPo7q2jE9ehutvPrDRBhSp5zFLAwN2CSNu1xqppffvBK5sHaFGM2zW1HukJ4ZRje3u"
      create_byron_wallet "random"
      click_link "Tx"
      click_link "Tx Fee"
      find("#address").set address
      click_button "Tx fee"
      expect(page).to have_text "not_enough_money"
    end

    it "I could send tx - if I had money" do
      address = "37btjrVyb4KEpFyPXAJjJib9FeBRNH8oT4abThrXGQTAmrb2LPo7q2jE9ehutvPrDRBhSp5zFLAwN2CSNu1xqppffvBK5sHaFGM2zW1HukJ4ZRje3u"
      create_byron_wallet "random"
      click_link "Tx"
      click_link "To address"
      find("#address").set address
      click_button "Send Tx"
      expect(page).to have_text "not_enough_money"
    end

    it "I can update wallet's name" do
      new_name = "Updated wallet name!"
      create_byron_wallet "random"
      click_link "Manage"
      click_link "Update name"
      find("#name").set new_name
      click_button "Update name"
      expect(page).to have_link new_name
    end

    it "I can update wallet's passphrase" do
      new_pass = "Updated wallet passphrase!"
      create_byron_wallet "random"
      click_link "Manage"
      click_link "Update passphrase"
      find("#new_pass").set new_pass
      click_button "Update passphrase"
      expect(page).to have_text "Balance:"
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
