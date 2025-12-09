require 'rails_helper'

RSpec.describe 'Dashboard Redirect to Onboarding', type: :system do
  let(:user) { create(:user) }

  before do
    sign_in user, scope: :user
  end

  describe 'when user needs onboarding' do
    it 'redirects to onboarding when user has no accounts' do
      # User has no accounts and no last_synced_at
      visit dashboard_path

      expect(page).to have_current_path(onboarding_connect_up_bank_path)
      expect(page).to have_text('Connect Your Up Bank Account')
    end

    it 'redirects to onboarding when user has no sync timestamp' do
      # Create account but no sync timestamp
      create(:account, user: user)
      visit dashboard_path

      expect(page).to have_current_path(onboarding_connect_up_bank_path)
    end

    it 'allows access to dashboard when onboarding is complete' do
      # User has accounts and sync timestamp
      create(:account, user: user)
      user.update!(last_synced_at: Time.current)

      visit dashboard_path

      expect(page).to have_current_path(dashboard_path)
      expect(page).to have_text('Dashboard')
    end
  end
end
