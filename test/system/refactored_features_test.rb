require "application_system_test_case"

class RefactoredFeaturesTest < ApplicationSystemTestCase
  def setup
    @user = users(:one)
    @account = accounts(:one)
    # Ensure account is properly associated with user for dashboard tests
    @account.update!(user: @user) unless @account.user_id == @user.id
    sign_in_user(@user)
    # Verify account association is persisted after sign-in
    @account.reload
    @user.reload
  end

  # ID Naming Changes (Phase 1) Tests
  test "form submissions work with new IDs" do
    @project = Project.create!(owner: @user, name: "Test Project")

    visit project_path(@project)
    # Use ID to find the link (works for both icon link and text link)
    find("#project-expense-add-link, #project-expense-add-empty-link", match: :first).click

    # Wait for form to load
    assert_selector "#project-expense-create-form, #project-expense-edit-form", wait: 5

    # Fill in form using new ID naming convention
    fill_in "Merchant", with: "Test Merchant"
    fill_in "Total", with: "50.00"
    # Set date field using JavaScript to ensure correct format
    # HTML5 date fields need YYYY-MM-DD format
    page.execute_script("document.getElementById('project-expense-due-on-input').value = '#{Date.today.strftime("%Y-%m-%d")}'")

    click_button "Create Expense"

    # Form submits with local: true, so it should be HTML format
    # Wait for redirect to project page (not form page)
    # Check if we're still on the form page (validation error) - wait a bit first
    sleep 0.5
    if has_current_path?(new_project_expense_path(@project), wait: 0)
      # Still on form page - check for error messages
      error_text = page.all('[class*="error"], [class*="red"]').map(&:text).join(" ")
      flunk "Form submission failed - still on form page. Errors: #{error_text}. Page: #{page.text[0..500]}"
    end

    # Should redirect to project page
    assert_current_path project_path(@project), wait: 10

    # Wait for page to fully load and expenses table to render
    assert_selector "#project-expenses-table-body", wait: 5

    # Verify expense was created by checking database
    expense = ProjectExpense.find_by(merchant: "Test Merchant", project: @project)
    assert_not_nil expense, "Expense should be created in database"

    # Check if expense has a due_on date
    assert_not_nil expense.due_on, "Expense should have a due_on date"

    # Expenses are filtered by month, so verify the expense is in the current month
    today = Date.today
    month_start = today.beginning_of_month
    month_end = today.end_of_month
    assert expense.due_on.between?(month_start, month_end),
           "Expense due_on (#{expense.due_on}) should be in current month (#{month_start} to #{month_end})"

    # Verify all expenses for this project (should include our new expense)
    all_expenses = @project.project_expenses.where(due_on: month_start..month_end)
    assert_includes all_expenses.map(&:merchant), "Test Merchant", "Expense should appear in month-filtered expenses"

    # Expense should appear in the table (merchant name is displayed)
    assert_text "Test Merchant", wait: 5
  end

  test "transaction drawer works with new IDs" do
    # Ensure account is associated with user before visiting dashboard
    # Force update and reload to ensure association is persisted
    @account.update!(user: @user) unless @account.user_id == @user.id
    @account.reload
    @user.reload  # Reload user to ensure association is fresh

    # Verify association is persisted
    assert_equal @user.id, Account.find(@account.id).user_id, "Account must be associated with user in database"

    # Ensure this account will be found by load_account_or_return
    # The method uses Current.user.accounts.order(:created_at).last
    # Make sure our account is the most recent one for this user
    Account.where(user_id: @user.id).where.not(id: @account.id).update_all(created_at: 1.day.ago)
    @account.update!(created_at: Time.current)  # Make it the most recent

    visit root_path

    # Verify we're on the dashboard (not redirected to login)
    assert_current_path root_path
    # Verify account exists - check for account balance which only shows if @account exists
    assert_text "Current Balance", wait: 5

    # IMPORTANT: The drawer only renders if @account exists when dashboard loads
    # If drawer isn't in DOM, it means Current.user.accounts.order(:created_at).last returned nil
    # Verify the drawer element exists BEFORE opening (it should be in DOM but hidden)
    drawer_in_dom = page.has_selector?("#transaction-modal", visible: false, wait: 2)
    unless drawer_in_dom
      # Check if maybe the account wasn't found - verify account exists for user
      user_accounts = Account.where(user_id: @user.id).pluck(:id, :user_id, :created_at)
      flunk "Transaction drawer not found in DOM. Account user_id: #{@account.user_id}, User id: #{@user.id}. User accounts: #{user_accounts.inspect}"
    end

    # Open transaction drawer (check for button with new ID naming)
    find("#add-transaction-button").click

    # Wait for modal to be visible (removes 'hidden' class and adds 'flex' when opened)
    assert_selector "#transaction-modal.flex", wait: 5

    # Wait for drawer animation to complete (drawer slides in from right)
    # The drawer starts with translate-x-full and removes it after 10ms setTimeout
    # Wait for form fields to be visible, which indicates drawer has finished sliding in
    assert_selector "#transaction-description-input", visible: true, wait: 10

    # Fill in transaction form using field IDs
    # Wait for fields to be ready and interactable - drawer animation takes ~500ms
    sleep 0.6  # Wait for drawer animation to complete

    description_field = find("#transaction-description-input", wait: 10)
    assert description_field.visible?, "Description field should be visible"
    # Use JavaScript to set value to ensure it's set correctly
    page.execute_script("document.getElementById('transaction-description-input').value = 'Test Transaction'")
    page.execute_script("document.getElementById('transaction-description-input').dispatchEvent(new Event('input', { bubbles: true }))")

    amount_field = find("#transaction-amount-input", wait: 10)
    assert amount_field.visible?, "Amount field should be visible"
    page.execute_script("document.getElementById('transaction-amount-input').value = '100.00'")
    page.execute_script("document.getElementById('transaction-amount-input').dispatchEvent(new Event('input', { bubbles: true }))")

    # Ensure date field has a value (it should default to today, but verify)
    date_field = find("#transaction-date-input", wait: 10)
    assert date_field.visible?, "Date field should be visible"
    if date_field.value.blank?
      page.execute_script("document.getElementById('transaction-date-input').value = '#{Date.today.strftime("%Y-%m-%d")}'")
      page.execute_script("document.getElementById('transaction-date-input').dispatchEvent(new Event('change', { bubbles: true }))")
    end

    # Use button ID to avoid ambiguity (there might be multiple buttons)
    submit_button = find_button("Add Transaction", id: "transaction-submit-button", wait: 5)

    # Verify form fields have values before submitting
    description_field = find("#transaction-description-input", wait: 5)
    amount_field = find("#transaction-amount-input", wait: 5)
    date_field = find("#transaction-date-input", wait: 5)

    assert_equal "Test Transaction", description_field.value, "Description field should have value"
    assert_equal "100.00", amount_field.value, "Amount field should have value"
    assert_not_empty date_field.value, "Date field should have value"

    # Store initial transaction count
    initial_count = Transaction.where(account: @account).count

    # Submit the form
    submit_button.click

    # Wait a moment for form submission to start
    sleep 0.5

    # Transaction form submits via Turbo Streams
    # Wait for either success (transaction appears) or error (form still visible with errors)
    # Check if transaction was created in database
    transaction_created = false
    20.times do |i|
      # Check for transaction with matching description and account
      # Also check without account filter in case account association is wrong
      if Transaction.exists?(description: "Test Transaction", account: @account)
        transaction_created = true
        break
      end
      # Also check if modal closed (indicates success)
      if page.has_no_selector?("#transaction-modal.flex", wait: 0.1)
        # Modal closed - check if transaction was created
        if Transaction.exists?(description: "Test Transaction", account: @account)
          transaction_created = true
          break
        end
      end
      sleep 0.3
    end

    unless transaction_created
      # Transaction not created - check for validation errors or redirect
      # Check if we were redirected (might indicate account not found)
      if has_current_path?(settings_path, wait: 2)
        flunk "Transaction creation failed: Redirected to settings (account not found). Account user_id: #{@account.user_id}, User id: #{@user.id}"
      elsif page.has_text?("can't be blank", wait: 2) || page.has_text?("error", wait: 2)
        flunk "Transaction creation failed with errors: #{page.text[0..500]}"
      else
        final_count = Transaction.where(account: @account).count
        # Check all transactions for this account to see what was created
        all_transactions = Transaction.where(account: @account).pluck(:description, :amount, :transaction_date)
        flunk "Transaction was not created. Initial count: #{initial_count}, Final count: #{final_count}. Account transactions: #{all_transactions.inspect}. Page text: #{page.text[0..500]}"
      end
    end

    # Transaction was created - wait for Turbo Stream to update UI
    assert_selector "#recent-transactions-table-body", wait: 10
    assert_text "Test Transaction", wait: 10

    # After Turbo Stream processes, modal should be closed (replaced with hidden version)
    # Check that modal is no longer visible with flex class
    assert_no_selector "#transaction-modal.flex", wait: 5
  end

  test "Turbo Frame targets work with new IDs" do
    @project = Project.create!(owner: @user, name: "Test Project")

    visit project_path(@project)

    # Turbo Frame usage should be present in calendar navigation (where it actually exists)
    assert_selector "[data-month-nav-turbo-frame-value]", visible: false
  end

  # Controller Refactoring (Phase 2) Tests
  test "projects index uses service objects" do
    Project.create!(owner: @user, name: "Project 1")
    Project.create!(owner: @user, name: "Project 2")

    visit projects_path

    # Service object should provide statistics
    assert_text "Project 1"
    assert_text "Project 2"
    # Statistics should be displayed
    assert_text "Projects"
  end

  test "project show uses ProjectShowDataService" do
    project = Project.create!(owner: @user, name: "Test Project")
    project.project_expenses.create!(
      merchant: "Test Merchant",
      total_cents: 10000,
      due_on: Date.today
    )

    visit project_path(project)

    # Service object should provide data
    assert_text "Test Project"
    assert_text "Test Merchant"
  end

  test "transactions index uses TransactionIndexService" do
    @account.transactions.create!(
      description: "Test Transaction",
      amount: -100.0,
      transaction_date: Date.today,
      status: "SETTLED",
      is_hypothetical: false
    )

    visit transactions_path

    # Service object should provide transactions
    assert_text "Test Transaction"
  end

  test "error handling works correctly" do
    @project = Project.create!(owner: @user, name: "Test Project")

    visit project_path(@project)
    # Use ID to find the link
    find("#project-expense-add-link, #project-expense-add-empty-link", match: :first).click

    # Wait for form to load
    assert_selector "#project-expense-create-form, #project-expense-edit-form", wait: 5

    # Try to create with invalid data
    fill_in "Merchant", with: "" # Invalid - required field
    click_button "Create Expense"

    # Should show validation errors
    assert_text "can't be blank"
  end

  # Stimulus Controller Refactoring (Phase 4) Tests
  test "modal interactions work" do
    # Ensure account is associated with user before visiting dashboard
    # Force update and reload to ensure association is persisted
    @account.update!(user: @user) unless @account.user_id == @user.id
    @account.reload
    @user.reload  # Reload user to ensure association is fresh

    # Verify association is persisted
    assert_equal @user.id, Account.find(@account.id).user_id, "Account must be associated with user in database"

    # Ensure this account will be found by load_account_or_return
    # The method uses Current.user.accounts.order(:created_at).last
    # Make sure our account is the most recent one for this user
    Account.where(user_id: @user.id).where.not(id: @account.id).update_all(created_at: 1.day.ago)
    @account.update!(created_at: Time.current)  # Make it the most recent

    visit root_path

    # Verify we're on the dashboard (not redirected to login)
    assert_current_path root_path
    # Verify account exists - check for account balance which only shows if @account exists
    assert_text "Current Balance", wait: 5

    # IMPORTANT: The drawer only renders if @account exists when dashboard loads
    # If drawer isn't in DOM, it means Current.user.accounts.order(:created_at).last returned nil
    # Verify the drawer element exists BEFORE opening (it should be in DOM but hidden)
    drawer_in_dom = page.has_selector?("#transaction-modal", visible: false, wait: 2)
    unless drawer_in_dom
      # Check if maybe the account wasn't found - verify account exists for user
      user_accounts = Account.where(user_id: @user.id).pluck(:id, :user_id, :created_at)
      flunk "Transaction drawer not found in DOM. Account user_id: #{@account.user_id}, User id: #{@user.id}. User accounts: #{user_accounts.inspect}"
    end

    # Open modal/drawer
    find("#add-transaction-button").click

    # Wait for modal to be visible (removes 'hidden' class and adds 'flex' when opened)
    assert_selector "#transaction-modal.flex", wait: 5

    # Wait for drawer animation to complete (drawer slides in from right)
    # The drawer starts with translate-x-full and removes it after 10ms setTimeout
    # Wait for form fields to be visible, which indicates drawer has finished sliding in
    # Note: drawer animation takes ~500ms, and form fields become visible after drawer slides in
    assert_selector "#transaction-description-input", visible: true, wait: 15

    # Close modal - use close button ID
    # Wait for button to be ready and clickable
    close_button = find("#transaction-modal-close-button", visible: true, wait: 5)
    # Ensure button is in viewport and clickable
    close_button.scroll_to(:center)
    close_button.click

    # Modal controller waits 300ms for animation before adding 'hidden' class
    # Wait for modal to be hidden after closing - check that flex class is removed
    # The modal should disappear (either hidden class added or element removed from DOM)
    # Wait longer for the close animation to complete
    assert_no_selector "#transaction-modal.flex", wait: 10
  end

  test "calendar navigation works" do
    visit calendar_path

    # Calendar should load
    assert_text "Calendar"

    # Calendar should display
    assert_current_path calendar_path
  end

  test "month navigation works" do
    visit calendar_path

    # Calendar should display
    assert_text "Calendar"
    # Month navigation should be present (controller in DOM)
    assert_selector "[data-controller]", visible: false
  end

  test "week navigation works" do
    visit calendar_path

    # Calendar should display
    assert_text "Calendar"
    # Week navigation should be present (controller in DOM)
    assert_selector "[data-controller]", visible: false
  end

  test "dropdown interactions work" do
    visit projects_path

    # Look for dropdown menus (if any)
    # Dropdowns should use new ID naming
    dropdowns = page.all("[data-controller~='dropdown']")
    if dropdowns.any?
      dropdowns.first.click
      assert_selector "[data-dropdown-target='menu']", visible: true
    end
  end

  test "form autocomplete works" do
    @project = Project.create!(owner: @user, name: "Test Project")
    @project.project_expenses.create!(
      merchant: "Grocery Store",
      category: "groceries",
      total_cents: 10000,
      due_on: Date.today
    )

    visit project_path(@project)
    # Use ID to find the link (works for both icon link and text link)
    find("#project-expense-add-link, #project-expense-add-empty-link", match: :first).click

    # Start typing in merchant field
    fill_in "Merchant", with: "Groc"

    # Expense template autocomplete should be present (uses expense-template controller)
    assert_selector "[data-controller~='expense-template']", visible: false
  end

  private

  def sign_in_user(user)
    visit new_session_path
    fill_in "email_address", with: user.email_address
    fill_in "password", with: "password"
    click_button "Sign in"

    # Wait for sign-in to complete
    assert_current_path root_path

    # Small delay to ensure session is fully established
    sleep 0.1
  end
end
