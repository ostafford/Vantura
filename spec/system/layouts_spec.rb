require 'rails_helper'

RSpec.describe 'Layout Components', type: :system do
  let(:user) { create(:user) }

  before do
    sign_in user, scope: :user
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
      sidebar = page.find('#sidebar', visible: false)
      expect(sidebar[:class]).to include('-translate-x-full')

      # Click mobile menu button
      page.find('[data-drawer-toggle="sidebar"]').click

      # Wait for sidebar to appear
      sleep 0.5

      # Sidebar should be visible (no -translate-x-full class)
      sidebar = page.find('#sidebar', visible: true)
      expect(sidebar[:class]).not_to include('-translate-x-full')
    end
  end

  describe 'Topbar' do
    it 'renders with page title' do
      visit root_path

      expect(page).to have_css('nav.fixed.top-0')
      expect(page).to have_text('Dashboard')
    end

    it 'has dark mode toggle button' do
      visit root_path

      expect(page).to have_button('Toggle dark mode', visible: false)
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

      # Button should still be present after click
      expect(page).to have_button('Toggle dark mode', visible: false)
    end
  end

  describe 'Navigation Links' do
    it 'navigates to dashboard' do
      visit transactions_path
      click_link 'Dashboard'

      expect(page).to have_current_path(dashboard_path)
    end

    it 'navigates to transactions' do
      visit root_path
      click_link 'Transactions'

      expect(page).to have_current_path(transactions_path)
    end
  end
end
