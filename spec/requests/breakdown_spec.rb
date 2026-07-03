# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Breakdown", type: :request do
  include_context "authenticated request"
  include_context "shared config"

  describe "GET /api/v1/breakdown" do
    let(:user) { create(:user) }
    let!(:obligation_commitments) do
      create_list(
        :commitment,
        2,
        user:,
        amount: 400,
        category: :obligation
      )
    end
    let!(:debt_commitment) do
      create(
        :commitment,
        user:,
        amount: 100,
        category: :debt
      )
    end
    let!(:service_commitment) do
      create_list(
        :commitment,
        2,
        user:,
        amount: 11,
        category: :service
      )
    end
    let!(:investment_commitment) do
      create(
        :commitment,
        user:,
        amount: 250,
        category: :investment
      )
    end

    let(:breakdown_data) do
      {
        breakdown: {
          obligation: "800.00",
          debt: "100.00",
          service: "22.00",
          investment: "250.00"
        }
      }
    end

    context "when user is authenticated" do
      before { get "/api/v1/breakdown", headers: auth_headers }

      it "returns 200 status" do
        expect(response).to have_http_status(:ok)
      end

      it "returns breakdown data" do
        expect(json_response).to eq(breakdown_data)
      end
    end

    context "when commitments are not active" do
      let!(:obligation_commitments) { [] }
      let!(:debt_commitment) { create(:commitment, :paused, user:, amount: 100, category: :debt) }
      let!(:service_commitment) { [] }
      let!(:investment_commitment) { nil }

      let(:breakdown_data) do
        {
          breakdown: {
            obligation: "0.00",
            debt: "0.00",
            service: "0.00",
            investment: "0.00"
          }
        }
      end

      before { get "/api/v1/breakdown", headers: auth_headers }

      it "excludes non-active commitments from totals" do
        expect(json_response).to eq(breakdown_data)
      end
    end

    context "when user is not authenticated" do
      before { get "/api/v1/breakdown", headers: {} }

      it "returns 401 unauthorized status" do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
