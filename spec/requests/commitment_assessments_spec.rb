# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::CommitmentAssessments", type: :request do
  include_context "authenticated request"
  include_context "shared config"

  let(:user) do
    create(
      :user,
      monthly_income: 4000,
      savings: 10_000,
      protected_savings: 3000
    )
  end
  let(:start_date) { Date.current + 3.months }
  let(:commitment_params) do
    {
      name: "Apple TV",
      category: "service",
      recurrence: "monthly",
      amount: 10,
      start_date: start_date.iso8601
    }
  end

  subject(:send_request) do
    post "/api/v1/commitments/assessment",
         params: { commitment: commitment_params },
         headers: auth_headers
  end

  context "when the candidate is valid" do
    it "returns the serialized assessment without creating a commitment" do
      expect { send_request }.not_to change(Commitment, :count)

      expect(response).to have_http_status(:ok)
      expect(json_response).to eq(
        assessment: {
          affordable: true,
          overexposed: false,
          worst_case_date: start_date.iso8601,
          projected_monthly_commitments: "10.00",
          remaining_monthly_cash_flow: "3990.00",
          remaining_spendable_savings: "7000.00"
        }
      )
    end

    it "does not change the user's savings" do
      expect { send_request }.not_to change { user.reload.savings }
    end
  end

  context "with a one-time candidate" do
    let(:due_date) { Date.current + 1.month }
    let(:commitment_params) do
      {
        name: "Laptop",
        category: "obligation",
        recurrence: "one_time",
        amount: 7500,
        due_date: due_date.iso8601
      }
    end

    it "returns an assessment against spendable savings" do
      send_request

      expect(response).to have_http_status(:ok)
      expect(json_response[:assessment]).to eq(
        affordable: false,
        overexposed: true,
        worst_case_date: due_date.iso8601,
        projected_monthly_commitments: nil,
        remaining_monthly_cash_flow: nil,
        remaining_spendable_savings: "-500.00"
      )
    end
  end

  context "when the candidate is invalid" do
    let(:commitment_params) { super().except(:start_date) }

    it "returns the validation errors" do
      send_request

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response[:errors]).to include("Start date can't be blank")
    end
  end

  context "when the financial profile is incomplete" do
    let(:user) { create(:user, protected_savings: nil) }

    it "returns the missing profile fields" do
      send_request

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response[:errors]).to eq(["Protected savings must be set"])
    end
  end

  context "when the user is not authenticated" do
    subject(:send_request) do
      post "/api/v1/commitments/assessment", params: { commitment: commitment_params }
    end

    it "returns unauthorized status" do
      send_request

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
