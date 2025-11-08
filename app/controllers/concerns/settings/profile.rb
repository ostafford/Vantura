module Settings::Profile
  extend ActiveSupport::Concern

  private

  def update_user_profile
    @user = Current.user
    @statistics = {
      accounts_count: @user.accounts.count,
      projects_count: user_projects_count
    }

    if @user.update(profile_params)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to settings_path, notice: "Profile updated successfully." }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("profile-section", partial: "settings/profile_section_content") }
        format.html { render :show, status: :unprocessable_entity }
      end
    end
  end

  def user_projects_count
    Project
      .joins("LEFT JOIN project_memberships ON project_memberships.project_id = projects.id")
      .where("projects.owner_id = :uid OR project_memberships.user_id = :uid", uid: Current.user.id)
      .distinct
      .count
  end

  def profile_params
    params.require(:user).permit(:name, :email_address)
  end
end
