require 'simplecov'
require 'capybara/rspec'

SimpleCov.start do
  add_filter %r{^/tests/}
end

def connect
  visit "/"
  click_button "Connect"
  expect(page).to have_css("img[src*='usb-connected']")
end

def create_byron_wallet(style)
  visit "/byron-wallets-create"
  find("#style option[value='#{style}']").select_option

  if style == "icarus"
    words = BipMnemonic.to_mnemonic(bits: 164, language: 'english')
    find("#mnemonics").set words
  end

  click_button "Create"
end

def delete_all
  visit "/byron-wallets-delete-all"
  click_button "Delete all Byron wallets?"
  expect(page).to have_text("Byron wallets: 0")
end

require_relative '../app'  # <-- your sinatra app
require_relative '../helpers/app_helpers'
