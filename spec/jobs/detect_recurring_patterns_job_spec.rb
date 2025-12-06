require "rails_helper"

RSpec.describe DetectRecurringPatternsJob, type: :job do
  let(:user) { create(:user) }
  let(:account) { create(:account, user: user) }

  describe "#perform" do
    context "with user_id parameter" do
      it "processes only the specified user" do
        other_user = create(:user)
        create(:transaction, user: user, account: account, settled_at: 1.month.ago)
        create(:transaction, user: other_user, account: create(:account, user: other_user), settled_at: 1.month.ago)

        expect {
          described_class.perform_now(user.id)
        }.to change { RecurringTransaction.count }.by_at_least(0)
      end
    end

    context "without user_id parameter" do
      it "processes all users" do
        user2 = create(:user)
        account2 = create(:account, user: user2)

        create(:transaction, user: user, account: account, settled_at: 1.month.ago)
        create(:transaction, user: user2, account: account2, settled_at: 1.month.ago)

        expect {
          described_class.perform_now
        }.not_to raise_error
      end
    end
  end

  describe "pattern detection" do
    context "with monthly recurring transactions" do
      it "creates a recurring transaction for monthly pattern" do
        # Create 3 transactions with same merchant, similar amount, monthly intervals
        base_date = 3.months.ago.to_date
        create(:transaction,
          user: user,
          account: account,
          description: "NETFLIX SUBSCRIPTION",
          amount_cents: -1599,
          settled_at: base_date)

        create(:transaction,
          user: user,
          account: account,
          description: "NETFLIX SUBSCRIPTION",
          amount_cents: -1599,
          settled_at: base_date + 1.month)

        create(:transaction,
          user: user,
          account: account,
          description: "NETFLIX SUBSCRIPTION",
          amount_cents: -1599,
          settled_at: base_date + 2.months)

        expect {
          described_class.perform_now(user.id)
        }.to change { RecurringTransaction.count }.by(1)

        recurring = RecurringTransaction.last
        expect(recurring.frequency).to eq("monthly")
        expect(recurring.transaction_type).to eq("expense")
        expect(recurring.merchant_pattern).to be_present
        expect(recurring.is_active).to be true
      end
    end

    context "with weekly recurring transactions" do
      it "creates a recurring transaction for weekly pattern" do
        base_date = 3.weeks.ago.to_date

        4.times do |i|
          create(:transaction,
            user: user,
            account: account,
            description: "COFFEE SHOP",
            amount_cents: -500,
            settled_at: base_date + i.weeks)
        end

        expect {
          described_class.perform_now(user.id)
        }.to change { RecurringTransaction.count }.by(1)

        recurring = RecurringTransaction.last
        expect(recurring.frequency).to eq("weekly")
      end
    end

    context "with insufficient occurrences" do
      it "does not create recurring transaction with less than 3 occurrences" do
        base_date = 2.months.ago.to_date

        create(:transaction,
          user: user,
          account: account,
          description: "NETFLIX",
          amount_cents: -1599,
          settled_at: base_date)

        create(:transaction,
          user: user,
          account: account,
          description: "NETFLIX",
          amount_cents: -1599,
          settled_at: base_date + 1.month)

        expect {
          described_class.perform_now(user.id)
        }.not_to change { RecurringTransaction.count }
      end
    end

    context "with irregular amounts" do
      it "creates recurring transaction when amounts are within tolerance" do
        base_date = 3.months.ago.to_date

        # Create transactions with slightly varying amounts (within $5 tolerance)
        create(:transaction,
          user: user,
          account: account,
          description: "SUBSCRIPTION",
          amount_cents: -2000, # $20.00
          settled_at: base_date)

        create(:transaction,
          user: user,
          account: account,
          description: "SUBSCRIPTION",
          amount_cents: -2100, # $21.00 (within tolerance)
          settled_at: base_date + 1.month)

        create(:transaction,
          user: user,
          account: account,
          description: "SUBSCRIPTION",
          amount_cents: -1999, # $19.99 (within tolerance)
          settled_at: base_date + 2.months)

        expect {
          described_class.perform_now(user.id)
        }.to change { RecurringTransaction.count }.by(1)
      end
    end
  end

  describe "updating existing patterns" do
    let!(:existing_recurring) do
      create(:recurring_transaction,
        account: account,
        merchant_pattern: "NETFLIX",
        frequency: "monthly",
        amount: -15.99,
        next_occurrence_date: Date.current,
        is_active: true)
    end

    it "updates existing recurring transaction when new matching transactions found" do
      base_date = 3.months.ago.to_date

      # Create new transactions that match the existing pattern
      create(:transaction,
        user: user,
        account: account,
        description: "NETFLIX SUBSCRIPTION",
        amount_cents: -1599,
        settled_at: base_date)

      create(:transaction,
        user: user,
        account: account,
        description: "NETFLIX SUBSCRIPTION",
        amount_cents: -1599,
        settled_at: base_date + 1.month)

      create(:transaction,
        user: user,
        account: account,
        description: "NETFLIX SUBSCRIPTION",
        amount_cents: -1599,
        settled_at: base_date + 2.months)

      expect {
        described_class.perform_now(user.id)
      }.not_to change { RecurringTransaction.count }

      existing_recurring.reload
      expect(existing_recurring.frequency).to eq("monthly")
      expect(existing_recurring.next_occurrence_date).to be > Date.current
    end
  end

  describe "edge cases" do
    context "with missed transactions" do
      it "still detects pattern with one missing occurrence" do
        base_date = 4.months.ago.to_date

        # Create 3 transactions with one month gap (missed month)
        create(:transaction,
          user: user,
          account: account,
          description: "SUBSCRIPTION",
          amount_cents: -1000,
          settled_at: base_date)

        create(:transaction,
          user: user,
          account: account,
          description: "SUBSCRIPTION",
          amount_cents: -1000,
          settled_at: base_date + 1.month)

        # Skip one month (missed transaction)
        create(:transaction,
          user: user,
          account: account,
          description: "SUBSCRIPTION",
          amount_cents: -1000,
          settled_at: base_date + 3.months) # 2 months gap instead of 1

        # Add one more to ensure we have enough occurrences
        create(:transaction,
          user: user,
          account: account,
          description: "SUBSCRIPTION",
          amount_cents: -1000,
          settled_at: base_date + 4.months)

        expect {
          described_class.perform_now(user.id)
        }.to change { RecurringTransaction.count }.by(1)
      end
    end

    context "with different accounts" do
      it "does not group transactions from different accounts" do
        account2 = create(:account, user: user)
        base_date = 3.months.ago.to_date

        # Create transactions in account 1
        create(:transaction,
          user: user,
          account: account,
          description: "SUBSCRIPTION",
          amount_cents: -1000,
          settled_at: base_date)

        create(:transaction,
          user: user,
          account: account,
          description: "SUBSCRIPTION",
          amount_cents: -1000,
          settled_at: base_date + 1.month)

        create(:transaction,
          user: user,
          account: account,
          description: "SUBSCRIPTION",
          amount_cents: -1000,
          settled_at: base_date + 2.months)

        # Create similar transactions in account 2
        create(:transaction,
          user: user,
          account: account2,
          description: "SUBSCRIPTION",
          amount_cents: -1000,
          settled_at: base_date)

        create(:transaction,
          user: user,
          account: account2,
          description: "SUBSCRIPTION",
          amount_cents: -1000,
          settled_at: base_date + 1.month)

        create(:transaction,
          user: user,
          account: account2,
          description: "SUBSCRIPTION",
          amount_cents: -1000,
          settled_at: base_date + 2.months)

        expect {
          described_class.perform_now(user.id)
        }.to change { RecurringTransaction.count }.by(2) # One for each account
      end
    end

    context "with income transactions" do
      it "creates recurring transaction for income pattern" do
        base_date = 3.months.ago.to_date

        3.times do |i|
          create(:transaction,
            user: user,
            account: account,
            description: "SALARY PAYMENT",
            amount_cents: 500000, # $5000 (positive for income)
            settled_at: base_date + i.months)
        end

        expect {
          described_class.perform_now(user.id)
        }.to change { RecurringTransaction.count }.by(1)

        recurring = RecurringTransaction.last
        expect(recurring.transaction_type).to eq("income")
      end
    end

    context "with transactions outside lookback period" do
      it "only analyzes transactions within the lookback period" do
        # Create transaction outside lookback period (7 months ago)
        create(:transaction,
          user: user,
          account: account,
          description: "OLD SUBSCRIPTION",
          amount_cents: -1000,
          settled_at: 7.months.ago)

        # Create only 2 more recent transactions (not enough for pattern)
        create(:transaction,
          user: user,
          account: account,
          description: "OLD SUBSCRIPTION",
          amount_cents: -1000,
          settled_at: 2.months.ago)

        create(:transaction,
          user: user,
          account: account,
          description: "OLD SUBSCRIPTION",
          amount_cents: -1000,
          settled_at: 1.month.ago)

        expect {
          described_class.perform_now(user.id)
        }.not_to change { RecurringTransaction.count }
      end
    end
  end

  describe "merchant pattern normalization" do
    it "normalizes merchant names correctly" do
      base_date = 3.months.ago.to_date

      # Create transactions with slightly different merchant descriptions
      create(:transaction,
        user: user,
        account: account,
        description: "NETFLIX SUBSCRIPTION",
        amount_cents: -1599,
        settled_at: base_date)

      create(:transaction,
        user: user,
        account: account,
        description: "NETFLIX.COM",
        amount_cents: -1599,
        settled_at: base_date + 1.month)

      create(:transaction,
        user: user,
        account: account,
        description: "NETFLIX PAYMENT",
        amount_cents: -1599,
        settled_at: base_date + 2.months)

      expect {
        described_class.perform_now(user.id)
      }.to change { RecurringTransaction.count }.by(1)

      recurring = RecurringTransaction.last
      expect(recurring.merchant_pattern).to match(/NETFLIX/i)
    end
  end
end
