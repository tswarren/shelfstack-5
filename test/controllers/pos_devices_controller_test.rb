# frozen_string_literal: true

require "test_helper"

class PosDevicesControllerTest < ActionDispatch::IntegrationTest
  setup do
    post session_path, params: { username: "admin", password: "password123" }
  end

  test "creates device for current store with audit" do
    assert_difference("PosDevice.count") do
      assert_difference("AdministrativeAuditEvent.count") do
        post pos_devices_path, params: {
          pos_device: { code: "REG2", name: "Register 2", device_type: "register", active: true }
        }
      end
    end
    device = PosDevice.find_by!(code: "REG2")
    assert_equal stores(:main_street).id, device.store_id
    assert_redirected_to pos_devices_path
  end

  test "cannot edit device from another store" do
    foreign = stores(:warehouse).pos_devices.create!(code: "W1", name: "Warehouse", device_type: "register")
    get edit_pos_device_path(foreign)
    assert_response :not_found
  end
end
