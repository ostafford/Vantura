require "rails_helper"

RSpec.describe "PlannedTransactions", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:account) { create(:account, user: user) }

  before do
    sign_in user, scope: :user
  end

  describe "GET /planned_transactions" do
    let!(:planned_transaction1) { create(:planned_transaction, user: user, planned_date: 5.days.from_now) }
    let!(:planned_transaction2) { create(:planned_transaction, user: user, planned_date: 10.days.from_now) }
    let!(:other_user_transaction) { create(:planned_transaction, user: other_user) }

    it "lists only current user's planned transactions" do
      get "/planned_transactions"

      expect(response).to have_http_status(:success)
      transactions = assigns(:planned_transactions)
      expect(transactions).to include(planned_transaction1, planned_transaction2)
      expect(transactions).not_to include(other_user_transaction)
    end

    it "orders by planned_date ascending" do
      get "/planned_transactions"

      transactions = assigns(:planned_transactions)
      expect(transactions.first).to eq(planned_transaction1)
      expect(transactions.last).to eq(planned_transaction2)
    end
  end

  describe "GET /planned_transactions/:id" do
    let(:planned_transaction) { create(:planned_transaction, user: user) }

    it "shows the planned transaction" do
      get "/planned_transactions/#{planned_transaction.id}"
      expect(response).to have_http_status(:success)
      expect(assigns(:planned_transaction)).to eq(planned_transaction)
    end

    it "prevents access to other user's planned transaction" do
      other_transaction = create(:planned_transaction, user: other_user)

      get "/planned_transactions/#{other_transaction.id}"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /planned_transactions/new" do
    it "shows the new planned transaction form" do
      get "/planned_transactions/new"
      expect(response).to have_http_status(:success)
      expect(assigns(:planned_transaction)).to be_a_new(PlannedTransaction)
      expect(assigns(:planned_transaction).user).to eq(user)
    end
  end

  describe "POST /planned_transactions" do
    context "with valid parameters" do
      it "creates a new planned transaction" do
        expect {
          post "/planned_transactions",
               params: {
                 planned_transaction: {
                   description: "Test Planned Expense",
                   amount_cents: 5000,
                   amount_currency: "AUD",
                   planned_date: 7.days.from_now,
                   transaction_type: "expense"
                 }
               }
        }.to change(PlannedTransaction, :count).by(1)

        planned_transaction = PlannedTransaction.last
        expect(planned_transaction.description).to eq("Test Planned Expense")
        expect(planned_transaction.amount_cents).to eq(5000)
        expect(planned_transaction.user).to eq(user)
        expect(response).to redirect_to(planned_transaction)
        expect(flash[:notice]).to include("created successfully")
      end

      it "saves recurrence pattern when provided" do
        post "/planned_transactions",
             params: {
               planned_transaction: {
                 description: "Monthly Subscription",
                 amount_cents: 1000,
                 amount_currency: "AUD",
                 planned_date: Date.current,
                 transaction_type: "expense",
                 is_recurring: true,
                 recurrence_pattern: "monthly",
                 recurrence_rule: "FREQ=MONTHLY"
               }
             }

        planned_transaction = PlannedTransaction.last
        expect(planned_transaction.is_recurring).to be true
        expect(planned_transaction.recurrence_pattern).to eq("monthly")
        expect(planned_transaction.recurrence_rule).to eq("FREQ=MONTHLY")
      end
    end

    context "with invalid parameters" do
      it "does not create and renders new" do
        expect {
          post "/planned_transactions",
               params: {
                 planned_transaction: {
                   description: ""
                 }
               }
        }.not_to change(PlannedTransaction, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to render_template(:new)
      end
    end
  end

  describe "GET /planned_transactions/:id/edit" do
    let(:planned_transaction) { create(:planned_transaction, user: user) }

    it "shows the edit form" do
      get "/planned_transactions/#{planned_transaction.id}/edit"
      expect(response).to have_http_status(:success)
      expect(assigns(:planned_transaction)).to eq(planned_transaction)
    end
  end

  describe "PATCH /planned_transactions/:id" do
    let(:planned_transaction) { create(:planned_transaction, user: user, description: "Old Description") }

    context "with valid parameters" do
      it "updates the planned transaction" do
        patch "/planned_transactions/#{planned_transaction.id}",
              params: {
                planned_transaction: {
                  description: "New Description",
                  amount_cents: 6000
                }
              }

        planned_transaction.reload
        expect(planned_transaction.description).to eq("New Description")
        expect(planned_transaction.amount_cents).to eq(6000)
        expect(response).to redirect_to(planned_transaction)
        expect(flash[:notice]).to include("updated successfully")
      end
    end

    context "with invalid parameters" do
      it "does not update and renders edit" do
        patch "/planned_transactions/#{planned_transaction.id}",
              params: {
                planned_transaction: {
                  description: ""
                }
              }

        planned_transaction.reload
        expect(planned_transaction.description).to eq("Old Description")
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to render_template(:edit)
      end
    end

    it "prevents updating other user's planned transaction" do
      other_transaction = create(:planned_transaction, user: other_user)

      patch "/planned_transactions/#{other_transaction.id}",
            params: {
              planned_transaction: {
                description: "Hacked Description"
              }
            }

      expect(response).to have_http_status(:not_found)
      other_transaction.reload
      expect(other_transaction.description).not_to eq("Hacked Description")
    end
  end

  describe "DELETE /planned_transactions/:id" do
    let!(:planned_transaction) { create(:planned_transaction, user: user) }

    it "deletes the planned transaction" do
      expect {
        delete "/planned_transactions/#{planned_transaction.id}"
      }.to change(PlannedTransaction, :count).by(-1)

      expect(response).to redirect_to(planned_transactions_path)
      expect(flash[:notice]).to include("deleted successfully")
    end

    it "prevents deleting other user's planned transaction" do
      other_transaction = create(:planned_transaction, user: other_user)

      expect {
        delete "/planned_transactions/#{other_transaction.id}"
      }.not_to change(PlannedTransaction, :count)

      expect(response).to have_http_status(:not_found)
    end
  end
end
