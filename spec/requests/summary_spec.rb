# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Summary", type: :request do
  include_context "authenticated request"
  include_context "shared config"

  describe "GET /api/v1/summary" do
    let(:user) { create(:user) }
    let(:commitment_amount) { 20 }
    let!(:commitment) do
      create(
        :commitment,
        user:,
        amount: commitment_amount,
        recurrence: :monthly
      )
    end
    let(:monthly_income) { format("%.2f", user.monthly_income) }
    let(:savings) { format("%.2f", user.savings) }
    let(:available_cash_flow) { format("%.2f", user.monthly_income - commitment_amount) }
    let(:monthly_commitments_amount) { format("%.2f", commitment_amount) }
    let(:savings_runway_months) { (user.savings / commitment_amount) }

    let(:summary_data) do
      {
        summary: {
          monthly_income:,
          savings:,
          available_cash_flow:,
          monthly_commitments_amount:,
          savings_runway_months:
        }
      }
    end

    context "when user is authenticated" do
      before { get "/api/v1/summary", headers: auth_headers }

      it "returns 200 status" do
        expect(response).to have_http_status(:ok)
      end

      it "returns summary data" do
        expect(json_response).to eq(summary_data)
      end
    end

    context "when the only commitment is paused" do
      let!(:commitment) { create(:commitment, :paused, user:, amount: commitment_amount, recurrence: :monthly) }

      before { get "/api/v1/summary", headers: auth_headers }

      it "excludes paused commitments from totals" do
        expect(json_response[:summary][:monthly_commitments_amount]).to eq("0.00")
      end
    end

    context "when user is not authenticated" do
      before { get "/api/v1/summary", headers: {} }

      it "returns 401 unauthorized status" do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
