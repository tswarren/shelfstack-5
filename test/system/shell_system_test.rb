# frozen_string_literal: true

require "application_system_test_case"

class ShellSystemTest < ApplicationSystemTestCase
  test "admin can sign in and see sidebar navigation" do
    visit new_session_path
    fill_in "Username", with: "admin"
    fill_in "Password", with: "password123"
    click_button "Sign in"

    assert_selector "aside.app-sidebar"
    assert_link "Products"
    assert_link "Register"
    assert_selector "a.skip-link", text: "Skip to main content"
  end
end
