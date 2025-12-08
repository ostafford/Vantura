require 'rails_helper'

RSpec.describe 'Layout Components', type: :system do
  let(:user) { create(:user, :with_up_bank_token) }
  let!(:account) { create(:account, user: user) }

  before do
    sign_in user, scope: :user
    # Mark onboarding as complete (has accounts and last_synced_at)
    user.update!(last_synced_at: Time.current)
    user.reload
  end

  describe 'Sidebar' do
    it 'renders on desktop view' do
      visit root_path

      expect(page).to have_css('#sidebar')
      expect(page).to have_link('Dashboard', href: dashboard_path)
      expect(page).to have_link('Transactions', href: transactions_path)
      expect(page).to have_link('Calendar', href: calendar_path)
      expect(page).to have_link('Projects', href: projects_path)
      expect(page).to have_link('Settings', href: settings_path)
    end

    it 'can be toggled on mobile view' do
      page.driver.resize(375, 667) # Mobile size
      visit root_path

      # Sidebar should be hidden initially on mobile (has -translate-x-full class)
      sidebar = page.find('#sidebar', visible: :all)
      expect(sidebar[:class]).to include('-translate-x-full')

      # Click mobile menu button
      page.find('[data-drawer-toggle="sidebar"]').click

      # Wait for sidebar to appear
      sleep 0.5

      # Sidebar should be visible (no -translate-x-full class)
      sidebar = page.find('#sidebar', visible: :all)
      expect(sidebar[:class]).not_to include('-translate-x-full')
    end
  end

  describe 'Topbar' do
    it 'renders with page title' do
      visit root_path

      expect(page).to have_css('nav.fixed.top-0')
      # Check for page title text in the topbar
      expect(page).to have_css('h1', text: 'Dashboard')
    end

    it 'has dark mode toggle button' do
      visit root_path

      # Dark mode button has sr-only text, check by data-controller attribute
      expect(page).to have_css('button[data-controller="dark-mode"]')
    end
  end

  describe 'Dark Mode Toggle' do
    it 'has a working dark mode toggle button' do
      visit root_path

      # Verify the toggle button exists (use first button with dark-mode controller)
      toggle_button = page.find('button[data-controller="dark-mode"]', match: :first)
      expect(toggle_button).to be_present

      # Verify it's clickable
      expect(toggle_button).to be_visible

      # Click it to verify it doesn't error
      toggle_button.click
      sleep 0.2 # Wait for JavaScript

      # Button should still be present after click (check by data-controller)
      expect(page).to have_css('button[data-controller="dark-mode"]')
    end
  end

  describe 'Navigation Links' do
    it 'navigates to dashboard' do
      # Ensure we have a transaction to visit transactions_path
      create(:transaction, user: user, account: account)
      visit transactions_path

      # Find and click Dashboard link in sidebar
      within('#sidebar') do
        click_link 'Dashboard'
      end

      expect(page).to have_current_path(dashboard_path)
    end

    it 'navigates to transactions' do
      visit root_path

      # Find and click Transactions link in sidebar
      within('#sidebar') do
        click_link 'Transactions'
      end

      expect(page).to have_current_path(transactions_path)
    end
  end
end
