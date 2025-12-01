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
    context "with TRANSACTION_CREATED event", :vcr do
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

      it "processes webhook event" do
        expect {
          described_class.perform_now(webhook_event.id)
        }.to change { WebhookEvent.processed.count }.by(1)
      end

      it "marks webhook event as processed" do
        described_class.perform_now(webhook_event.id)
        
        webhook_event.reload
        expect(webhook_event).to be_processed
        expect(webhook_event.processed_at).to be_present
      end

      it "broadcasts dashboard update via Turbo Streams" do
        expect(Turbo::StreamsChannel).to receive(:broadcast_update_to).with(
          "user_#{user.id}_dashboard",
          target: "recent_transactions",
          partial: "dashboard/recent_transactions",
          locals: { user: user }
        )
        
        described_class.perform_now(webhook_event.id)
      end
    end

    context "with TRANSACTION_SETTLED event", :vcr do
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

      it "processes transaction settled event" do
        expect {
          described_class.perform_now(webhook_event.id)
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
        expect {
          described_class.perform_now(webhook_event.id)
        }.to change(Transaction, :count).by(-1)
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
        expect(Rails.logger).to receive(:info).with("Webhook ping received")
        
        described_class.perform_now(webhook_event.id)
        
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
        expect(Rails.logger).to receive(:warn).with("Unknown event type: UNKNOWN_EVENT")
        
        described_class.perform_now(webhook_event.id)
        
        webhook_event.reload
        expect(webhook_event).to be_processed
      end
    end

    context "when webhook event not found" do
      it "raises ActiveRecord::RecordNotFound" do
        expect {
          described_class.perform_now(99999)
        }.to raise_error(ActiveRecord::RecordNotFound)
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
        expect {
          described_class.perform_now(webhook_event.id)
        }.to raise_error
        
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

      it "retries on ActiveRecord::RecordNotFound" do
        allow(WebhookEvent).to receive(:find).and_raise(ActiveRecord::RecordNotFound)
        
        expect {
          described_class.perform_now(webhook_event.id)
        }.to raise_error(ActiveRecord::RecordNotFound)
        
        expect(described_class).to have_been_enqueued
      end
    end
  end
end

