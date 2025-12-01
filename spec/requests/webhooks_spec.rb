require "rails_helper"

RSpec.describe "Webhooks", type: :request do
  describe "POST /webhooks/up" do
    let(:user) { create(:user) }
    let(:payload) { JSON.parse(file_fixture("webhook_transaction_created.json").read) }
    let(:secret_key) { "test_secret_key" }
    let(:signature) { compute_signature(payload.to_json) }

    before do
      allow(User).to receive(:first).and_return(user)
      ENV["UP_BANK_WEBHOOK_SECRET_KEY"] = secret_key
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

