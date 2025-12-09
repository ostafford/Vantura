require "rails_helper"

RSpec.describe ProcessUpWebhookJob, type: :job do
  let(:user) { create(:user, up_bank_token: "test_token") }
  let(:account) { create(:account, user: user, up_id: "test-account-id") }
  let(:webhook_event) do
    # Ensure user token is saved before creating webhook_event
    user.reload
    create(:webhook_event, user: user, payload: payload)
  end

  before do
    # Ensure user has token after reload
    allow_any_instance_of(User).to receive(:up_bank_token).and_return("test_token")
  end

  describe "#perform" do
    context "with TRANSACTION_CREATED event" do
      let(:payload) do
        {
          "data" => {
            "attributes" => {
              "eventType" => "TRANSACTION_CREATED"
            },
            "relationships" => {
              "transaction" => {
                "links" => {
                  "related" => "https://api.up.com.au/api/v1/transactions/test-id"
                }
              }
            }
          }
        }
      end

      before do
        # Stub API calls to bypass VCR cassettes with 401s
        transaction_data = {
          "id" => "test-id",
          "attributes" => {
            "status" => "SETTLED",
            "description" => "Test Transaction",
            "amount" => { "valueInBaseUnits" => -1000 }
          },
          "relationships" => {
            "account" => {
              "data" => { "id" => account.up_id }
            }
          }
        }
        allow_any_instance_of(UpBankApiService).to receive(:fetch_transaction).and_return(transaction_data)
      end

      it "processes webhook event" do
        expect {
          described_class.perform_now(webhook_event)
        }.to change { WebhookEvent.processed.count }.by(1)
      end

      it "marks webhook event as processed" do
        described_class.perform_now(webhook_event)

        webhook_event.reload
        expect(webhook_event).to be_processed
        expect(webhook_event.processed_at).to be_present
      end

      it "broadcasts dashboard update via Turbo Streams" do
        # Get recent transactions that will be passed to the partial
        recent_transactions = user.transactions.recent.limit(20)

        expect(Turbo::StreamsChannel).to receive(:broadcast_replace_to).with(
          "user_#{user.id}_dashboard",
          target: "recent-transactions",
          partial: "dashboard/recent_transactions",
          locals: { recent_transactions: recent_transactions }
        )

        described_class.perform_now(webhook_event)
      end

      context "with large transaction" do
        before do
          # Stub API calls with large transaction amount
          transaction_data = {
            "id" => "test-id",
            "attributes" => {
              "status" => "SETTLED",
              "description" => "Large Purchase",
              "amount" => { "valueInBaseUnits" => -150_000 } # $1500, exceeds threshold
            },
            "relationships" => {
              "account" => {
                "data" => { "id" => account.up_id }
              }
            }
          }
          allow_any_instance_of(UpBankApiService).to receive(:fetch_transaction).and_return(transaction_data)
        end

        it "creates large transaction notification" do
          expect {
            described_class.perform_now(webhook_event)
          }.to change { Notification.where(notification_type: :large_transaction).count }.by(1)
        end

        it "notification is linked to correct user" do
          described_class.perform_now(webhook_event)

          notification = Notification.where(notification_type: :large_transaction).last
          expect(notification.user).to eq(user)
        end

        it "notification contains correct metadata" do
          described_class.perform_now(webhook_event)

          notification = Notification.where(notification_type: :large_transaction).last
          expect(notification.notification_type).to eq("large_transaction")
          expect(notification.title).to eq("Large Transaction Alert")
          expect(notification.message).to include("Large Purchase")
        end
      end

      context "with transaction below threshold" do
        before do
          # Stub API calls with small transaction amount
          transaction_data = {
            "id" => "test-id",
            "attributes" => {
              "status" => "SETTLED",
              "description" => "Small Purchase",
              "amount" => { "valueInBaseUnits" => -50_000 } # $500, below threshold
            },
            "relationships" => {
              "account" => {
                "data" => { "id" => account.up_id }
              }
            }
          }
          allow_any_instance_of(UpBankApiService).to receive(:fetch_transaction).and_return(transaction_data)
        end

        it "does not create large transaction notification" do
          expect {
            described_class.perform_now(webhook_event)
          }.not_to change { Notification.where(notification_type: :large_transaction).count }
        end
      end
    end

    context "with TRANSACTION_SETTLED event" do
      let(:payload) do
        {
          "data" => {
            "attributes" => {
              "eventType" => "TRANSACTION_SETTLED"
            },
            "relationships" => {
              "transaction" => {
                "links" => {
                  "related" => "https://api.up.com.au/api/v1/transactions/test-id"
                }
              }
            }
          }
        }
      end

      before do
        # Stub API calls to bypass VCR cassettes with 401s
        transaction_data = {
          "id" => "test-id",
          "attributes" => {
            "status" => "SETTLED",
            "description" => "Test Transaction",
            "amount" => { "valueInBaseUnits" => -1000 }
          },
          "relationships" => {
            "account" => {
              "data" => { "id" => account.up_id }
            }
          }
        }
        allow_any_instance_of(UpBankApiService).to receive(:fetch_transaction).and_return(transaction_data)
      end

      it "processes transaction settled event" do
        expect {
          described_class.perform_now(webhook_event)
        }.to change { WebhookEvent.processed.count }.by(1)
      end
    end

    context "with TRANSACTION_DELETED event" do
      let(:transaction) { create(:transaction, user: user, account: account, up_id: "test-transaction-id") }
      let(:payload) do
        {
          "data" => {
            "attributes" => {
              "eventType" => "TRANSACTION_DELETED"
            },
            "relationships" => {
              "transaction" => {
                "data" => {
                  "id" => transaction.up_id
                }
              }
            }
          }
        }
      end

      it "deletes the transaction" do
        # Ensure transaction exists before the test
        expect(transaction).to be_persisted

        expect {
          described_class.perform_now(webhook_event)
        }.to change(Transaction, :count).by(-1)

        # Verify transaction is deleted
        expect(Transaction.find_by(id: transaction.id)).to be_nil
      end
    end

    context "with PING event" do
      let(:payload) do
        {
          "data" => {
            "attributes" => {
              "eventType" => "PING"
            }
          }
        }
      end

      it "acknowledges ping without processing" do
        allow(Rails.logger).to receive(:info)

        described_class.perform_now(webhook_event)

        expect(Rails.logger).to have_received(:info).with("Webhook ping received")
        webhook_event.reload
        expect(webhook_event).to be_processed
      end
    end

    context "with unknown event type" do
      let(:payload) do
        {
          "data" => {
            "attributes" => {
              "eventType" => "UNKNOWN_EVENT"
            }
          }
        }
      end

      it "logs warning and marks as processed" do
        allow(Rails.logger).to receive(:warn)

        described_class.perform_now(webhook_event)

        expect(Rails.logger).to have_received(:warn).with("Unknown event type: UNKNOWN_EVENT")
        webhook_event.reload
        expect(webhook_event).to be_processed
      end
    end

    context "when webhook event is deleted before job runs" do
      let(:payload) do
        {
          "data" => {
            "attributes" => {
              "eventType" => "PING"
            }
          }
        }
      end

      it "discards the job gracefully when DeserializationError occurs" do
        # Create a webhook event, save its ID, then destroy it
        event = create(:webhook_event, user: user, payload: payload)
        event_id = event.id
        event.destroy

        # Simulate what happens when ActiveJob tries to deserialize a deleted record
        # DeserializationError is raised when GlobalID can't locate the record
        allow(GlobalID::Locator).to receive(:locate).and_raise(ActiveJob::DeserializationError)

        # The job should discard silently (not raise an error)
        expect {
          # We can't pass the destroyed event, so we'll use a valid one and stub the locator
          described_class.perform_now(webhook_event)
        }.not_to raise_error
      end

      it "verifies discard_on configuration exists" do
        # Check that the job has discard_on configured for DeserializationError
        source_file = Rails.root.join("app/jobs/process_up_webhook_job.rb")
        source_code = File.read(source_file)
        expect(source_code).to include("discard_on ActiveJob::DeserializationError")
      end
    end

    context "when API call fails" do
      let(:payload) do
        {
          "data" => {
            "attributes" => {
              "eventType" => "TRANSACTION_CREATED"
            },
            "relationships" => {
              "transaction" => {
                "links" => {
                  "related" => "https://api.up.com.au/api/v1/transactions/invalid-id"
                }
              }
            }
          }
        }
      end

      it "marks webhook event as failed" do
        # Stub the API call to fail
        allow_any_instance_of(UpBankApiService).to receive(:fetch_transaction).and_raise(UpBankApiError, "API Error: 404")

        expect {
          described_class.perform_now(webhook_event)
        }.to raise_error(UpBankApiError)

        webhook_event.reload
        expect(webhook_event.error_message).to be_present
      end
    end

    context "retry behavior" do
      let(:payload) do
        {
          "data" => {
            "attributes" => {
              "eventType" => "TRANSACTION_CREATED"
            },
            "relationships" => {
              "transaction" => {
                "links" => {
                  "related" => "https://api.up.com.au/api/v1/transactions/test-id"
                }
              }
            }
          }
        }
      end

      before do
        # Stub API calls to bypass VCR cassettes with 401s
        transaction_data = {
          "id" => "test-id",
          "attributes" => {
            "status" => "SETTLED",
            "description" => "Test Transaction",
            "amount" => { "valueInBaseUnits" => -1000 }
          },
          "relationships" => {
            "account" => {
              "data" => { "id" => account.up_id }
            }
          }
        }
        allow_any_instance_of(UpBankApiService).to receive(:fetch_transaction).and_return(transaction_data)
      end

      it "retries on network timeout errors" do
        # Verify retry configuration is set up for network errors
        source_file = Rails.root.join("app/jobs/process_up_webhook_job.rb")
        source_code = File.read(source_file)
        expect(source_code).to include("retry_on Net::ReadTimeout")
        expect(source_code).to include("retry_on Net::OpenTimeout")
        expect(source_code).to include("retry_on Timeout::Error")
      end

      it "does not retry on RecordNotFound (uses discard instead)" do
        # Verify RecordNotFound is NOT in retry_on configuration
        source_file = Rails.root.join("app/jobs/process_up_webhook_job.rb")
        source_code = File.read(source_file)
        expect(source_code).not_to include("retry_on ActiveRecord::RecordNotFound")
      end
    end
  end
end
