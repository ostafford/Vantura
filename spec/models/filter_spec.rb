require "rails_helper"

RSpec.describe Filter, type: :model do
  let(:user) { create(:user) }
  let(:account) { create(:account, user: user) }
  let(:category) { create(:category) }

  describe "associations" do
    it { should belong_to(:user) }
  end

  describe "validations" do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:user_id) }
  end

  describe "scopes" do
    describe ".recent" do
      it "returns filters ordered by created_at desc" do
        old_filter = create(:filter, user: user, created_at: 2.days.ago)
        new_filter = create(:filter, user: user, created_at: 1.day.ago)

        expect(Filter.recent.first).to eq(new_filter)
        expect(Filter.recent.last).to eq(old_filter)
      end
    end

    describe ".for_user" do
      it "returns filters for specific user" do
        user1 = create(:user)
        user2 = create(:user)
        filter1 = create(:filter, user: user1)
        filter2 = create(:filter, user: user2)

        expect(Filter.for_user(user1)).to include(filter1)
        expect(Filter.for_user(user1)).not_to include(filter2)
      end
    end
  end

  describe "#apply_to_transactions" do
    let(:filter) { create(:filter, user: user) }

    before do
      # Create test transactions
      create(:transaction, user: user, account: account, amount_cents: -5000, description: "Coffee shop")
      create(:transaction, user: user, account: account, amount_cents: -10000, description: "Grocery store")
      create(:transaction, user: user, account: account, amount_cents: 50000, description: "Salary")
    end

    context "with no filters" do
      it "returns all user transactions" do
        result = filter.apply_to_transactions
        expect(result.count).to eq(3)
      end
    end

    context "with category filter" do
      let(:filter) { create(:filter, :with_category_filter, user: user, filter_params: { "category_id" => category.id }) }

      before do
        create(:transaction, user: user, account: account, category: category, amount_cents: -3000)
      end

      it "filters by category" do
        result = filter.apply_to_transactions
        expect(result.count).to eq(1)
        expect(result.first.category).to eq(category)
      end
    end

    context "with transaction type filter" do
      let(:filter) { create(:filter, :with_transaction_type_filter, user: user) }

      it "filters expenses" do
        result = filter.apply_to_transactions
        expect(result.count).to eq(2)
        expect(result.all? { |t| t.amount_cents < 0 }).to be true
      end
    end

    context "with date range filter" do
      let(:filter) do
        create(:filter, :with_date_range, user: user, date_range: {
                 "start_date" => 2.days.ago.to_date.to_s,
                 "end_date" => Date.today.to_s
               })
      end

      before do
        create(:transaction, user: user, account: account, created_at: 3.days.ago)
        create(:transaction, user: user, account: account, created_at: 1.day.ago)
      end

      it "filters by date range" do
        result = filter.apply_to_transactions
        expect(result.count).to eq(4) # 3 from before block + 1 from 1 day ago
      end
    end

    context "with amount range filter" do
      let(:filter) do
        create(:filter, :with_amount_range, user: user, filter_params: {
                 "min_amount" => 5.0,
                 "max_amount" => 50.0
               })
      end

      it "filters by amount range" do
        result = filter.apply_to_transactions
        # Should match transactions with absolute value between 5.00 and 50.00 AUD
        # -5000 cents (50.00 AUD) and -10000 cents (100.00 AUD) should match
        # But -10000 is > 50.00, so only -5000 should match
        expect(result.count).to eq(1)
        expect(result.first.amount_cents.abs).to eq(5000)
      end
    end

    context "with search filter" do
      let(:filter) { create(:filter, :with_search, user: user, filter_params: { "search" => "coffee" }) }

      it "filters by description search" do
        result = filter.apply_to_transactions
        expect(result.count).to eq(1)
        expect(result.first.description).to include("Coffee")
      end
    end

    context "with account filter" do
      let(:other_account) { create(:account, user: user) }
      let(:filter) { create(:filter, user: user, filter_params: { "account_id" => account.id }) }

      before do
        create(:transaction, user: user, account: other_account)
      end

      it "filters by account" do
        result = filter.apply_to_transactions
        expect(result.all? { |t| t.account_id == account.id }).to be true
      end
    end
  end

  describe "#has_active_filters?" do
    context "with no filters" do
      let(:filter) { create(:filter, user: user) }

      it "returns false" do
        expect(filter.has_active_filters?).to be false
      end
    end

    context "with filter params" do
      let(:filter) { create(:filter, :with_category_filter, user: user) }

      it "returns true" do
        expect(filter.has_active_filters?).to be true
      end
    end

    context "with date range" do
      let(:filter) { create(:filter, :with_date_range, user: user) }

      it "returns true" do
        expect(filter.has_active_filters?).to be true
      end
    end
  end

  describe "#summary" do
    context "with category filter" do
      let(:filter) { create(:filter, :with_category_filter, user: user, filter_params: { "category_id" => category.id }) }

      it "includes category in summary" do
        expect(filter.summary).to include("Category:")
      end
    end

    context "with transaction type filter" do
      let(:filter) { create(:filter, :with_transaction_type_filter, user: user) }

      it "includes type in summary" do
        expect(filter.summary).to include("Type: expense")
      end
    end

    context "with date range" do
      let(:filter) { create(:filter, :with_date_range, user: user) }

      it "includes date range in summary" do
        expect(filter.summary).to include("Date:")
      end
    end
  end
end

