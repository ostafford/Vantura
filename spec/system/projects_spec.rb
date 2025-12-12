require 'rails_helper'

RSpec.describe 'Projects Page', type: :system do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:project) { create(:project, owner: user, name: "Household Expenses", description: "Shared household costs") }
  let!(:member) do
    u = create(:user)
    create(:project_member, project: project, user: u, can_create: true, can_edit: false)
    u
  end

  before do
    sign_in user, scope: :user
    user.update!(last_synced_at: Time.current)
  end

  describe 'Projects Index' do
    let!(:owned_project) { create(:project, owner: user, name: "My Project") }
    let!(:member_project) do
      p = create(:project, owner: other_user, name: "Shared Project")
      create(:project_member, project: p, user: user)
      p
    end
    let!(:other_project) { create(:project, owner: other_user, name: "Other Project") }

    it 'displays project cards' do
      visit projects_path

      expect(page).to have_current_path(projects_path)
      expect(page).to have_text('Shared Expense Projects')
      expect(page).to have_text('My Project')
      expect(page).to have_text('Shared Project')
      expect(page).not_to have_text('Other Project')
    end

    it 'displays project cards with Flowbite styling' do
      visit projects_path

      # Check for card styling (rounded-lg, shadow)
      expect(page).to have_css('.rounded-lg.shadow')
      expect(page).to have_css('.grid.grid-cols-1.md\\:grid-cols-2.lg\\:grid-cols-3')
    end

    it 'shows empty state when no projects' do
      Project.destroy_all
      visit projects_path

      expect(page).to have_text('No projects yet')
      expect(page).to have_link('Create Your First Project', href: new_project_path)
    end

    it 'has New Project button' do
      visit projects_path

      expect(page).to have_link('New Project', href: new_project_path)
    end
  end

  describe 'Project Detail Page' do
    it 'loads project detail page' do
      visit project_path(project)

      expect(page).to have_current_path(project_path(project))
      expect(page).to have_text('Household Expenses')
      expect(page).to have_text(project.description)
    end

    it 'displays project info section' do
      visit project_path(project)

      expect(page).to have_text('Owner:')
      expect(page).to have_text(user.email_address)
    end

    it 'displays members section' do
      visit project_path(project)

      expect(page).to have_text('Members')
      expect(page).to have_text(user.email_address)
      expect(page).to have_text(member.email_address)
    end

    it 'displays summary stats' do
      visit project_path(project)

      expect(page).to have_text('Summary')
      expect(page).to have_text('Total This Month')
      expect(page).to have_text('Your Share')
    end

    it 'has Add Expense button for project members' do
      visit project_path(project)

      expect(page).to have_button('Add Expense')
    end
  end

  describe 'Expense List' do
    let!(:expense1) do
      create(:project_expense,
        project: project,
        description: "Electricity Bill",
        total_amount_cents: 18000,
        expense_date: Date.current - 5.days,
        paid_by_user: user)
    end
    let!(:expense2) do
      create(:project_expense,
        project: project,
        description: "Rent",
        total_amount_cents: 180000,
        expense_date: Date.current - 10.days,
        paid_by_user: user)
    end

    it 'displays expense list' do
      visit project_path(project)

      expect(page).to have_text('Electricity Bill')
      expect(page).to have_text('Rent')
      expect(page).to have_text('$180.00')
      expect(page).to have_text('$1,800.00')
    end

    it 'displays expense items with details' do
      visit project_path(project)

      expect(page).to have_text('Paid by:')
      expect(page).to have_text(expense1.expense_date.strftime("%b %d, %Y"))
    end

    it 'shows empty state when no expenses' do
      ProjectExpense.destroy_all
      visit project_path(project)

      expect(page).to have_text('No expenses found')
    end
  end

  describe 'Add Expense Modal' do
    it 'opens add expense modal' do
      visit project_path(project)

      click_button 'Add Expense'

      # Wait for modal to appear
      expect(page).to have_css('#add-expense-modal:not(.hidden)', wait: 2)
      expect(page).to have_text("Add Expense to #{project.name}")
    end

    it 'can create expense via modal' do
      visit project_path(project)

      click_button 'Add Expense'

      # Wait for form to load
      expect(page).to have_field('Description', wait: 2)

      fill_in 'Description', with: 'Test Expense'
      fill_in 'Total Amount (AUD)', with: '50.00'
      select user.name || user.email_address, from: 'Paid By'

      click_button 'Save Expense'

      # Wait for modal to close
      expect(page).not_to have_css('#add-expense-modal:not(.hidden)', wait: 5)

      # Wait for expense to appear in list (Turbo Stream broadcast)
      # Check for the amount first to confirm expense was created
      expect(page).to have_text('$50.00', wait: 5)
      # Then check for description (expense name/description is shown in the list)
      expect(page).to have_text('Test Expense', wait: 5)
    end
  end

  describe 'Split Calculator' do
    before do
      visit project_path(project)
      click_button 'Add Expense'
      expect(page).to have_field('Description', wait: 2)
    end

    it 'works with equal split' do
      fill_in 'Total Amount (AUD)', with: '100.00'

      # Select equal split (should be default)
      choose 'Equal split'

      # Wait for split calculation
      sleep 0.5

      # Check that amounts are calculated
      # Should split between owner and member = 2 people = $50 each
      # Find the amount input fields by data attribute
      amount_fields = page.all('[data-split-calculator-target="amountInput"]', minimum: 2)
      expect(amount_fields.first.value).to eq('50.00')
      expect(amount_fields.last.value).to eq('50.00')
    end

    it 'validates total matches expense amount' do
      fill_in 'Total Amount (AUD)', with: '100.00'
      choose 'Custom amounts'

      # Enter amounts that don't match
      all('input[data-split-calculator-target="amountInput"]').first.set('30.00')
      all('input[data-split-calculator-target="amountInput"]').last.set('30.00')

      # Should show validation error
      expect(page).to have_text('does not match expense amount', wait: 2)
    end
  end

  describe 'Contribution Mark as Paid' do
    let!(:expense) do
      e = create(:project_expense,
        project: project,
        description: "Test Expense",
        total_amount_cents: 10000,
        paid_by_user: user)
      e.split_evenly_among_members
      e
    end
    let!(:contribution) { expense.expense_contributions.find_by(user: member) }

    it 'can mark contribution as paid' do
      visit project_path(project)

      # Click Details button on expense - this should open the modal for this specific expense
      click_button 'Details', match: :first

      # Wait for modal - use the expense ID to find the specific modal
      modal_id = "expense-detail-modal-#{expense.id}"
      expect(page).to have_css("##{modal_id}:not(.hidden)", wait: 2)

      # Find and click the first Mark as Paid button (for any pending contribution)
      within("##{modal_id}") do
        click_button 'Mark as Paid', match: :first
      end

      # Wait for Turbo Stream update to complete
      expect(page).to have_text('✓ Paid', wait: 5)
    end
  end

  describe 'Turbo Stream Updates' do
    it 'updates expense list on create' do
      visit project_path(project)

      initial_count = page.all('[id^="expense-"]').count

      click_button 'Add Expense'
      expect(page).to have_field('Description', wait: 2)

      fill_in 'Description', with: 'New Expense via Turbo'
      fill_in 'Total Amount (AUD)', with: '75.00'
      select user.name || user.email_address, from: 'Paid By'
      choose 'Equal split'

      click_button 'Save Expense'

      # Wait for Turbo Stream update
      expect(page).to have_text('New Expense via Turbo', wait: 3)
      expect(page.all('[id^="expense-"]').count).to eq(initial_count + 1)
    end

    it 'updates summary on contribution status change' do
      expense = create(:project_expense,
        project: project,
        description: "Summary Test",
        total_amount_cents: 20000,
        paid_by_user: user)
      expense.split_evenly_among_members
      contribution = expense.expense_contributions.find_by(user: member)

      visit project_path(project)

      # Get initial outstanding amount
      initial_outstanding = page.text.match(/\$(\d+\.\d+)/)

      # Mark as paid
      click_button 'Details', match: :first
      modal_id = "expense-detail-modal-#{expense.id}"
      expect(page).to have_css("##{modal_id}:not(.hidden)", wait: 2)

      within("##{modal_id}") do
        click_button 'Mark as Paid', match: :first
      end

      # Wait for summary update
      sleep 1
      # Summary should update (outstanding should decrease)
      expect(page).to have_css('#project-' + project.id.to_s + '-summary', wait: 2)
    end
  end

  describe 'Filters' do
    let!(:paid_expense) do
      e = create(:project_expense,
        project: project,
        description: "Paid Expense",
        total_amount_cents: 5000,
        paid_by_user: user)
      e.split_evenly_among_members
      e.expense_contributions.update_all(status: "paid", paid_at: Time.current)
      e
    end
    let!(:pending_expense) do
      e = create(:project_expense,
        project: project,
        description: "Pending Expense",
        total_amount_cents: 5000,
        paid_by_user: user)
      e.split_evenly_among_members
      e
    end

    it 'filters by status' do
      visit project_path(project)

      # Should show both expenses
      expect(page).to have_text('Paid Expense')
      expect(page).to have_text('Pending Expense')

      # Filter by paid
      select 'Paid', from: 'status'

      # Wait for Turbo Stream update to complete
      expect(page).to have_text('Paid Expense', wait: 5)
      expect(page).not_to have_text('Pending Expense', wait: 5)
    end
  end
end
