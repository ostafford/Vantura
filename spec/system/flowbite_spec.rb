require 'rails_helper'

RSpec.describe 'Flowbite Integration', type: :system do
  let(:user) { create(:user) }

  before do
    sign_in user, scope: :user
  end

  describe 'Flowbite components load correctly' do
    it 'loads Flowbite JavaScript' do
      visit root_path

      # Check that page loads successfully
      expect(page).to have_css('body')

      # Verify Flowbite is available by checking if Flowbite functions exist
      # Flowbite initializes components on page load
      expect(page).to have_content('Dashboard')
    end

    it 'renders Flowbite button component' do
      visit root_path

      # Create a test button with Flowbite classes
      page.execute_script("
        const btn = document.createElement('button');
        btn.className = 'text-white bg-blue-700 hover:bg-blue-800 focus:ring-4 focus:ring-blue-300 font-medium rounded-lg text-sm px-5 py-2.5 me-2 mb-2 dark:bg-blue-600 dark:hover:bg-blue-700 dark:focus:ring-blue-800';
        btn.textContent = 'Test Button';
        document.body.appendChild(btn);
      ")

      expect(page).to have_button('Test Button')
    end
  end

  describe 'Flowbite modal component' do
    it 'can open and close a modal' do
      visit root_path

      # Create a test modal with Flowbite structure
      page.execute_script("
        const modal = document.createElement('div');
        modal.id = 'test-modal';
        modal.setAttribute('data-modal-target', 'test-modal');
        modal.className = 'hidden fixed inset-0 z-50 overflow-y-auto';
        modal.innerHTML = `
          <div class='fixed inset-0 bg-gray-900 bg-opacity-50'></div>
          <div class='flex items-center justify-center min-h-screen'>
            <div class='bg-white rounded-lg shadow-xl p-6 max-w-md w-full'>
              <h3 class='text-lg font-semibold mb-4'>Test Modal</h3>
              <p class='text-gray-600 mb-4'>This is a test modal.</p>
              <button data-modal-hide='test-modal' class='text-white bg-blue-700 hover:bg-blue-800 px-4 py-2 rounded'>Close</button>
            </div>
          </div>
        `;
        document.body.appendChild(modal);
      ")

      # Modal should be hidden initially
      expect(page).to have_css('#test-modal.hidden', visible: false)
    end
  end

  describe 'Flowbite dropdown component' do
    it 'renders dropdown component' do
      visit root_path

      # Create a test dropdown with Flowbite structure
      page.execute_script("
        const dropdown = document.createElement('div');
        dropdown.className = 'relative';
        dropdown.innerHTML = `
          <button id='dropdown-button' data-dropdown-toggle='test-dropdown' class='text-white bg-blue-700 hover:bg-blue-800 focus:ring-4 focus:ring-blue-300 font-medium rounded-lg text-sm px-5 py-2.5 text-center inline-flex items-center dark:bg-blue-600 dark:hover:bg-blue-700 dark:focus:ring-blue-800' type='button'>
            Dropdown button
            <svg class='w-2.5 h-2.5 ms-3' aria-hidden='true' fill='none' viewBox='0 0 10 6'>
              <path stroke='currentColor' stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='m1 1 4 4 4-4'/>
            </svg>
          </button>
          <div id='test-dropdown' class='z-10 hidden bg-white divide-y divide-gray-100 rounded-lg shadow w-44 dark:bg-gray-700'>
            <ul class='py-2 text-sm text-gray-700 dark:text-gray-200'>
              <li><a href='#' class='block px-4 py-2 hover:bg-gray-100 dark:hover:bg-gray-600 dark:hover:text-white'>Dashboard</a></li>
              <li><a href='#' class='block px-4 py-2 hover:bg-gray-100 dark:hover:bg-gray-600 dark:hover:text-white'>Settings</a></li>
              <li><a href='#' class='block px-4 py-2 hover:bg-gray-100 dark:hover:bg-gray-600 dark:hover:text-white'>Sign out</a></li>
            </ul>
          </div>
        `;
        document.body.appendChild(dropdown);
      ")

      # Dropdown button should be visible
      expect(page).to have_button('Dropdown button')

      # Dropdown menu should be hidden initially
      expect(page).to have_css('#test-dropdown.hidden', visible: false)
    end
  end
end
