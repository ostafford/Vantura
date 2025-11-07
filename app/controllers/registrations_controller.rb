class RegistrationsController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 5, within: 15.minutes, only: :create, with: -> { redirect_to sign_up_path, alert: "Too many registration attempts. Please try again later." }

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      Rails.logger.info "[SECURITY] New user registration: #{@user.email_address} from IP: #{request.remote_ip}"
      start_new_session_for @user
      session[:return_to_after_authenticating] = settings_path
      redirect_to after_authentication_url, notice: "Welcome to Vantura! Please configure your Up Bank token to get started."
    else
      Rails.logger.warn "[SECURITY] Failed registration attempt for: #{params.dig(:user, :email_address)} from IP: #{request.remote_ip}"
      render :new, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:email_address, :password, :password_confirmation)
  end
end
