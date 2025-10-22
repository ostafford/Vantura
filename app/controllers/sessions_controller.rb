class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_url, alert: "Try again later." }

  def new
  end

  def create
    if user = User.authenticate_by(params.permit(:email_address, :password))
      Rails.logger.info "[SECURITY] Successful login: #{user.email_address} from IP: #{request.remote_ip}, User-Agent: #{request.user_agent}"
      start_new_session_for user
      redirect_to after_authentication_url
    else
      Rails.logger.warn "[SECURITY] Failed login attempt: #{params[:email_address]} from IP: #{request.remote_ip}, User-Agent: #{request.user_agent}"
      redirect_to new_session_path, alert: "Try another email address or password."
    end
  end

  def destroy
    Rails.logger.info "[SECURITY] User logout: #{Current.session.user.email_address} from IP: #{request.remote_ip}"
    terminate_session
    redirect_to new_session_path
  end
end
