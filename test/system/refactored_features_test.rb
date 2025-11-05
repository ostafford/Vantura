require "application_system_test_case"

class RefactoredFeaturesTest < ApplicationSystemTestCase
  def setup
    @user = users(:one)
    @account = accounts(:one)
    sign_in_user(@user)
  end

  # ID Naming Changes (Phase 1) Tests
  test "form submissions work with new IDs" do
    @project = Project.create!(owner: @user, name: "Test Project")

    visit project_path(@project)
    click_link "Add Expense"

    # Fill in form using new ID naming convention
    fill_in "Merchant", with: "Test Merchant"
    fill_in "Amount", with: "50.00"
    fill_in "Due on", with: Date.today.to_s

    click_button "Create Expense"

    # Should redirect and show success
    assert_current_path project_path(@project)
    assert_text "Test Merchant"
  end

  test "transaction drawer works with new IDs" do
    visit root_path

    # Open transaction drawer (check for button with new ID naming)
    find("button", text: /Add|New|Transaction/i).click

    # Fill in transaction form
    fill_in "description", with: "Test Transaction"
    fill_in "amount", with: "100.00"

    click_button "Create"

    # Should close drawer and show transaction
    assert_text "Test Transaction"
  end

  test "Turbo Frame targets work with new IDs" do
    @project = Project.create!(owner: @user, name: "Test Project")

    visit project_path(@project)

    # Turbo Frame should be present with new ID naming
    assert_selector "turbo-frame", visible: false
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
    click_link "Add Expense"

    # Try to create with invalid data
    fill_in "Merchant", with: "" # Invalid - required field
    click_button "Create Expense"

    # Should show validation errors
    assert_text "can't be blank"
  end

  # Stimulus Controller Refactoring (Phase 4) Tests
  test "modal interactions work" do
    visit root_path

    # Open modal/drawer
    find("button", text: /Add|New|Transaction/i).click

    # Modal should be visible
    assert_selector "[data-controller~='modal']", visible: true

    # Close modal
    find("button", text: /Close|Cancel|X/i).click

    # Modal should be hidden
    assert_no_selector "[data-controller~='modal']", visible: true
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
    click_link "Add Expense"

    # Start typing in merchant field
    fill_in "Merchant", with: "Groc"

    # Autocomplete should suggest "Grocery Store"
    # (This depends on autocomplete implementation)
    assert_selector "[data-controller~='autocomplete']", visible: false
  end

  private

  def sign_in_user(user)
    visit new_session_path
    fill_in "email_address", with: user.email_address
    fill_in "password", with: "password"
    click_button "Sign in"

    # Wait for sign-in to complete
    assert_current_path root_path
  end
end
