# frozen_string_literal: true

class PosDevicesController < ApplicationController
  before_action -> { require_permission!("administration.device.manage") }
  before_action :set_device, only: %i[edit update]

  def index
    @devices = Current.store.pos_devices.order(:code)
  end

  def new
    @device = Current.store.pos_devices.new(device_type: "register")
  end

  def create
    @device = Current.store.pos_devices.new(device_params)
    if Administration::CreatePosDevice.call(
      device: @device,
      actor: Current.user,
      organization: Current.organization,
      store: Current.store
    )
      redirect_to pos_devices_path, notice: "Device created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if Administration::UpdatePosDevice.call(
      device: @device,
      attributes: device_params.to_h,
      actor: Current.user,
      organization: Current.organization,
      store: Current.store
    )
      redirect_to pos_devices_path, notice: "Device updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_device
    @device = Current.store.pos_devices.find(params[:id])
  end

  def device_params
    params.require(:pos_device).permit(:code, :name, :device_type, :active)
  end
end
