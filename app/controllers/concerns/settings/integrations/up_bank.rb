module Settings::Integrations::UpBank
  extend ActiveSupport::Concern

  private

  def update_up_bank_token
    token = up_bank_params[:up_bank_token]

    # Only validate if user is actually changing the token (not just dots)
    if token.present? && !token.match?(/^•+$/)
      # Use Rails.error.handle to capture errors and provide fallback behavior
      result = Rails.error.handle(StandardError, context: { user_id: Current.user.id, action: "update_up_bank_token" }) do
        # Validate token by pinging Up Bank API
        unless validate_up_bank_token(token)
          return { success: false, message: "Invalid Up Bank token. Please check your token and try again." }
        end

        # Token is valid, save it
        if Current.user.update(up_bank_token: token)
          Rails.logger.info "[SECURITY] Up Bank token updated for: #{Current.user.email_address} from IP: #{request.remote_ip}"
          trigger_up_bank_sync
        else
          return { success: false, message: "Failed to save token.", render_errors: true }
        end
      end

      result || { success: false, message: "An error occurred. Please try again." }
    else
      { success: false, message: "Please enter a valid Up Bank token." }
    end
  end

  def validate_up_bank_token(token)
    # Test the token by pinging Up Bank API
    Rails.logger.info "Validating Up Bank token..."
    client = UpBank::Client.new(token)
    response = client.ping

    # Check if ping was successful
    is_valid = response.present? && response.dig(:meta, :statusEmoji) == "⚡️"

    if is_valid
      Rails.logger.info "Up Bank token validation successful!"
    else
      Rails.logger.warn "Up Bank token validation failed - unexpected response"
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
    Rails.logger.error "Up Bank token validation failed: #{e.message}"
    false
  end

  def trigger_up_bank_sync
    # Automatically sync the user's data
    Rails.logger.info "Starting auto-sync for user #{Current.user.id} after token configuration"
    sync_result = UpBank::SyncService.call(Current.user)

    if sync_result[:success]
      { success: true, message: "Token validated and data synced! Added #{sync_result[:new_transactions]} transactions.", redirect_to: root_path, sync_result: sync_result }
    else
      { success: true, message: "Token saved but sync failed: #{sync_result[:error]}. Please try clicking 'Sync Now' on the Dashboard.", redirect_to: root_path, sync_result: sync_result }
    end
  end

  def up_bank_params
    params.require(:user).permit(:up_bank_token)
  end
end
