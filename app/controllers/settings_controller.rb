class SettingsController < ApplicationController
  before_action :authenticate_user!

  def index
    @user = current_user
  end

  def update
    if current_user.update(user_params)
      respond_to do |format|
        format.html { redirect_to settings_path, notice: "Settings updated successfully" }
        format.json { head :ok }
      end
    else
      respond_to do |format|
        format.html { render :index, status: :unprocessable_entity }
        format.json { render json: { errors: current_user.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  private

  def user_params
    params.require(:user).permit(:name, :avatar_url, :dark_mode, :currency)
  end
end
