class SettingsController < ApplicationController
  before_action :authenticate_user!

  def index
    @user = current_user
    @accounts = current_user.accounts.to_a if current_user.has_up_bank_token?
  end

  def update
    @user = current_user
    if @user.update(user_params)
      flash[:notice] = I18n.t("flash.settings.updated")
      respond_to do |format|
        format.html { redirect_to settings_path, notice: flash[:notice] }
        format.json { head :ok }
        format.turbo_stream
      end
    else
      @accounts = @user.accounts.to_a if @user.has_up_bank_token?
      respond_to do |format|
        format.html { render :index, status: :unprocessable_entity }
        format.json { render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity }
        format.turbo_stream { render :index, status: :unprocessable_entity }
      end
    end
  end

  def update_password
    @user = current_user
    if @user.update_with_password(password_params)
      bypass_sign_in(@user)
      flash[:notice] = I18n.t("flash.settings.password_updated")
      respond_to do |format|
        format.html { redirect_to settings_path, notice: flash[:notice] }
        format.json { head :ok }
        format.turbo_stream
      end
    else
      @accounts = @user.accounts.to_a if @user.has_up_bank_token?
      respond_to do |format|
        format.html { render :index, status: :unprocessable_entity }
        format.json { render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity }
        format.turbo_stream { render :index, status: :unprocessable_entity }
      end
    end
  end

  def update_up_bank_token
    @user = current_user
    @accounts = @user.accounts.to_a if @user.has_up_bank_token?
    if @user.update(up_bank_token: params[:user][:up_bank_token])
      flash[:notice] = I18n.t("flash.settings.token_updated")
      respond_to do |format|
        format.html { redirect_to settings_path, notice: flash[:notice] }
        format.json { head :ok }
        format.turbo_stream
      end
    else
      respond_to do |format|
        format.html { render :index, status: :unprocessable_entity }
        format.json { render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity }
        format.turbo_stream { render :index, status: :unprocessable_entity }
      end
    end
  end

  def sync_now
    @user = current_user
    return head :unauthorized unless @user.has_up_bank_token?

    Rails.cache.delete("user/#{@user.id}/accounts")
    Rails.cache.delete("user/#{@user.id}/balance")

    SyncUpBankDataJob.perform_later(@user)
    @accounts = @user.accounts.to_a if @user.has_up_bank_token?
    flash[:notice] = I18n.t("flash.settings.sync_started")

    respond_to do |format|
      format.html { redirect_to settings_path, notice: flash[:notice] }
      format.json { render json: { status: "success", message: flash[:notice] }, status: :ok }
      format.turbo_stream
    end
  end

  def disconnect_bank
    @user = current_user
    # Clear token - explicitly clear both the attribute and ciphertext
    @user.up_bank_token = nil
    @user.up_bank_token_ciphertext = nil
    @user.save

    # Delete related accounts and transactions (hard delete)
    @user.accounts.destroy_all
    @user.transactions.destroy_all

    # Invalidate cache
    Rails.cache.delete("user/#{@user.id}/accounts")
    Rails.cache.delete("user/#{@user.id}/balance")

    @accounts = [] # No accounts after disconnect
    flash[:notice] = I18n.t("flash.settings.bank_disconnected")

    respond_to do |format|
      format.html { redirect_to settings_path, notice: flash[:notice] }
      format.json { head :ok }
      format.turbo_stream
    end
  end

  def destroy_account
    # Hard delete user and all related data
    # Need to delete in order to avoid foreign key violations
    user = current_user

    # Delete projects owned by user (and their related data)
    user.owned_projects.each do |project|
      project.project_expenses.destroy_all
      project.project_members.destroy_all
      project.destroy
    end

    # Delete project memberships
    user.project_members.destroy_all

    # Delete expense contributions
    user.expense_contributions.destroy_all

    # Delete accounts and transactions
    user.accounts.destroy_all
    user.transactions.destroy_all

    # Delete other related data
    user.planned_transactions.destroy_all
    user.goals.destroy_all
    user.filters.destroy_all
    user.notifications.destroy_all
    user.sessions.destroy_all
    user.webhook_events.destroy_all
    user.feedback_items.destroy_all

    # Clear Up Bank token
    user.update(up_bank_token: nil)

    # Sign out first (flash persists in session)
    sign_out user

    # Set flash message after sign out but before destroy
    flash[:notice] = I18n.t("flash.settings.account_deleted")

    # Destroy user
    user.destroy

    respond_to do |format|
      format.html { redirect_to root_path }
      format.json { head :ok }
    end
  end

  private

  def user_params
    params.require(:user).permit(:name, :dark_mode, :currency, :date_format, :avatar)
  end

  def password_params
    params.require(:user).permit(:current_password, :password, :password_confirmation)
  end
end
