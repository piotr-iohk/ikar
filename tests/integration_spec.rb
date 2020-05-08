require_relative 'spec_helper'

Capybara.app = Sinatra::Application
# Capybara.default_driver = :selenium
# Capybara.server = :webrick

include Helpers::App

describe 'This App', type: :feature do
  it "I can visit on all platforms" do
    visit "/"
    expect(page).to have_text os
  end
end
