require "rails_helper"

RSpec.describe Notification, type: :model do
  let(:user) { create(:user) }

  describe "associations" do
    it { should belong_to(:user) }
  end

  describe "validations" do
    it { should validate_presence_of(:user_id) }
    it { should validate_presence_of(:notification_type) }
    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:message) }
  end

  describe "enums" do
    it {
      should define_enum_for(:notification_type).backed_by_column_of_type(:string).with_values(
        transaction_created: "transaction_created",
        transaction_settled: "transaction_settled",
        large_transaction: "large_transaction",
        goal_progress: "goal_progress",
        goal_achieved: "goal_achieved",
        project_expense_added: "project_expense_added",
        project_expense_paid: "project_expense_paid",
        sync_completed: "sync_completed",
        sync_failed: "sync_failed",
        recurring_detected: "recurring_detected",
        system: "system"
      )
    }
  end

  describe "scopes" do
    describe ".unread" do
      it "returns unread notifications" do
        unread_notification = create(:notification, :unread, user: user)
        read_notification = create(:notification, :read, user: user)

        expect(Notification.unread).to include(unread_notification)
        expect(Notification.unread).not_to include(read_notification)
      end
    end

    describe ".read" do
      it "returns read notifications" do
        unread_notification = create(:notification, :unread, user: user)
        read_notification = create(:notification, :read, user: user)

        expect(Notification.read).to include(read_notification)
        expect(Notification.read).not_to include(unread_notification)
      end
    end

    describe ".active" do
      it "returns active notifications" do
        active_notification = create(:notification, user: user, is_active: true)
        inactive_notification = create(:notification, user: user, is_active: false)

        expect(Notification.active).to include(active_notification)
        expect(Notification.active).not_to include(inactive_notification)
      end
    end

    describe ".recent" do
      it "returns notifications ordered by created_at desc" do
        old_notification = create(:notification, user: user, created_at: 2.days.ago)
        new_notification = create(:notification, user: user, created_at: 1.day.ago)

        # Scope to user to avoid interference from other test data
        results = Notification.where(user: user).recent.to_a
        expect(results.first).to eq(new_notification)
        expect(results.last).to eq(old_notification)
      end
    end

    describe ".for_user" do
      it "returns notifications for specific user" do
        user1 = create(:user)
        user2 = create(:user)
        notification1 = create(:notification, user: user1)
        notification2 = create(:notification, user: user2)

        expect(Notification.for_user(user1)).to include(notification1)
        expect(Notification.for_user(user1)).not_to include(notification2)
      end
    end

    describe ".by_type" do
      it "returns notifications by type" do
        transaction_notification = create(:notification, user: user, notification_type: :transaction_created)
        sync_notification = create(:notification, :sync_completed, user: user)

        expect(Notification.by_type(:transaction_created)).to include(transaction_notification)
        expect(Notification.by_type(:transaction_created)).not_to include(sync_notification)
      end
    end
  end

  describe "#read?" do
    it "returns true when read_at is present" do
      notification = create(:notification, :read, user: user)
      expect(notification.read?).to be true
    end

    it "returns false when read_at is nil" do
      notification = create(:notification, :unread, user: user)
      expect(notification.read?).to be false
    end
  end

  describe "#unread?" do
    it "returns true when read_at is nil" do
      notification = create(:notification, :unread, user: user)
      expect(notification.unread?).to be true
    end

    it "returns false when read_at is present" do
      notification = create(:notification, :read, user: user)
      expect(notification.unread?).to be false
    end
  end

  describe "#mark_as_read!" do
    it "sets read_at to current time" do
      notification = create(:notification, :unread, user: user)
      expect { notification.mark_as_read! }.to change { notification.read_at }.from(nil)
      expect(notification.read_at).to be_within(1.second).of(Time.current)
    end

    it "does not update if already read" do
      notification = create(:notification, :read, user: user, read_at: 1.hour.ago)
      original_read_at = notification.read_at
      notification.mark_as_read!
      expect(notification.read_at).to eq(original_read_at)
    end
  end

  describe "#mark_as_unread!" do
    it "sets read_at to nil" do
      notification = create(:notification, :read, user: user)
      expect { notification.mark_as_unread! }.to change { notification.read_at }.to(nil)
    end
  end

  describe "#metadata_hash" do
    it "parses JSON metadata" do
      notification = create(:notification, user: user, metadata: '{"key": "value"}')
      expect(notification.metadata_hash).to eq({ "key" => "value" })
    end

    it "returns empty hash for blank metadata" do
      notification = create(:notification, user: user, metadata: nil)
      expect(notification.metadata_hash).to eq({})
    end

    it "returns empty hash for invalid JSON" do
      notification = create(:notification, user: user, metadata: "invalid json")
      expect(notification.metadata_hash).to eq({})
    end
  end

  describe "#metadata_hash=" do
    it "converts hash to JSON string" do
      notification = build(:notification, user: user)
      notification.metadata_hash = { "key" => "value" }
      expect(notification.metadata).to eq('{"key":"value"}')
    end
  end

  describe ".create_transaction_notification" do
    let(:account) { create(:account, user: user) }
    let(:transaction) { create(:transaction, user: user, account: account) }

    it "creates a transaction notification" do
      notification = Notification.create_transaction_notification(user, transaction)
      expect(notification).to be_persisted
      expect(notification.user).to eq(user)
      expect(notification.notification_type).to eq("transaction_created")
      expect(notification.metadata_hash["transaction_id"]).to eq(transaction.id)
    end
  end

  describe ".create_large_transaction_notification" do
    let(:account) { create(:account, user: user) }
    let(:transaction) { create(:transaction, user: user, account: account, amount_cents: -150_000) }

    it "creates a large transaction notification" do
      notification = Notification.create_large_transaction_notification(user, transaction)
      expect(notification).to be_persisted
      expect(notification.notification_type).to eq("large_transaction")
      expect(notification.metadata_hash["amount_cents"]).to eq(-150_000)
    end
  end

  describe ".create_sync_notification" do
    context "with success" do
      it "creates a sync completed notification" do
        notification = Notification.create_sync_notification(user, success: true, transaction_count: 5)
        expect(notification).to be_persisted
        expect(notification.notification_type).to eq("sync_completed")
        expect(notification.metadata_hash["transaction_count"]).to eq(5)
      end
    end

    context "with failure" do
      it "creates a sync failed notification" do
        notification = Notification.create_sync_notification(user, success: false, error_message: "API Error")
        expect(notification).to be_persisted
        expect(notification.notification_type).to eq("sync_failed")
        expect(notification.metadata_hash["error_message"]).to eq("API Error")
      end
    end
  end

  describe ".mark_all_as_read_for_user" do
    it "marks all unread notifications as read" do
      unread1 = create(:notification, :unread, user: user)
      unread2 = create(:notification, :unread, user: user)
      read = create(:notification, :read, user: user)

      Notification.mark_all_as_read_for_user(user)

      expect(unread1.reload.read_at).to be_present
      expect(unread2.reload.read_at).to be_present
      expect(read.reload.read_at).to be_present
    end
  end
end
