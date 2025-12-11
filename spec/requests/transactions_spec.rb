require "rails_helper"

RSpec.describe "Transactions", type: :request do
  let(:user) { create(:user) }
  let(:account) { create(:account, user: user) }
  let(:category) { create(:category) }
  let(:other_user) { create(:user) }
  let(:other_account) { create(:account, user: other_user) }

  before do
    sign_in user, scope: :user
  end

  describe "GET /transactions" do
    let!(:transaction1) do
      create(:transaction,
             user: user,
             account: account,
             category: category,
             description: "Coffee purchase",
             amount_cents: -500,
             created_at: 5.days.ago,
             settled_at: 5.days.ago,
             created_at_up: 5.days.ago)
    end

    let!(:transaction2) do
      create(:transaction,
             user: user,
             account: account,
             description: "Salary deposit",
             amount_cents: 5000,
             created_at: 3.days.ago,
             settled_at: 3.days.ago,
             created_at_up: 3.days.ago)
    end

    let!(:transaction3) do
      create(:transaction,
             user: user,
             account: account,
             category: category,
             description: "Lunch",
             amount_cents: -1500,
             created_at: 1.day.ago,
             settled_at: 1.day.ago,
             created_at_up: 1.day.ago)
    end

    let!(:other_user_transaction) do
      create(:transaction, user: other_user, account: other_account)
    end

    it "returns only current user's transactions" do
      get "/transactions"

      expect(response).to have_http_status(:success)
      expect(assigns(:transactions).count).to eq(3)
      expect(assigns(:transactions)).not_to include(other_user_transaction)
    end

    it "orders transactions by most recent first" do
      get "/transactions"

      transactions = assigns(:transactions)
      expect(transactions.first).to eq(transaction3)
      expect(transactions.last).to eq(transaction1)
    end

    context "with category filter" do
      it "filters by category_id" do
        get "/transactions", params: { category_id: category.id }

        transactions = assigns(:transactions)
        expect(transactions.count).to eq(2)
        expect(transactions).to include(transaction1, transaction3)
        expect(transactions).not_to include(transaction2)
      end
    end

    context "with transaction_type filter" do
      it "filters income transactions" do
        get "/transactions", params: { transaction_type: "income" }

        transactions = assigns(:transactions)
        expect(transactions.count).to eq(1)
        expect(transactions).to include(transaction2)
      end

      it "filters expense transactions" do
        get "/transactions", params: { transaction_type: "expense" }

        transactions = assigns(:transactions)
        expect(transactions.count).to eq(2)
        expect(transactions).to include(transaction1, transaction3)
      end
    end

    context "with date range filter" do
      it "filters by start_date" do
        get "/transactions", params: { start_date: 2.days.ago.to_date.to_s }

        transactions = assigns(:transactions)
        expect(transactions.count).to eq(1)
        expect(transactions).to include(transaction3)
      end

      it "filters by end_date" do
        get "/transactions", params: { end_date: 2.days.ago.to_date.to_s }

        transactions = assigns(:transactions)
        expect(transactions.count).to eq(2)
        expect(transactions).to include(transaction1, transaction2)
      end

      it "filters by both start_date and end_date" do
        get "/transactions",
            params: {
              start_date: 4.days.ago.to_date.to_s,
              end_date: 2.days.ago.to_date.to_s
            }

        transactions = assigns(:transactions)
        expect(transactions.count).to eq(1)
        expect(transactions).to include(transaction2)
      end
    end

    context "with amount range filter" do
      it "filters by min_amount" do
        get "/transactions", params: { min_amount: 10.0 }

        transactions = assigns(:transactions)
        expect(transactions.count).to eq(2)
        expect(transactions).to include(transaction2, transaction3)
      end

      it "filters by max_amount" do
        get "/transactions", params: { max_amount: 10.0 }

        transactions = assigns(:transactions)
        expect(transactions.count).to eq(1)
        expect(transactions).to include(transaction1)
      end

      it "filters by both min_amount and max_amount" do
        get "/transactions",
            params: {
              min_amount: 10.0,
              max_amount: 20.0
            }

        transactions = assigns(:transactions)
        expect(transactions.count).to eq(1)
        expect(transactions).to include(transaction3)
      end
    end

    context "with search filter" do
      it "searches in description" do
        get "/transactions", params: { search: "Coffee" }

        transactions = assigns(:transactions)
        expect(transactions.count).to eq(1)
        expect(transactions).to include(transaction1)
      end

      it "searches case-insensitively" do
        get "/transactions", params: { search: "coffee" }

        transactions = assigns(:transactions)
        expect(transactions.count).to eq(1)
        expect(transactions).to include(transaction1)
      end
    end

    context "with account filter" do
      it "filters by account_id" do
        get "/transactions", params: { account_id: account.id }

        transactions = assigns(:transactions)
        expect(transactions.count).to eq(3)
        expect(transactions).to all(have_attributes(account: account))
      end
    end

    context "with multiple filters" do
      it "applies all filters together" do
        get "/transactions",
            params: {
              category_id: category.id,
              transaction_type: "expense",
              min_amount: 10.0
            }

        transactions = assigns(:transactions)
        expect(transactions.count).to eq(1)
        expect(transactions).to include(transaction3)
      end
    end
  end

  describe "GET /transactions/:id" do
    let(:transaction) { create(:transaction, user: user, account: account) }

    it "shows the transaction" do
      get "/transactions/#{transaction.id}"

      expect(response).to have_http_status(:success)
      expect(assigns(:transaction)).to eq(transaction)
    end

    it "prevents access to other user's transaction" do
      other_transaction = create(:transaction, user: other_user, account: other_account)

      get "/transactions/#{other_transaction.id}"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /transactions/:id" do
    let(:transaction) { create(:transaction, user: user, account: account, category: nil, notes: nil) }
    let(:new_category) { create(:category) }
    let(:tag1) { create(:tag) }
    let(:tag2) { create(:tag) }

    it "updates transaction notes" do
      patch "/transactions/#{transaction.id}",
            params: {
              transaction: {
                notes: "This is a test note"
              }
            }

      expect(response).to redirect_to(transaction_path(transaction))
      transaction.reload
      expect(transaction.notes).to eq("This is a test note")
      expect(flash[:notice]).to include("Transaction updated successfully")
    end

    it "updates transaction category" do
      patch "/transactions/#{transaction.id}",
            params: {
              transaction: {
                category_id: new_category.id
              }
            }

      expect(response).to redirect_to(transaction_path(transaction))
      transaction.reload
      expect(transaction.category).to eq(new_category)
    end

    it "updates transaction tags" do
      patch "/transactions/#{transaction.id}",
            params: {
              transaction: {
                tag_ids: [ tag1.id, tag2.id ]
              }
            }

      expect(response).to redirect_to(transaction_path(transaction))
      transaction.reload
      expect(transaction.tags).to contain_exactly(tag1, tag2)
    end

    it "updates multiple fields at once" do
      patch "/transactions/#{transaction.id}",
            params: {
              transaction: {
                category_id: new_category.id,
                notes: "Updated notes",
                tag_ids: [ tag1.id ]
              }
            }

      expect(response).to redirect_to(transaction_path(transaction))
      transaction.reload
      expect(transaction.category).to eq(new_category)
      expect(transaction.notes).to eq("Updated notes")
      expect(transaction.tags).to contain_exactly(tag1)
    end

    it "allows removing all tags" do
      transaction.tag_ids = [ tag1.id, tag2.id ]
      transaction.save!

      patch "/transactions/#{transaction.id}",
            params: {
              transaction: {
                tag_ids: [ "" ]
              }
            }

      expect(response).to redirect_to(transaction_path(transaction))
      transaction.reload
      expect(transaction.tags).to be_empty
    end

    it "prevents updating other user's transaction" do
      other_transaction = create(:transaction, user: other_user, account: other_account)

      patch "/transactions/#{other_transaction.id}",
            params: {
              transaction: {
                notes: "Hacked note"
              }
            }

      expect(response).to have_http_status(:not_found)
      other_transaction.reload
      expect(other_transaction.notes).not_to eq("Hacked note")
    end
  end
end
