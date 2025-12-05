require "rails_helper"

RSpec.describe "ProjectExpenses", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:project) { create(:project, owner: user) }
  let(:member_user) do
    u = create(:user)
    create(:project_member, project: project, user: u, can_create: true, can_edit: false)
    u
  end

  before do
    sign_in user, scope: :user
  end

  describe "GET /projects/:project_id/project_expenses" do
    let!(:expense1) { create(:project_expense, project: project) }
    let!(:expense2) { create(:project_expense, project: project) }

    it "lists all expenses for the project" do
      get "/projects/#{project.id}/project_expenses"

      expect(response).to have_http_status(:success)
      expenses = assigns(:project_expenses)
      expect(expenses).to include(expense1, expense2)
    end

    context "when user is not a member" do
      let(:other_project) { create(:project, owner: other_user) }

      it "prevents access" do
        get "/projects/#{other_project.id}/project_expenses"
        expect(response).to redirect_to(projects_path)
        expect(flash[:alert]).to include("don't have access")
      end
    end
  end

  describe "GET /projects/:project_id/project_expenses/:id" do
    let(:expense) { create(:project_expense, project: project) }

    it "shows the expense" do
      get "/projects/#{project.id}/project_expenses/#{expense.id}"
      expect(response).to have_http_status(:success)
      expect(assigns(:project_expense)).to eq(expense)
    end
  end

  describe "GET /projects/:project_id/project_expenses/new" do
    it "shows the new expense form" do
      get "/projects/#{project.id}/project_expenses/new"
      expect(response).to have_http_status(:success)
      expect(assigns(:project_expense)).to be_a_new(ProjectExpense)
    end
  end

  describe "POST /projects/:project_id/project_expenses" do
    context "with valid parameters" do
      it "creates a new expense" do
        expect {
          post "/projects/#{project.id}/project_expenses",
               params: {
                 project_expense: {
                   description: "Test Expense",
                   total_amount_cents: 5000,
                   total_amount_currency: "AUD",
                   expense_date: Date.current
                 }
               }
        }.to change(ProjectExpense, :count).by(1)

        expense = ProjectExpense.last
        expect(expense.description).to eq("Test Expense")
        expect(expense.total_amount_cents).to eq(5000)
        expect(expense.paid_by_user).to eq(user)
        expect(response).to redirect_to([ project, expense ])
        expect(flash[:notice]).to include("created successfully")
      end

      it "splits expense evenly among members when requested" do
        other_member = create(:user)
        create(:project_member, project: project, user: other_member)

        post "/projects/#{project.id}/project_expenses",
             params: {
               project_expense: {
                 description: "Shared Expense",
                 total_amount_cents: 10000,
                 total_amount_currency: "AUD",
                 expense_date: Date.current
               },
               split_evenly: "true"
             }

        expense = ProjectExpense.last
        # Should split between owner and the one member = 2 people
        expect(expense.expense_contributions.count).to eq(2)
        total_contributions = expense.expense_contributions.sum(:amount_cents)
        expect(total_contributions).to eq(10000)
        # Each person should pay half (5000 cents)
        expect(expense.expense_contributions.pluck(:amount_cents)).to all(eq(5000))
      end
    end

    context "with invalid parameters" do
      it "does not create expense and renders new" do
        expect {
          post "/projects/#{project.id}/project_expenses",
               params: {
                 project_expense: {
                   description: ""
                 }
               }
        }.not_to change(ProjectExpense, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to render_template(:new)
      end
    end
  end

  describe "GET /projects/:project_id/project_expenses/:id/edit" do
    let(:expense) { create(:project_expense, project: project) }

    it "shows the edit form for project editor" do
      get "/projects/#{project.id}/project_expenses/#{expense.id}/edit"
      expect(response).to have_http_status(:success)
      expect(assigns(:project_expense)).to eq(expense)
    end

    context "when user cannot edit" do
      before do
        sign_in member_user, scope: :user
      end

      it "prevents access" do
        get "/projects/#{project.id}/project_expenses/#{expense.id}/edit"
        expect(response).to redirect_to([ project, expense ])
        expect(flash[:alert]).to include("don't have permission to edit")
      end
    end
  end

  describe "PATCH /projects/:project_id/project_expenses/:id" do
    let(:expense) { create(:project_expense, project: project, description: "Old Description") }

    context "with valid parameters" do
      it "updates the expense" do
        patch "/projects/#{project.id}/project_expenses/#{expense.id}",
              params: {
                project_expense: {
                  description: "New Description",
                  total_amount_cents: 6000
                }
              }

        expense.reload
        expect(expense.description).to eq("New Description")
        expect(expense.total_amount_cents).to eq(6000)
        expect(response).to redirect_to([ project, expense ])
        expect(flash[:notice]).to include("updated successfully")
      end
    end

    context "with invalid parameters" do
      it "does not update and renders edit" do
        patch "/projects/#{project.id}/project_expenses/#{expense.id}",
              params: {
                project_expense: {
                  description: ""
                }
              }

        expense.reload
        expect(expense.description).to eq("Old Description")
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to render_template(:edit)
      end
    end

    context "when user cannot edit" do
      before do
        sign_in member_user, scope: :user
      end

      it "prevents update" do
        patch "/projects/#{project.id}/project_expenses/#{expense.id}",
              params: {
                project_expense: {
                  description: "Hacked Description"
                }
              }

        expense.reload
        expect(expense.description).to eq("Old Description")
        expect(response).to redirect_to([ project, expense ])
        expect(flash[:alert]).to include("don't have permission to edit")
      end
    end
  end

  describe "DELETE /projects/:project_id/project_expenses/:id" do
    let!(:expense) { create(:project_expense, project: project) }
    let!(:contribution) { create(:expense_contribution, project_expense: expense) }

    it "deletes the expense and cascades contributions" do
      expect {
        delete "/projects/#{project.id}/project_expenses/#{expense.id}"
      }.to change(ProjectExpense, :count).by(-1)
         .and change(ExpenseContribution, :count).by(-1)

      expect(response).to redirect_to(project_project_expenses_path(project))
      expect(flash[:notice]).to include("deleted successfully")
    end

    context "when user cannot edit" do
      before do
        sign_in member_user, scope: :user
      end

      it "prevents deletion" do
        expect {
          delete "/projects/#{project.id}/project_expenses/#{expense.id}"
        }.not_to change(ProjectExpense, :count)

        expect(response).to redirect_to([ project, expense ])
        expect(flash[:alert]).to include("don't have permission to edit")
      end
    end
  end
end

