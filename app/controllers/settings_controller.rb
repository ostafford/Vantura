class SettingsController < ApplicationController
  include Settings::Profile
  include Settings::Integrations::UpBank

  def show
    @user = Current.user
    @statistics = {
      accounts_count: @user.accounts.count,
      projects_count: user_projects_count
    }

    # Generate deletion token for this session
    session[:deletion_token] = SecureRandom.hex(16)
  end

  def update_profile
    update_user_profile
  end

  def update_up_bank_integration
    @up_bank_result = update_up_bank_token

    respond_to do |format|
      format.turbo_stream
      format.html do
        if @up_bank_result[:success]
          redirect_to @up_bank_result[:redirect_to] || settings_path, notice: @up_bank_result[:message]
        elsif @up_bank_result[:render_errors]
          render :show, status: :unprocessable_entity
        else
          redirect_to settings_path, alert: @up_bank_result[:message]
        end
      end
    end
  end

  def destroy
    @deletion_result = AccountDeletionService.call(Current.user, params[:confirmation_token], session[:deletion_token])

    respond_to do |format|
      format.turbo_stream
      format.html do
        if @deletion_result[:success]
          session.delete(:deletion_token)
          cookies.delete(:session_id)
          redirect_to new_session_path, notice: @deletion_result[:message]
        else
          redirect_to settings_path, alert: @deletion_result[:message]
        end
      end
    end
  end

end
