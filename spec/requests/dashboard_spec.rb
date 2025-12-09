require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  let(:user) { create(:user, :with_up_bank_token) }

  before do
    sign_in user, scope: :user
  end

  describe "POST /sync" do
    context "with HTML format" do
      it "enqueues sync job and redirects with notice" do
        expect {
          post "/sync"
        }.to have_enqueued_job(SyncUpBankDataJob).with(user)
      end

      it "redirects to dashboard with success message" do
        post "/sync"

        expect(response).to redirect_to(dashboard_path)
        expect(flash[:notice]).to be_present
      end

      it "invalidates user cache" do
        # Set cache values
        Rails.cache.write("user/#{user.id}/accounts", [])
        Rails.cache.write("user/#{user.id}/balance", 1000)

        post "/sync"

        expect(Rails.cache.read("user/#{user.id}/accounts")).to be_nil
        expect(Rails.cache.read("user/#{user.id}/balance")).to be_nil
      end
    end

    context "with JSON format" do
      it "enqueues sync job and returns JSON success" do
        expect {
          post "/sync",
               headers: {
                 "Accept" => "application/json",
                 "Content-Type" => "application/json"
               },
               as: :json
        }.to have_enqueued_job(SyncUpBankDataJob).with(user)
      end

      it "returns JSON response with success status" do
        post "/sync",
             headers: {
               "Accept" => "application/json",
               "Content-Type" => "application/json"
             },
             as: :json

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response["status"]).to eq("success")
        expect(json_response["message"]).to be_present
      end

      it "does not redirect for JSON requests" do
        post "/sync",
             headers: {
               "Accept" => "application/json",
               "Content-Type" => "application/json"
             },
             as: :json

        expect(response).to have_http_status(:ok)
        expect(response).not_to redirect_to(dashboard_path)
        expect(response.location).to be_nil
      end

      it "invalidates user cache" do
        # Set cache values
        Rails.cache.write("user/#{user.id}/accounts", [])
        Rails.cache.write("user/#{user.id}/balance", 1000)

        post "/sync",
             headers: {
               "Accept" => "application/json",
               "Content-Type" => "application/json"
             },
             as: :json

        expect(Rails.cache.read("user/#{user.id}/accounts")).to be_nil
        expect(Rails.cache.read("user/#{user.id}/balance")).to be_nil
      end
    end

    context "when user has no Up Bank token" do
      let(:user_without_token) { create(:user) }

      before do
        sign_out user
        sign_in user_without_token, scope: :user
      end

      it "returns unauthorized for HTML requests" do
        post "/sync"

        expect(response).to have_http_status(:unauthorized)
      end

      it "returns unauthorized for JSON requests" do
        post "/sync",
             headers: {
               "Accept" => "application/json",
               "Content-Type" => "application/json"
             },
             as: :json

        expect(response).to have_http_status(:unauthorized)
      end

      it "does not enqueue sync job" do
        expect {
          post "/sync"
        }.not_to have_enqueued_job(SyncUpBankDataJob)
      end
    end

    context "authentication" do
      it "requires authentication" do
        sign_out user

        post "/sync"

        expect(response).not_to have_http_status(:ok)
        expect(response).not_to have_http_status(:unauthorized) # Should redirect to login
      end
    end
  end
end
