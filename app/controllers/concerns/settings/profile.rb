module Settings::Profile
  extend ActiveSupport::Concern

  private

  def update_user_profile
    @user = Current.user

    if @user.update(profile_params)
      redirect_to settings_path, notice: "Profile updated successfully."
    else
      render :show, status: :unprocessable_entity
    end
  end

  def profile_params
    params.require(:user).permit(:email_address)
  end
end

