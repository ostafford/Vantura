# frozen_string_literal: true

class RegistrationsController < Devise::RegistrationsController
  # Custom RegistrationsController to handle email_address field
  # instead of the default 'email' field expected by Devise.
  #
  # The User model uses 'email_address' as the database field name
  # (following the codebase's descriptive naming convention), but Devise's
  # default RegistrationsController expects 'email' in strong parameters.
  #
  # This controller overrides the parameter methods to permit 'email_address'
  # instead of 'email', allowing registration to work correctly.

  private

  def sign_up_params
    permitted = params.require(:user).permit(:email, :password, :password_confirmation)
    permitted[:email_address] = permitted.delete(:email) if permitted[:email]
    permitted
  end

  def account_update_params
    permitted = params.require(:user).permit(:email, :password, :password_confirmation, :current_password)
    permitted[:email_address] = permitted.delete(:email) if permitted[:email]
    permitted
  end
end
