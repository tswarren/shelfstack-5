# frozen_string_literal: true

require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # Docker (and some CI images) ship Debian Chromium rather than Google Chrome.
  # Host runs without these env vars continue to use Selenium Manager defaults.
  if (chrome_bin = ENV["CHROME_BIN"].presence)
    Selenium::WebDriver::Chrome.path = chrome_bin
  end

  if (driver_path = ENV["CHROMEDRIVER_PATH"].presence)
    Selenium::WebDriver::Chrome::Service.driver_path = driver_path
  end

  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ] do |driver_option|
    driver_option.binary = ENV["CHROME_BIN"] if ENV["CHROME_BIN"].present?
    driver_option.add_argument("--no-sandbox")
    driver_option.add_argument("--disable-dev-shm-usage")
    driver_option.add_argument("--disable-gpu")
  end
end
