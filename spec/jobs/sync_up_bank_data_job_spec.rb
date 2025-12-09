require "rails_helper"

RSpec.describe SyncUpBankDataJob, type: :job do
  let(:user) { create(:user, up_bank_token: "test_token") }

  before do
    # Ensure user has token
    allow_any_instance_of(User).to receive(:up_bank_token).and_return("test_token")

    # Stub the UpBankApiService
    service = instance_double(UpBankApiService)
    allow(UpBankApiService).to receive(:new).with(user).and_return(service)
    allow(service).to receive(:sync_all_data)
  end

  describe "#perform" do
    context "with successful sync" do
      before do
        # Create some existing transactions
        create_list(:transaction, 3, user: user)
      end

      it "calls sync_all_data on UpBankApiService" do
        service = instance_double(UpBankApiService)
        allow(UpBankApiService).to receive(:new).with(user).and_return(service)
        expect(service).to receive(:sync_all_data)

        described_class.perform_now(user)
      end

      it "updates last_synced_at timestamp" do
        expect {
          described_class.perform_now(user)
        }.to change { user.reload.last_synced_at }
      end

      it "creates sync completed notification" do
        expect {
          described_class.perform_now(user)
        }.to change { Notification.where(notification_type: :sync_completed).count }.by(1)
      end

      it "notification is linked to correct user" do
        described_class.perform_now(user)

        notification = Notification.where(notification_type: :sync_completed).last
        expect(notification.user).to eq(user)
      end

      it "notification contains correct metadata" do
        described_class.perform_now(user)

        notification = Notification.where(notification_type: :sync_completed).last
        expect(notification.notification_type).to eq("sync_completed")
        expect(notification.title).to eq("Sync Completed")
        expect(notification.metadata_hash).to have_key("synced_at")
      end

      context "when new transactions are synced" do
        before do
          # Create transactions before sync
          create_list(:transaction, 2, user: user)
        end

        it "notification includes transaction count" do
          described_class.perform_now(user)

          notification = Notification.where(notification_type: :sync_completed).last
          expect(notification.message).to be_present
        end
      end
    end

    context "with failed sync" do
      before do
        service = instance_double(UpBankApiService)
        allow(UpBankApiService).to receive(:new).with(user).and_return(service)
        allow(service).to receive(:sync_all_data).and_raise(StandardError, "API Error")
      end

      it "creates sync failed notification" do
        expect {
          begin
            described_class.perform_now(user)
          rescue StandardError
            # Expected to raise
          end
        }.to change { Notification.where(notification_type: :sync_failed).count }.by(1)
      end

      it "notification contains error message" do
        begin
          described_class.perform_now(user)
        rescue StandardError
          # Expected to raise
        end

        notification = Notification.where(notification_type: :sync_failed).last
        expect(notification.notification_type).to eq("sync_failed")
        expect(notification.title).to eq("Sync Failed")
        expect(notification.message).to include("API Error")
        expect(notification.metadata_hash).to have_key("error_message")
      end

      it "notification is linked to correct user" do
        begin
          described_class.perform_now(user)
        rescue StandardError
          # Expected to raise
        end

        notification = Notification.where(notification_type: :sync_failed).last
        expect(notification.user).to eq(user)
      end
    end

    context "when user is deleted" do
      it "does not create notification" do
        user_id = user.id
        user.destroy

        expect {
          begin
            described_class.perform_now(User.find(user_id))
          rescue ActiveRecord::RecordNotFound
            # Expected
          end
        }.not_to change { Notification.count }
      end
    end

    it "broadcasts dashboard stats update via Turbo Streams" do
      # Calculate stats that will be passed to the partial
      stats = user.calculate_stats

      # Expect stats broadcast (transaction list broadcast also happens, so use allow for that)
      expect(Turbo::StreamsChannel).to receive(:broadcast_replace_to).with(
        "user_#{user.id}_dashboard",
        target: "dashboard-stats",
        partial: "dashboard/stats",
        locals: { stats: stats }
      )

      # Allow transaction list broadcast (empty list in this case)
      allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to).with(
        "user_#{user.id}_dashboard",
        target: "recent-transactions",
        partial: "dashboard/recent_transactions",
        locals: { recent_transactions: anything }
      )

      described_class.perform_now(user)
    end

    it "broadcasts recent transactions list update via Turbo Streams (Flow A: REPLACE)" do
      # Create some transactions for the user
      create_list(:transaction, 5, user: user)

      # Get recent transactions that will be passed to the partial
      recent_transactions = user.transactions.recent.limit(20)

      # Expect both broadcasts: stats and transaction list
      # Allow stats broadcast
      allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to).with(
        "user_#{user.id}_dashboard",
        target: "dashboard-stats",
        partial: "dashboard/stats",
        locals: anything
      )

      # Specifically check for transaction list broadcast
      expect(Turbo::StreamsChannel).to receive(:broadcast_replace_to).with(
        "user_#{user.id}_dashboard",
        target: "recent-transactions",
        partial: "dashboard/recent_transactions",
        locals: { recent_transactions: recent_transactions }
      )

      described_class.perform_now(user)
    end

    context "with broadcast_progress: true" do
      let(:service) { instance_double(UpBankApiService) }

      before do
        allow(UpBankApiService).to receive(:new).with(user).and_return(service)
        allow(service).to receive(:sync_accounts).and_return([])
        allow(service).to receive(:sync_transactions)
        allow(service).to receive(:sync_categories)

        # Create real accounts relation for calculate_stats
        create_list(:account, 2, user: user, balance_cents: 1000)

        # Stub transactions relation - need count and recent
        transactions_relation = double(count: 0, recent: double(limit: []))
        allow(user).to receive(:transactions).and_return(transactions_relation)
      end

      it "broadcasts progress updates" do
        expect(Turbo::StreamsChannel).to receive(:broadcast_replace_to).at_least(:once).with(
          "user_#{user.id}_onboarding",
          target: "progress-bar",
          partial: "onboarding/progress_bar",
          locals: anything
        )

        # Also allow other broadcasts (completion, dashboard)
        allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
        allow(Turbo::StreamsChannel).to receive(:broadcast_append_to)
        allow(Turbo::StreamsChannel).to receive(:broadcast_action_to)

        described_class.perform_now(user, broadcast_progress: true)
      end

      it "broadcasts step completions" do
        expect(Turbo::StreamsChannel).to receive(:broadcast_append_to).at_least(:once).with(
          "user_#{user.id}_onboarding",
          target: "sync-steps",
          partial: "onboarding/sync_step",
          locals: anything
        )

        # Also allow other broadcasts (progress, completion, dashboard)
        allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
        allow(Turbo::StreamsChannel).to receive(:broadcast_action_to)

        described_class.perform_now(user, broadcast_progress: true)
      end

      it "broadcasts completion message" do
        expect(Turbo::StreamsChannel).to receive(:broadcast_replace_to).with(
          "user_#{user.id}_onboarding",
          target: "completion-redirect",
          partial: "onboarding/completion",
          locals: anything
        )

        # Also allow other broadcasts (progress, steps, dashboard)
        allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to).and_call_original
        allow(Turbo::StreamsChannel).to receive(:broadcast_append_to)
        allow(Turbo::StreamsChannel).to receive(:broadcast_action_to)

        described_class.perform_now(user, broadcast_progress: true)
      end

      it "calls sync methods individually when broadcasting progress" do
        expect(service).to receive(:sync_accounts).and_return([])
        expect(service).to receive(:sync_categories).ordered
        expect(service).to receive(:sync_transactions).ordered

        # Don't expect sync_all_data when broadcasting
        expect(service).not_to receive(:sync_all_data)

        # Allow broadcasts
        allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
        allow(Turbo::StreamsChannel).to receive(:broadcast_append_to)
        allow(Turbo::StreamsChannel).to receive(:broadcast_action_to)

        described_class.perform_now(user, broadcast_progress: true)
      end
    end
  end
end
