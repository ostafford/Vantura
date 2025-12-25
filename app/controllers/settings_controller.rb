class SettingsController < ApplicationController
  def show
    @user = current_user
  end

  def update
    @user = current_user
    
    if params[:user] && params[:user][:up_pat].present?
      pat = params[:user][:up_pat].strip
      
      unless valid_pat_format?(pat)
        flash[:alert] = "Invalid PAT format. Please check your token. It should start with 'up:yeah:'"
        render :show, status: :unprocessable_entity
        return
      end

      # Check if PAT is changing
      old_pat = @user.up_pat
      pat_changed = old_pat != pat
      
      # Use update with strong parameters - this ensures Rails encrypted attributes work correctly
      if @user.update(up_pat: pat)
        if pat_changed
          InitialSyncJob.perform_later(@user.id)
          flash[:notice] = "Settings updated successfully. Syncing your data..."
        else
          flash[:notice] = "Settings updated successfully."
        end
        redirect_to settings_path
      else
        flash[:alert] = @user.errors.full_messages.join(", ")
        render :show, status: :unprocessable_entity
      end
    else
      # No PAT provided, just redirect
      redirect_to settings_path
    end
  end

  def sync_now
    if current_user.up_pat_configured?
      InitialSyncJob.perform_later(current_user.id)
      flash[:notice] = "Sync started. This may take a few minutes."
    else
      flash[:alert] = "Please configure your Up Bank PAT first."
    end
    redirect_to settings_path
  end

  private

  def valid_pat_format?(pat)
    pat.to_s.match?(/\Aup:yeah:[a-zA-Z0-9]+\z/)
  end
end

