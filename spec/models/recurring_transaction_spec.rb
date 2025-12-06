require "rails_helper"

RSpec.describe RecurringTransaction, type: :model do
  describe "associations" do
    it { should belong_to(:account) }
    it { should belong_to(:template_transaction).class_name("Transaction").optional }
  end

  describe "validations" do
    it { should validate_presence_of(:account_id) }
    it { should validate_presence_of(:amount) }
    it { should validate_presence_of(:frequency) }
    it { should validate_presence_of(:next_occurrence_date) }
    it { should validate_presence_of(:transaction_type) }
  end

  describe "enums" do
    it {
      should define_enum_for(:transaction_type).with_values(
        expense: "expense",
        income: "income"
      ).backed_by_column_of_type(:string)
    }
  end

  describe "scopes" do
    describe ".active" do
      it "returns only active recurring transactions" do
        active = create(:recurring_transaction, is_active: true)
        inactive = create(:recurring_transaction, is_active: false)

        expect(RecurringTransaction.active).to include(active)
        expect(RecurringTransaction.active).not_to include(inactive)
      end
    end

    describe ".upcoming" do
      it "returns recurring transactions with next_occurrence_date in the future" do
        upcoming = create(:recurring_transaction, next_occurrence_date: Date.current + 1.month)
        past = create(:recurring_transaction, next_occurrence_date: Date.current - 1.day)

        expect(RecurringTransaction.upcoming).to include(upcoming)
        expect(RecurringTransaction.upcoming).not_to include(past)
      end
    end

    describe ".due" do
      it "returns active recurring transactions that are due or overdue" do
        due = create(:recurring_transaction, is_active: true, next_occurrence_date: Date.current)
        overdue = create(:recurring_transaction, is_active: true, next_occurrence_date: Date.current - 1.day)
        upcoming = create(:recurring_transaction, is_active: true, next_occurrence_date: Date.current + 1.day)
        inactive = create(:recurring_transaction, is_active: false, next_occurrence_date: Date.current)

        due_transactions = RecurringTransaction.due
        expect(due_transactions).to include(due)
        expect(due_transactions).to include(overdue)
        expect(due_transactions).not_to include(upcoming)
        expect(due_transactions).not_to include(inactive)
      end
    end
  end

  describe "callbacks" do
    describe "before_validation :set_defaults" do
      it "sets is_active to true by default" do
        recurring = build(:recurring_transaction, is_active: nil)
        recurring.valid?
        expect(recurring.is_active).to be true
      end

      it "sets amount_tolerance to 1.0 by default" do
        recurring = build(:recurring_transaction, amount_tolerance: nil)
        recurring.valid?
        expect(recurring.amount_tolerance).to eq(1.0)
      end

      it "sets projection_months to 'indefinite' by default" do
        recurring = build(:recurring_transaction, projection_months: nil)
        recurring.valid?
        expect(recurring.projection_months).to eq("indefinite")
      end
    end

    describe "before_validation :normalize_amount" do
      context "for expense transactions" do
        it "makes amount negative if positive" do
          recurring = build(:recurring_transaction, transaction_type: "expense", amount: 50.0)
          recurring.valid?
          expect(recurring.amount).to be < 0
        end

        it "keeps amount negative if already negative" do
          recurring = build(:recurring_transaction, transaction_type: "expense", amount: -50.0)
          recurring.valid?
          expect(recurring.amount).to eq(-50.0)
        end
      end

      context "for income transactions" do
        it "makes amount positive if negative" do
          recurring = build(:recurring_transaction, transaction_type: "income", amount: -100.0)
          recurring.valid?
          expect(recurring.amount).to be > 0
        end

        it "keeps amount positive if already positive" do
          recurring = build(:recurring_transaction, transaction_type: "income", amount: 100.0)
          recurring.valid?
          expect(recurring.amount).to eq(100.0)
        end
      end
    end
  end

  describe "#matches?" do
    let(:account) { create(:account) }
    let(:recurring) do
      create(:recurring_transaction,
        account: account,
        amount: 25.50,
        transaction_type: "expense",
        amount_tolerance: 1.0)
    end

    context "when transaction matches pattern" do
      it "returns true for matching transaction" do
        transaction = create(:transaction,
          account: account,
          amount_cents: -2550, # $25.50 in cents, negative for expense
          status: "settled")

        expect(recurring.matches?(transaction)).to be true
      end

      it "returns true for transaction within tolerance" do
        transaction = create(:transaction,
          account: account,
          amount_cents: -2600, # $26.00, within $1.00 tolerance
          status: "settled")

        expect(recurring.matches?(transaction)).to be true
      end
    end

    context "when transaction does not match" do
      it "returns false for different account" do
        other_account = create(:account)
        transaction = create(:transaction, account: other_account, amount_cents: -2550)

        expect(recurring.matches?(transaction)).to be false
      end

      it "returns false for amount outside tolerance" do
        transaction = create(:transaction,
          account: account,
          amount_cents: -3000, # $30.00, outside $1.00 tolerance
          status: "settled")

        expect(recurring.matches?(transaction)).to be false
      end

      it "returns false for non-Transaction object" do
        expect(recurring.matches?("not a transaction")).to be false
      end
    end

    context "with merchant pattern" do
      let(:recurring) do
        create(:recurring_transaction,
          account: account,
          amount: 15.99,
          merchant_pattern: "NETFLIX",
          amount_tolerance: 1.0)
      end

      it "returns true when description matches pattern" do
        transaction = create(:transaction,
          account: account,
          description: "NETFLIX SUBSCRIPTION",
          amount_cents: -1599,
          status: "settled")

        expect(recurring.matches?(transaction)).to be true
      end

      it "returns false when description does not match pattern" do
        transaction = create(:transaction,
          account: account,
          description: "SPOTIFY SUBSCRIPTION",
          amount_cents: -1599,
          status: "settled")

        expect(recurring.matches?(transaction)).to be false
      end
    end

    context "with category" do
      let(:category) { create(:category, name: "Entertainment") }
      let(:recurring) do
        create(:recurring_transaction,
          account: account,
          amount: 25.50,
          category: "Entertainment",
          amount_tolerance: 1.0)
      end

      it "returns true when category matches" do
        transaction = create(:transaction,
          account: account,
          category: category,
          amount_cents: -2550,
          status: "settled")

        expect(recurring.matches?(transaction)).to be true
      end

      it "returns false when category does not match" do
        other_category = create(:category, name: "Shopping")
        transaction = create(:transaction,
          account: account,
          category: other_category,
          amount_cents: -2550,
          status: "settled")

        expect(recurring.matches?(transaction)).to be false
      end
    end
  end

  describe "#generate_planned_transactions" do
    let(:account) { create(:account) }
    let(:user) { account.user }
    let(:recurring) do
      create(:recurring_transaction,
        account: account,
        frequency: "monthly",
        next_occurrence_date: Date.current + 1.month,
        amount: 50.0,
        description: "Monthly Subscription")
    end

    it "generates planned transactions for the date range" do
      start_date = Date.current
      end_date = Date.current + 3.months

      planned_transactions = recurring.generate_planned_transactions(start_date, end_date)

      expect(planned_transactions.length).to be >= 2
      expect(planned_transactions.first.user).to eq(user)
      expect(planned_transactions.first.description).to eq("Monthly Subscription")
      expect(planned_transactions.first.amount_cents).to eq(-5000) # Negative for expense
    end

    it "does not create duplicates for existing planned transactions" do
      start_date = Date.current
      end_date = Date.current + 3.months

      # Create existing planned transaction
      create(:planned_transaction,
        user: user,
        description: "Monthly Subscription",
        planned_date: Date.current + 1.month)

      planned_transactions = recurring.generate_planned_transactions(start_date, end_date)

      # Should not create duplicate for the existing date
      expect(planned_transactions.length).to be >= 1
    end

    it "returns empty array for inactive recurring transaction" do
      recurring.update(is_active: false)
      planned_transactions = recurring.generate_planned_transactions(Date.current, Date.current + 3.months)

      expect(planned_transactions).to be_empty
    end

    it "handles different frequencies correctly" do
      weekly_recurring = create(:recurring_transaction, :weekly,
        account: account,
        next_occurrence_date: Date.current + 1.week)

      start_date = Date.current
      end_date = Date.current + 1.month

      planned_transactions = weekly_recurring.generate_planned_transactions(start_date, end_date)

      expect(planned_transactions.length).to be >= 4 # At least 4 weeks
    end
  end

  describe "#update_next_occurrence!" do
    let(:account) { create(:account) }

    it "updates next_occurrence_date to the next occurrence" do
      recurring = create(:recurring_transaction,
        account: account,
        frequency: "monthly",
        next_occurrence_date: Date.current)

      result = recurring.update_next_occurrence!

      expect(result).to be true
      expect(recurring.next_occurrence_date).to be > Date.current
      expect(recurring.next_occurrence_date.month).to eq((Date.current.month % 12) + 1)
    end

    it "returns false if schedule cannot be built" do
      recurring = create(:recurring_transaction,
        account: account,
        frequency: "invalid",
        next_occurrence_date: Date.current)

      result = recurring.update_next_occurrence!

      expect(result).to be false
    end
  end

  describe "#build_schedule" do
    let(:account) { create(:account) }

    it "builds a daily schedule" do
      recurring = create(:recurring_transaction,
        account: account,
        frequency: "daily",
        next_occurrence_date: Date.current)

      schedule = recurring.build_schedule
      expect(schedule).not_to be_nil
      expect(schedule.recurrence_rules.first).to be_a(IceCube::DailyRule)
    end

    it "builds a weekly schedule" do
      recurring = create(:recurring_transaction,
        account: account,
        frequency: "weekly",
        next_occurrence_date: Date.current)

      schedule = recurring.build_schedule
      expect(schedule).not_to be_nil
      expect(schedule.recurrence_rules.first).to be_a(IceCube::WeeklyRule)
    end

    it "builds a monthly schedule" do
      recurring = create(:recurring_transaction,
        account: account,
        frequency: "monthly",
        next_occurrence_date: Date.current)

      schedule = recurring.build_schedule
      expect(schedule).not_to be_nil
      expect(schedule.recurrence_rules.first).to be_a(IceCube::MonthlyRule)
    end

    it "builds a yearly schedule" do
      recurring = create(:recurring_transaction,
        account: account,
        frequency: "yearly",
        next_occurrence_date: Date.current)

      schedule = recurring.build_schedule
      expect(schedule).not_to be_nil
      expect(schedule.recurrence_rules.first).to be_a(IceCube::YearlyRule)
    end

    it "returns nil for invalid frequency" do
      recurring = create(:recurring_transaction,
        account: account,
        frequency: "invalid",
        next_occurrence_date: Date.current)

      schedule = recurring.build_schedule
      expect(schedule).to be_nil
    end

    it "returns nil if frequency is blank" do
      recurring = build(:recurring_transaction, account: account, frequency: nil)
      schedule = recurring.build_schedule
      expect(schedule).to be_nil
    end
  end

  describe "#due?" do
    let(:account) { create(:account) }

    it "returns true for due recurring transaction" do
      recurring = create(:recurring_transaction,
        account: account,
        is_active: true,
        next_occurrence_date: Date.current)

      expect(recurring.due?).to be true
    end

    it "returns true for overdue recurring transaction" do
      recurring = create(:recurring_transaction,
        account: account,
        is_active: true,
        next_occurrence_date: Date.current - 1.day)

      expect(recurring.due?).to be true
    end

    it "returns false for upcoming recurring transaction" do
      recurring = create(:recurring_transaction,
        account: account,
        is_active: true,
        next_occurrence_date: Date.current + 1.day)

      expect(recurring.due?).to be false
    end

    it "returns false for inactive recurring transaction" do
      recurring = create(:recurring_transaction,
        account: account,
        is_active: false,
        next_occurrence_date: Date.current)

      expect(recurring.due?).to be false
    end
  end

  describe "#occurrences" do
    let(:account) { create(:account) }

    it "returns occurrences in the date range" do
      recurring = create(:recurring_transaction,
        account: account,
        frequency: "monthly",
        next_occurrence_date: Date.current)

      start_date = Date.current
      end_date = Date.current + 3.months

      occurrences = recurring.occurrences(start_date, end_date)

      expect(occurrences.length).to be >= 3
      expect(occurrences.first).to be_a(Time)
    end

    it "returns empty array if schedule cannot be built" do
      recurring = create(:recurring_transaction,
        account: account,
        frequency: "invalid",
        next_occurrence_date: Date.current)

      occurrences = recurring.occurrences(Date.current, Date.current + 3.months)

      expect(occurrences).to be_empty
    end
  end
end

