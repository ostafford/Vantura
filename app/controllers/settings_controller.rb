class SettingsController < ApplicationController
  def show
    # Show settings page with token form
  end

  def update
    token = user_params[:up_bank_token]

    # Only validate if user is actually changing the token (not just dots)
    if token.present? && !token.match?(/^•+$/)
      # Use Rails.error.handle to capture errors and provide fallback behavior
      Rails.error.handle(StandardError, context: { user_id: Current.user.id, action: "update_up_bank_token" }) do
        # Validate token by pinging Up Bank API
        unless validate_up_bank_token(token)
          redirect_to settings_path, alert: "❌ Invalid Up Bank token. Please check your token and try again."
          return
        end

        # Token is valid, save it
        if Current.user.update(up_bank_token: token)
          Rails.logger.info "[SECURITY] UP Bank token updated for: #{Current.user.email_address} from IP: #{request.remote_ip}"
          # Automatically sync the user's data
          Rails.logger.info "Starting auto-sync for user #{Current.user.id} after token configuration"
          sync_result = UpBank::SyncService.call(Current.user)

          if sync_result[:success]
            redirect_to root_path, notice: "✅ Token validated and data synced! Added #{sync_result[:new_transactions]} transactions."
          else
            redirect_to root_path, alert: "⚠️ Token saved but sync failed: #{sync_result[:error]}. Please try clicking 'Sync Now' on the Dashboard."
          end
        else
          render :show, status: :unprocessable_entity, alert: "Failed to save token: #{Current.user.errors.full_messages.join(', ')}"
        end
      end || redirect_to(settings_path, alert: "❌ An error occurred. Please try again.")
    else
      redirect_to settings_path, alert: "Please enter a valid Up Bank token."
    end
  end

  private

  def user_params
    params.require(:user).permit(:up_bank_token)
  end

  def validate_up_bank_token(token)
    # Test the token by pinging Up Bank API
    Rails.logger.info "Validating Up Bank token..."
    client = UpBank::Client.new(token)
    response = client.ping

    # Check if ping was successful
    is_valid = response.present? && response.dig(:meta, :statusEmoji) == "⚡️"

    if is_valid
      Rails.logger.info "✅ Up Bank token validation successful!"
    else
      Rails.logger.warn "❌ Up Bank token validation failed - unexpected response"
    end

    is_valid
  rescue StandardError => e
    # Report validation errors to error tracker with context
    Rails.error.report(e, 
      handled: true,
      severity: :warning,
      context: { 
        user_id: Current.user&.id,
        action: "validate_up_bank_token"
      }
    )
    Rails.logger.error "❌ Up Bank token validation failed: #{e.message}"
    false
  end
end
