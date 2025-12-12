require 'rails_helper'

RSpec.describe 'Settings', type: :system do
  let(:user) { create(:user) }

  before do
    sign_in user, scope: :user
  end

  describe 'Settings page loads' do
    it 'displays all sections' do
      visit settings_path

      expect(page).to have_content('Settings')
      expect(page).to have_content('Profile')
      expect(page).to have_content('Up Bank Integration')
      expect(page).to have_content('Preferences')
      expect(page).to have_content('Danger Zone')
    end
  end

  describe 'Profile section' do
    it 'can update name' do
      visit settings_path

      fill_in 'Name', with: 'New Name'
      click_button 'Save Changes'

      # Wait for Turbo Stream to append toast to toast-container
      expect(page).to have_css('#toast-container', wait: 5)
      expect(page).to have_content('Settings updated successfully', wait: 5)
      expect(user.reload.name).to eq('New Name')
    end

    it 'can upload avatar' do
      visit settings_path

      # Create a simple test image file
      test_image_path = Rails.root.join('spec', 'fixtures', 'files', 'test_avatar.png')
      FileUtils.mkdir_p(File.dirname(test_image_path))

      # Create a minimal valid PNG file (1x1 pixel)
      # PNG signature + minimal IHDR chunk
      png_data = [
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, # PNG signature
        0x00, 0x00, 0x00, 0x0D, # IHDR chunk length
        0x49, 0x48, 0x44, 0x52, # IHDR
        0x00, 0x00, 0x00, 0x01, # width: 1
        0x00, 0x00, 0x00, 0x01, # height: 1
        0x08, 0x02, 0x00, 0x00, 0x00, # bit depth, color type, etc.
        0x90, 0x77, 0x53, 0xDE, # CRC
        0x00, 0x00, 0x00, 0x00, # IEND chunk length
        0x49, 0x45, 0x4E, 0x44, # IEND
        0xAE, 0x42, 0x60, 0x82  # IEND CRC
      ].pack('C*')

      File.binwrite(test_image_path, png_data)

      attach_file('Avatar', test_image_path)
      click_button 'Save Changes'

      # Wait for Turbo Stream to append toast
      expect(page).to have_content('Settings updated successfully', wait: 5)
      expect(user.reload.avatar).to be_attached

      # Cleanup
      File.delete(test_image_path) if File.exist?(test_image_path)
    end

    it 'can change password' do
      visit settings_path

      click_button 'Change Password'

      # Wait for modal to appear
      expect(page).to have_field('Current Password')

      fill_in 'Current Password', with: user.password
      fill_in 'New Password', with: 'newpassword123'
      fill_in 'Confirm New Password', with: 'newpassword123'
      click_button 'Update Password'

      # Wait for Turbo Stream to append toast
      expect(page).to have_content('Password updated successfully', wait: 5)

      # Verify password was changed
      user.reload
      expect(user.valid_password?('newpassword123')).to be true
    end
  end

  describe 'Up Bank integration' do
    context 'when connected' do
      let(:user) { create(:user, :with_up_bank_token) }
      let!(:account) { create(:account, user: user, display_name: 'Spending Account', balance_cents: 234567) }

      before do
        user.update(last_synced_at: 5.minutes.ago)
      end

      it 'shows connection status' do
        visit settings_path

        expect(page).to have_content('Connected')
        expect(page).to have_content('Last Synced')
      end

      it 'shows connected accounts' do
        visit settings_path

        expect(page).to have_content('Connected Accounts')
        expect(page).to have_content('Spending Account')
      end

      it 'can sync now' do
        visit settings_path

        # Mock the sync job
        allow(SyncUpBankDataJob).to receive(:perform_later)

        click_button 'Sync Now'

        # Wait for Turbo Stream to append toast
        expect(page).to have_content('Sync started', wait: 5)
        expect(SyncUpBankDataJob).to have_received(:perform_later).with(user)
      end

      it 'can disconnect bank' do
        visit settings_path

        expect {
          accept_confirm do
            click_button 'Disconnect'
          end
        }.to change { user.accounts.count }.by(-1)
          .and change { user.transactions.count }.by(0) # No transactions in this test

        # Wait for Turbo Stream to append toast
        expect(page).to have_content('Up Bank account disconnected successfully', wait: 5)
        expect(user.reload.has_up_bank_token?).to be false
      end

      it 'can update token' do
        visit settings_path

        # The token field is a password field - find it by placeholder or field name
        # The field name is user[up_bank_token] but Capybara can find it by placeholder
        token_field = page.find_field(placeholder: 'Enter new token', wait: 2)
        token_field.fill_in(with: 'up:new_token_here_12345678901234567890')
        click_button 'Update Token'

        # Wait for Turbo Stream to append toast
        expect(page).to have_content('Up Bank token updated successfully', wait: 5)
      end
    end

    context 'when not connected' do
      it 'shows not connected state' do
        visit settings_path

        expect(page).to have_content('Not Connected')
        expect(page).to have_link('Connect Up Bank Account')
      end
    end
  end

  describe 'Preferences' do
    it 'can toggle dark mode' do
      visit settings_path

      check 'Dark Mode'
      click_button 'Save Preferences'

      # Wait for Turbo Stream to append toast
      expect(page).to have_content('Settings updated successfully', wait: 5)
      expect(user.reload.dark_mode).to be true
    end

    it 'can change currency' do
      visit settings_path

      select 'USD - US Dollar', from: 'Currency'
      click_button 'Save Preferences'

      # Wait for Turbo Stream to append toast
      expect(page).to have_content('Settings updated successfully', wait: 5)
      expect(user.reload.currency).to eq('USD')
    end

    it 'can change date format' do
      visit settings_path

      select 'MM/DD/YYYY', from: 'Date Format'
      click_button 'Save Preferences'

      # Wait for Turbo Stream to append toast
      expect(page).to have_content('Settings updated successfully', wait: 5)
      expect(user.reload.date_format).to eq('MM/DD/YYYY')
    end
  end

  describe 'Danger zone' do
    let!(:account) { create(:account, user: user) }
    let!(:transaction) { create(:transaction, user: user) }
    let!(:project) { create(:project, owner: user) }

    it 'can delete account with confirmation' do
      visit settings_path

      expect {
        accept_confirm do
          click_button 'Delete My Account'
        end
      }.to change(User, :count).by(-1)
        .and change(Account, :count).by(-1)
        .and change(Transaction, :count).by(-1)
        .and change(Project, :count).by(-1)

      # Wait for redirect to sign-in page
      expect(page).to have_current_path(root_path, wait: 5)

      # Flash message should appear in either flash-messages div or toast-container
      expect(page).to have_css('#flash-messages, #toast-container', wait: 2)
      expect(page).to have_content('Your account has been deleted', wait: 5)
      expect(User.exists?(user.id)).to be false
    end

    it 'requires confirmation before deleting' do
      visit settings_path

      dismiss_confirm do
        click_button 'Delete My Account'
      end

      # User should still exist
      expect(User.exists?(user.id)).to be true
      expect(page).to have_current_path(settings_path)
    end
  end
end
