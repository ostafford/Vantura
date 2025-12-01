class SettingsController < ApplicationController
  before_action :authenticate_user!

  def index
    @user = current_user
  end

  def update
    if current_user.update(user_params)
      redirect_to settings_path, notice: "Settings updated successfully"
    else
      render :index, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:name, :avatar_url, :dark_mode, :currency)
  end
end
