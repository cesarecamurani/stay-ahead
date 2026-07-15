# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Me", type: :request do
  include_context "authenticated request"
  include_context "shared config"

  describe "GET /api/v1/me" do
    let(:user) { create(:user, monthly_income:, savings:) }

    context "when authenticated" do
      before { get "/api/v1/me", headers: auth_headers }

      it "returns user id" do
        expect(json_response[:user][:id]).to eq(user.id)
      end

      it "returns user email" do
        expect(json_response[:user][:email]).to eq(user.email)
      end

      it "returns user monthly income" do
        expect(json_response[:user][:monthly_income]).to eq("5000.00")
      end

      it "returns user savings" do
        expect(json_response[:user][:savings]).to eq("10000.00")
      end

      it "returns success status" do
        expect(response).to have_http_status(:success)
      end
    end

    context "when not authenticated" do
      it "returns unauthorized status" do
        get "/api/v1/me"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "PATCH /api/v1/me" do
    let(:user) { create(:user, email:, password:) }
    let(:monthly_income) { 6000.0 }
    let(:savings) { 15000.0 }
    let(:currency) { "GBP" }

    context "with valid parameters" do
      let(:valid_attributes) do
        {
          monthly_income:,
          savings:,
          currency:
        }
      end

      before do
        patch "/api/v1/me", params: { user: valid_attributes }, headers: auth_headers

        user.reload
      end

      it "returns ok status" do
        expect(response).to have_http_status(:ok)
      end

      it "updates the user's profile monthly_income" do
        expect(user.monthly_income).to eq(monthly_income)
      end

      it "updates the user's profile savings" do
        expect(user.savings).to eq(savings)
      end

      it "updates the user's profile currency" do
        expect(user.currency).to eq(currency)
      end

      it "returns updated user monthly_income" do
        expect(json_response[:user][:monthly_income]).to eq("6000.00")
      end

      it "returns updated user savings" do
        expect(json_response[:user][:savings]).to eq("15000.00")
      end

      it "returns updated user currency" do
        expect(json_response[:user][:currency]).to eq(currency)
      end
    end

    context "with invalid parameters" do
      let(:monthly_income) { -5000.0 }
      let(:savings) { -10000.0 }
      let(:currency) { "XXX" }

      let(:invalid_attributes) do
        {
          monthly_income:,
          savings:,
          currency:
        }
      end

      subject(:send_request) { patch "/api/v1/me", params: { user: invalid_attributes }, headers: auth_headers }

      it "does not update the user's profile" do
        expect { send_request }.not_to change { user.reload.attributes }
      end

      it "returns unprocessable_entity status" do
        send_request
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns the appropriate error messages" do
        send_request
        expect(json_response[:errors]).to include(
          "Monthly income must be greater than or equal to 0",
          "Savings must be greater than or equal to 0",
          "Currency XXX is not a valid currency"
        )
      end
    end
  end
end
