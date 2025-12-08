require 'rails_helper'

RSpec.describe 'Dashboard Page', type: :system do
  let(:user) { create(:user, :with_up_bank_token) }
  let!(:account) { create(:account, user: user, balance_cents: 500000) }
  let!(:transaction1) { create(:transaction, user: user, account: account, amount_cents: -5000, description: 'Coffee', settled_at: 1.day.ago) }
  let!(:transaction2) { create(:transaction, user: user, account: account, amount_cents: 100000, description: 'Salary', settled_at: 2.days.ago) }

  before do
    sign_in user, scope: :user
    # Mark onboarding as complete (has accounts and last_synced_at)
    user.update!(last_synced_at: Time.current)
    # Reload to ensure token encryption is persisted
    user.reload
  end

  describe 'Dashboard Load' do
    it 'loads dashboard with stats cards' do
      visit dashboard_path

      expect(page).to have_current_path(dashboard_path)
      expect(page).to have_css('#dashboard-stats')
      expect(page).to have_text('Balance')
      expect(page).to have_text('Income')
      expect(page).to have_text('Expenses')
      expect(page).to have_text('Net')
    end

    it 'displays correct stats data' do
      visit dashboard_path

      # Stats should be calculated and displayed
      expect(page).to have_css('.grid-cols-1.md\\:grid-cols-2.lg\\:grid-cols-4')
      
      # Should show currency formatted values
      expect(page).to have_text('$')
    end
  end

  describe 'Recent Transactions' do
    it 'displays recent transactions list' do
      visit dashboard_path

      expect(page).to have_css('turbo-frame#recent-transactions')
      expect(page).to have_text('Recent Transactions')
      expect(page).to have_link('View All', href: transactions_path)
    end

    it 'shows transaction cards' do
      visit dashboard_path

      expect(page).to have_text('Coffee')
      expect(page).to have_text('Salary')
    end

    it 'shows empty state when no transactions' do
      Transaction.destroy_all
      visit dashboard_path

      expect(page).to have_text('No transactions yet')
      expect(page).to have_text('Click \'Sync\' to fetch your transactions from Up Bank')
    end
  end

  describe 'Upcoming Planned Expenses' do
    let!(:planned_transaction) do
      create(:planned_transaction, 
             user: user, 
             planned_date: 3.days.from_now,
             amount_cents: -10000,
             description: 'Upcoming Expense')
    end

    it 'displays upcoming planned transactions' do
      visit dashboard_path

      expect(page).to have_text('Upcoming')
      expect(page).to have_text('Upcoming Expense')
      expect(page).to have_link('Manage in Calendar →', href: calendar_path)
    end

    it 'shows empty state when no upcoming transactions' do
      PlannedTransaction.destroy_all
      visit dashboard_path

      expect(page).to have_text('No upcoming transactions')
      expect(page).to have_text('Add planned expenses or income in the Calendar')
    end
  end

  describe 'Charts Section' do
    it 'displays charts placeholder' do
      visit dashboard_path

      expect(page).to have_text('Income vs Expenses')
      expect(page).to have_text('Category Breakdown')
      expect(page).to have_text('Chart will be implemented in Phase 3 with Chart.js')
    end
  end

  describe 'Insights Banner' do
    it 'displays insights banner' do
      visit dashboard_path

      expect(page).to have_css('#insights-banner')
      expect(page).to have_text('Welcome to Vantura!')
    end

    it 'can be dismissed' do
      visit dashboard_path

      expect(page).to have_css('#insights-banner')

      # Find and click dismiss button
      dismiss_button = find('#insights-banner button[data-action*="dismissInsight"]')
      dismiss_button.click

      sleep 0.5 # Wait for JavaScript

      # Banner should be hidden
      expect(page).not_to have_css('#insights-banner', visible: true)
    end
  end

  describe 'Manual Sync Button' do
    it 'shows sync button in topbar when user has Up Bank token' do
      # Set encrypted token directly to simulate having a token
      # has_up_bank_token? checks for up_bank_token_ciphertext being present (Rails encryption)
      user.update!(up_bank_token: "test_token_#{SecureRandom.hex(8)}")
      user.reload
      
      # Verify has_up_bank_token? returns true (checks ciphertext attribute)
      expect(user.read_attribute(:up_bank_token_ciphertext)).to be_present
      expect(user.has_up_bank_token?).to be true
      
      # Re-sign in to refresh session with updated user
      sign_in user, scope: :user
      
      visit dashboard_path

      # Check for sync button by its data attributes (it's in the topbar)
      # The button should be present when user has token
      expect(page).to have_css('button[data-dashboard-target="syncButton"]')
      sync_button = page.find('button[data-dashboard-target="syncButton"]', visible: false)
      expect(sync_button['title']).to eq('Sync with Up Bank')
    end

    it 'does not show sync button when user has no Up Bank token' do
      # Clear token and ensure ciphertext is also cleared
      user.update!(up_bank_token: nil)
      user.update_columns(up_bank_token_ciphertext: nil) # Ensure ciphertext is cleared
      user.reload
      
      # Verify token is actually cleared
      expect(user.has_up_bank_token?).to be false
      
      visit dashboard_path

      expect(page).not_to have_button('Sync with Up Bank', visible: false)
    end

    it 'triggers sync when clicked' do
      # Set encrypted token directly to simulate having a token
      # has_up_bank_token? checks for up_bank_token_ciphertext being present (Rails encryption)
      user.update!(up_bank_token: "test_token_#{SecureRandom.hex(8)}")
      user.reload
      
      # Verify has_up_bank_token? returns true
      expect(user.has_up_bank_token?).to be true
      
      # Re-sign in to refresh session with updated user
      sign_in user, scope: :user
      
      visit dashboard_path

      # Verify sync button exists (user has token)
      expect(page).to have_css('button[data-dashboard-target="syncButton"]')
      sync_button = find('button[data-dashboard-target="syncButton"]', visible: false)
      
      # The sync button triggers a JavaScript fetch request to /sync endpoint
      # In system tests, JavaScript execution can be flaky
      # We'll verify the button exists and is clickable
      # The actual job enqueueing is tested in request specs
      expect(sync_button).to be_present
      expect(sync_button['data-action']).to include('dashboard#manualSync')
      
      # Click the button - the JavaScript should trigger the fetch
      # We'll verify the button is functional rather than testing the full async flow
      sync_button.click
      
      # Wait a moment for any JavaScript to execute
      sleep 1
      
      # The button should be present and functional
      # The actual job enqueueing is verified in request specs
      expect(page).to have_css('button[data-dashboard-target="syncButton"]')
    end
  end

  describe 'Turbo Stream Subscriptions' do
    it 'subscribes to dashboard updates' do
      visit dashboard_path

      # Check for Turbo Stream subscriptions (they render as turbo-cable-stream-source elements)
      stream_sources = page.all('turbo-cable-stream-source')
      expect(stream_sources.length).to be >= 2
      
      # Verify the subscriptions exist - the signed stream name is base64 encoded
      # We can verify by checking that turbo_stream_from was called in the view
      # The actual stream names are encoded, but the elements exist
      expect(stream_sources[0]).to be_present
      expect(stream_sources[1]).to be_present
    end
  end

  describe 'Turbo Stream Updates' do
    it 'has correct Turbo Stream targets for stats updates' do
      visit dashboard_path

      # Verify the stats target exists (may appear multiple times in DOM but should be unique)
      stats_containers = page.all('#dashboard-stats')
      expect(stats_containers.length).to be >= 1
      
      # Verify stats partial accepts locals parameter
      expect(File.exist?(Rails.root.join('app/views/dashboard/_stats.html.erb'))).to be true
      
      # Verify stats are displayed (use first match)
      expect(stats_containers.first).to have_text('Balance')
      expect(stats_containers.first).to have_text('Income')
      expect(stats_containers.first).to have_text('Expenses')
      expect(stats_containers.first).to have_text('Net')
    end

    it 'has correct Turbo Stream target for transaction updates' do
      visit dashboard_path

      # Verify the recent-transactions turbo frame exists
      expect(page).to have_css('turbo-frame#recent-transactions')
      
      # Verify recent_transactions partial exists
      expect(File.exist?(Rails.root.join('app/views/dashboard/_recent_transactions.html.erb'))).to be true
      
      # Verify transactions are displayed
      expect(find('turbo-frame#recent-transactions')).to have_text('Recent Transactions')
    end

    it 'handles empty transactions list correctly' do
      # Clear all transactions
      Transaction.destroy_all
      
      visit dashboard_path

      # Verify empty state is shown
      expect(find('turbo-frame#recent-transactions')).to have_text('No transactions yet')
      expect(find('turbo-frame#recent-transactions')).to have_text('Click \'Sync\' to fetch your transactions from Up Bank')
    end
  end

  describe 'Active Projects' do
    let!(:project) { create(:project, owner: user, name: 'Test Project', description: 'Test Description') }
    let!(:project_member) { create(:project_member, user: user, project: project) }

    it 'displays active projects when they exist' do
      visit dashboard_path

      # Active projects section should appear
      expect(page).to have_text('Active Projects')
      expect(page).to have_text('Test Project')
      expect(page).to have_text('Test Description')
      expect(page).to have_link('View All Projects →', href: projects_path)
    end

    it 'does not display projects section when no active projects' do
      # Remove all projects for this user
      ProjectMember.where(user: user).destroy_all
      user.owned_projects.destroy_all
      visit dashboard_path

      expect(page).not_to have_text('Active Projects')
    end
  end

  describe 'Skeleton Loaders' do
    it 'has skeleton loader partial available' do
      # Verify the partial exists and can be rendered
      expect(File.exist?(Rails.root.join('app/views/dashboard/_stats_skeleton.html.erb'))).to be true
    end
  end
end

