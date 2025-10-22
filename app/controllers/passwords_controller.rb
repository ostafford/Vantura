class PasswordsController < ApplicationController
  allow_unauthenticated_access
  before_action :set_user_by_token, only: %i[ edit update ]

  def new
  end

  def create
    if user = User.find_by(email_address: params[:email_address])
      Rails.logger.info "[SECURITY] Password reset requested for: #{user.email_address} from IP: #{request.remote_ip}"
      PasswordsMailer.reset(user).deliver_later
    else
      Rails.logger.warn "[SECURITY] Password reset requested for non-existent email: #{params[:email_address]} from IP: #{request.remote_ip}"
    end

    redirect_to new_session_path, notice: "Password reset instructions sent (if user with that email address exists)."
  end

  def edit
  end

  def update
    if @user.update(params.permit(:password, :password_confirmation))
      Rails.logger.info "[SECURITY] Password successfully reset for: #{@user.email_address} from IP: #{request.remote_ip}"
      redirect_to new_session_path, notice: "Password has been reset."
    else
      Rails.logger.warn "[SECURITY] Failed password reset attempt for: #{@user.email_address} from IP: #{request.remote_ip}"
      redirect_to edit_password_path(params[:token]), alert: "Passwords did not match."
    end
  end

  private
    def set_user_by_token
      @user = User.find_by_password_reset_token!(params[:token])
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      redirect_to new_password_path, alert: "Password reset link is invalid or has expired."
    end
end
