require "rails_helper"

RSpec.describe "Webhooks", type: :request do
  describe "POST /webhooks/up" do
    let(:user) { create(:user) }
    let(:payload) { JSON.parse(file_fixture("webhook_transaction_created.json").read) }
    let(:secret_key) { "test_secret_key" }
    let(:signature) { compute_signature(payload.to_json) }

    before do
      ENV["UP_BANK_WEBHOOK_SECRET_KEY"] = secret_key
      # Ensure we have a user for fallback
      user
    end

    context "with valid signature" do
      it "creates a webhook event" do
        expect {
          post "/webhooks/up",
            params: payload.to_json,
            headers: {
              "Content-Type" => "application/json",
              "X-Up-Authenticity-Signature" => signature
            }
        }.to change(WebhookEvent, :count).by(1)
      end

      it "enqueues ProcessUpWebhookJob" do
        expect {
          post "/webhooks/up",
            params: payload.to_json,
            headers: {
              "Content-Type" => "application/json",
              "X-Up-Authenticity-Signature" => signature
            }
        }.to have_enqueued_job(ProcessUpWebhookJob)
      end

      it "returns 200 OK" do
        post "/webhooks/up",
          params: payload.to_json,
          headers: {
            "Content-Type" => "application/json",
            "X-Up-Authenticity-Signature" => signature
          }

        expect(response).to have_http_status(:ok)
      end

      it "stores correct event type" do
        post "/webhooks/up",
          params: payload.to_json,
          headers: {
            "Content-Type" => "application/json",
            "X-Up-Authenticity-Signature" => signature
          }

        webhook_event = WebhookEvent.last
        expect(webhook_event.event_type).to eq("TRANSACTION_CREATED")
      end

      context "when transaction exists in database" do
        let(:account) { create(:account, user: user) }
        let(:existing_transaction) { create(:transaction, user: user, account: account, up_id: "test-transaction-id") }

        before do
          # Update payload to reference existing transaction
          payload["data"]["relationships"]["transaction"]["links"]["related"] = "https://api.up.com.au/api/v1/transactions/test-transaction-id"
          existing_transaction
        end

        it "identifies user from existing transaction" do
          post "/webhooks/up",
            params: payload.to_json,
            headers: {
              "Content-Type" => "application/json",
              "X-Up-Authenticity-Signature" => compute_signature(payload.to_json)
            }

          webhook_event = WebhookEvent.last
          expect(webhook_event.user).to eq(user)
        end
      end

      context "when multiple users exist" do
        let(:user_with_token) { create(:user, :with_up_bank_token) }
        let(:user_without_token) { create(:user) }

        before do
          # Clear the outer user to test multiple users scenario
          User.destroy_all
          user_with_token
          user_without_token
        end

        it "prefers user with Up Bank token" do
          post "/webhooks/up",
            params: payload.to_json,
            headers: {
              "Content-Type" => "application/json",
              "X-Up-Authenticity-Signature" => compute_signature(payload.to_json)
            }

          webhook_event = WebhookEvent.last
          expect(webhook_event.user).to eq(user_with_token)
        end
      end

      context "with PING event" do
        let(:ping_payload) do
          {
            "data" => {
              "type" => "webhookEvent",
              "id" => "ping-id",
              "attributes" => {
                "eventType" => "PING",
                "createdAt" => "2024-01-01T00:00:00Z"
              }
            }
          }
        end

        let(:test_user) { create(:user) }

        before do
          # Clear all users to ensure test isolation
          User.destroy_all
          # Create a fresh user for this test (not using memoized 'user')
          test_user
        end

        it "uses fallback user identification" do
          post "/webhooks/up",
            params: ping_payload.to_json,
            headers: {
              "Content-Type" => "application/json",
              "X-Up-Authenticity-Signature" => compute_signature(ping_payload.to_json)
            }

          webhook_event = WebhookEvent.last
          expect(webhook_event.user).to eq(test_user)
          expect(webhook_event.event_type).to eq("PING")
        end
      end
    end

    context "with invalid signature" do
      let(:invalid_signature) { "invalid_signature" }

      it "raises SecurityError" do
        expect {
          post "/webhooks/up",
            params: payload.to_json,
            headers: {
              "Content-Type" => "application/json",
              "X-Up-Authenticity-Signature" => invalid_signature
            }
        }.to raise_error(SecurityError, "Invalid webhook signature")
      end
    end

    context "with missing signature" do
      it "raises SecurityError" do
        expect {
          post "/webhooks/up",
            params: payload.to_json,
            headers: {
              "Content-Type" => "application/json"
            }
        }.to raise_error(SecurityError, "Invalid webhook signature")
      end
    end

    context "with invalid JSON payload" do
      it "returns 200 OK (always returns 200 to Up Bank)" do
        post "/webhooks/up",
          params: "invalid json",
          headers: {
            "Content-Type" => "application/json",
            "X-Up-Authenticity-Signature" => compute_signature("invalid json")
          }

        expect(response).to have_http_status(:ok)
      end
    end

    private

    def compute_signature(body)
      secret = ENV.fetch("UP_BANK_WEBHOOK_SECRET_KEY")
      OpenSSL::HMAC.hexdigest("SHA256", secret, body)
    end
  end
end
