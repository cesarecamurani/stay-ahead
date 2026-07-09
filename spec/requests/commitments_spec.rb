# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Commitments", type: :request do
  include_context "authenticated request"
  include_context "shared config"

  describe "GET /api/v1/commitments" do
    let!(:first_commitment) { create(:commitment, user:, name: "Rent") }
    let!(:second_commitment) { create(:commitment, user:, name: "Insurance") }
    let!(:other_user_commitment) { create(:commitment) }

    context "when authenticated" do
      before { get "/api/v1/commitments", headers: auth_headers }

      it "returns success status" do
        expect(response).to have_http_status(:success)
      end

      it "returns only current user commitments" do
        expect(json_response.size).to eq(2)
      end

      it "includes first commitment id" do
        expect(json_response.map { |item| item[:id] }).to include(first_commitment.id)
      end

      it "does not include other user commitments" do
        expect(json_response.map { |item| item[:id] }).not_to include(other_user_commitment.id)
      end
    end

    context "when not authenticated" do
      before { get "/api/v1/commitments" }

      it "returns unauthorized status" do
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns unauthorized error" do
        expect(json_response[:error]).to eq("unauthorized")
      end
    end
  end

  describe "GET /api/v1/commitments/:id" do
    let!(:commitment) { create(:commitment, user:, name: "Mortgage") }

    context "when authenticated and commitment belongs to current user" do
      before { get "/api/v1/commitments/#{commitment.id}", headers: auth_headers }

      it "returns success status" do
        expect(response).to have_http_status(:success)
      end

      it "returns commitment id" do
        expect(json_response[:id]).to eq(commitment.id)
      end

      it "returns commitment name" do
        expect(json_response[:name]).to eq("Mortgage")
      end
    end

    context "when authenticated and commitment belongs to another user" do
      let(:other_commitment) { create(:commitment) }

      before { get "/api/v1/commitments/#{other_commitment.id}", headers: auth_headers }

      it "returns not found status" do
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when not authenticated" do
      before { get "/api/v1/commitments/#{commitment.id}" }

      it "returns unauthorized status" do
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns unauthorized error" do
        expect(json_response[:error]).to eq("unauthorized")
      end
    end

    context "when commitment does not exist" do
      before { get "/api/v1/commitments/0", headers: auth_headers }

      it "returns not found status" do
        expect(response).to have_http_status(:not_found)
      end

      it "returns commitment not found error" do
        expect(json_response[:error]).to eq("Commitment not found")
      end
    end
  end

  describe "POST /api/v1/commitments" do
    let(:valid_params) do
      {
        name: "Car Loan",
        category: "debt",
        amount: 300.25,
        start_date: Date.current,
        duration_months: 24,
        interest_rate: 4.5,
        recurrence: "monthly"
      }
    end

    context "when authenticated with valid params" do
      subject(:send_request) { post "/api/v1/commitments", params: { commitment: valid_params }, headers: auth_headers }

      it "creates a commitment" do
        expect { send_request }.to change(Commitment, :count).by(1)
      end

      it "returns created status" do
        send_request
        expect(response).to have_http_status(:created)
      end

      it "returns created commitment name" do
        send_request
        expect(json_response[:name]).to eq("Car Loan")
      end

      it "stores commitment for current user" do
        send_request
        expect(Commitment.order(:created_at).last.user_id).to eq(user.id)
      end

      it "sets active status when start_date is today" do
        send_request
        expect(json_response[:status]).to eq("active")
      end

      it "formats amount as money" do
        send_request
        expect(json_response[:amount]).to eq("300.25")
      end
    end

    context "when start_date is in the future" do
      let(:valid_params) { super().merge(start_date: Date.current + 1.month) }

      before { post "/api/v1/commitments", params: { commitment: valid_params }, headers: auth_headers }

      it "sets scheduled status" do
        expect(json_response[:status]).to eq("scheduled")
      end
    end

    context "when creating a one-time commitment" do
      let(:due_date) { Date.current + 2.weeks }
      let(:one_time_params) do
        {
          name: "Insurance premium",
          category: "obligation",
          recurrence: "one_time",
          amount: 120.00,
          due_date:
        }
      end

      before { post "/api/v1/commitments", params: { commitment: one_time_params }, headers: auth_headers }

      it "creates a one-time commitment" do
        expect(response).to have_http_status(:created)
        expect(Commitment.last).to be_one_time
      end

      it "sets scheduled status when due_date is in the future" do
        expect(json_response[:status]).to eq("scheduled")
      end

      it "returns due_date in the response" do
        expect(json_response[:due_date]).to eq(due_date.iso8601)
      end

      it "omits start_date from the response" do
        expect(json_response).not_to have_key(:start_date)
      end
    end

    context "when one-time commitment due_date is today" do
      let(:one_time_params) do
        {
          name: "Past due payment",
          category: "debt",
          recurrence: "one_time",
          amount: 50.00,
          due_date: Date.current
        }
      end

      before { post "/api/v1/commitments", params: { commitment: one_time_params }, headers: auth_headers }

      it "sets completed status" do
        expect(json_response[:status]).to eq("completed")
      end
    end

    context "when one-time commitment is missing due_date" do
      before do
        post "/api/v1/commitments",
             params: {
               commitment: {
                 name: "Missing date",
                 category: "debt",
                 recurrence: "one_time",
                 amount: 100
               }
             },
             headers: auth_headers
      end

      it "returns unprocessable_entity status" do
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns validation errors" do
        expect(json_response[:errors]).to include("Due date can't be blank")
      end
    end

    context "when recurring commitment includes due_date" do
      before do
        post "/api/v1/commitments",
             params: { commitment: valid_params.merge(due_date: Date.current) },
             headers: auth_headers
      end

      it "returns unprocessable_entity status" do
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns validation errors" do
        expect(json_response[:errors]).to include("Due date must be blank")
      end
    end

    context "when status is sent in params" do
      before do
        post "/api/v1/commitments",
             params: { commitment: valid_params.merge(status: "paused") },
             headers: auth_headers
      end

      it "ignores client status and sets active from start_date" do
        expect(json_response[:status]).to eq("active")
      end
    end

    context "when category is invalid" do
      before do
        post "/api/v1/commitments",
             params: { commitment: valid_params.merge(category: "aaa") },
             headers: auth_headers
      end

      it "does not create a commitment" do
        expect(Commitment.count).to eq(0)
      end

      it "returns unprocessable_entity status" do
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns validation errors" do
        expect(json_response[:errors]).to include("Category is not included in the list")
      end
    end

    context "when recurrence is invalid" do
      before do
        post "/api/v1/commitments",
             params: { commitment: valid_params.merge(recurrence: "aaa") },
             headers: auth_headers
      end

      it "does not create a commitment" do
        expect(Commitment.count).to eq(0)
      end

      it "returns unprocessable_entity status" do
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns validation errors" do
        expect(json_response[:errors]).to include("Recurrence is not included in the list")
      end
    end

    context "when authenticated with invalid params" do
      let(:invalid_params) do
        {
          name: nil,
          category: "debt",
          amount: 100,
          start_date: Date.current,
          recurrence: "monthly"
        }
      end

      before do
        post "/api/v1/commitments",
             params: { commitment: invalid_params },
             headers: auth_headers
      end

      it "does not create a commitment" do
        expect(Commitment.count).to eq(0)
      end

      it "returns unprocessable_entity status" do
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns validation errors" do
        expect(json_response[:errors]).to include("Name can't be blank")
      end
    end

    context "when authenticated without commitment param" do
      before { post "/api/v1/commitments", params: {}, headers: auth_headers }

      it "returns bad request status" do
        expect(response).to have_http_status(:bad_request)
      end
    end

    context "when not authenticated" do
      before { post "/api/v1/commitments", params: { commitment: valid_params } }

      it "returns unauthorized status" do
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns unauthorized error" do
        expect(json_response[:error]).to eq("unauthorized")
      end
    end
  end

  describe "PATCH /api/v1/commitments/:id" do
    let!(:commitment) { create(:commitment, user:, name: "Old Name", amount: 500) }

    context "when authenticated with valid params" do
      let(:update_params) { { name: "New Name", amount: 450 } }

      before do
        patch "/api/v1/commitments/#{commitment.id}",
              params: { commitment: update_params },
              headers: auth_headers
      end

      it "returns ok status" do
        expect(response).to have_http_status(:ok)
      end

      it "updates commitment name" do
        expect(commitment.reload.name).to eq("New Name")
      end

      it "returns updated commitment name" do
        expect(json_response[:name]).to eq("New Name")
      end
    end

    context "when status is sent in params" do
      before do
        patch "/api/v1/commitments/#{commitment.id}",
              params: { commitment: { status: "paused" } },
              headers: auth_headers
      end

      it "does not change status" do
        expect(commitment.reload).to be_active
      end
    end

    context "when updating due_date on a one-time commitment" do
      let(:updated_due_date) { Date.current + 2.months }
      let!(:commitment) do
        create(
          :commitment,
          :one_time,
          user:,
          due_date: Date.current + 1.month
        )
      end

      before do
        patch "/api/v1/commitments/#{commitment.id}",
              params: { commitment: { due_date: updated_due_date } },
              headers: auth_headers
      end

      it "updates due_date" do
        expect(commitment.reload.due_date).to eq(updated_due_date)
      end

      it "returns updated due_date" do
        expect(json_response[:due_date]).to eq(updated_due_date.iso8601)
      end
    end

    context "when category is invalid" do
      before do
        patch "/api/v1/commitments/#{commitment.id}",
              params: { commitment: { category: "aaa" } },
              headers: auth_headers
      end

      it "returns unprocessable_entity status" do
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns validation errors" do
        expect(json_response[:errors]).to include("Category is not included in the list")
      end

      it "does not change category" do
        expect(commitment.reload.category).to eq("obligation")
      end
    end

    context "when authenticated with invalid params" do
      let(:invalid_update_params) { { amount: -1 } }

      before do
        patch "/api/v1/commitments/#{commitment.id}",
              params: { commitment: invalid_update_params },
              headers: auth_headers
      end

      it "returns unprocessable_entity status" do
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns validation errors" do
        expect(json_response[:errors]).to include("Amount must be greater than 0")
      end

      it "does not update commitment amount" do
        expect(commitment.reload.amount.to_f).to eq(500.0)
      end
    end

    context "when authenticated and commitment belongs to another user" do
      let(:other_commitment) { create(:commitment) }

      before do
        patch "/api/v1/commitments/#{other_commitment.id}",
              params: { commitment: { name: "Not Allowed" } },
              headers: auth_headers
      end

      it "returns not found status" do
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when not authenticated" do
      before do
        patch "/api/v1/commitments/#{commitment.id}", params: { commitment: { name: "Blocked" } }
      end

      it "returns unauthorized status" do
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns unauthorized error" do
        expect(json_response[:error]).to eq("unauthorized")
      end
    end
  end

  describe "POST /api/v1/commitments/:id/pause" do
    let!(:commitment) { create(:commitment, user:) }

    context "when authenticated" do
      before { post "/api/v1/commitments/#{commitment.id}/pause", headers: auth_headers }

      it "returns ok status" do
        expect(response).to have_http_status(:ok)
      end

      it "pauses the commitment" do
        expect(commitment.reload).to be_paused
      end

      it "returns paused status" do
        expect(json_response[:status]).to eq("paused")
      end
    end

    context "when commitment is not active" do
      let!(:commitment) { create(:commitment, :scheduled, user:) }

      before { post "/api/v1/commitments/#{commitment.id}/pause", headers: auth_headers }

      it "returns unprocessable_entity status" do
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "does not change status" do
        expect(commitment.reload).to be_scheduled
      end

      it "returns transition errors" do
        expect(json_response[:errors]).to be_present
      end
    end

    context "when commitment belongs to another user" do
      let(:other_commitment) { create(:commitment) }

      before { post "/api/v1/commitments/#{other_commitment.id}/pause", headers: auth_headers }

      it "returns not found status" do
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when not authenticated" do
      before { post "/api/v1/commitments/#{commitment.id}/pause" }

      it "returns unauthorized status" do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /api/v1/commitments/:id/cancel" do
    let!(:commitment) { create(:commitment, user:) }

    context "when authenticated" do
      before { post "/api/v1/commitments/#{commitment.id}/cancel", headers: auth_headers }

      it "returns ok status" do
        expect(response).to have_http_status(:ok)
      end

      it "cancels the commitment" do
        expect(commitment.reload).to be_cancelled
      end

      it "returns cancelled status" do
        expect(json_response[:status]).to eq("cancelled")
      end
    end

    context "when commitment is already cancelled" do
      let!(:commitment) { create(:commitment, :cancelled, user:) }

      before { post "/api/v1/commitments/#{commitment.id}/cancel", headers: auth_headers }

      it "returns unprocessable_entity status" do
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "when not authenticated" do
      before { post "/api/v1/commitments/#{commitment.id}/cancel" }

      it "returns unauthorized status" do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /api/v1/commitments/:id/resume" do
    let!(:commitment) { create(:commitment, :paused, user:) }

    context "when authenticated" do
      before { post "/api/v1/commitments/#{commitment.id}/resume", headers: auth_headers }

      it "returns ok status" do
        expect(response).to have_http_status(:ok)
      end

      it "resumes the commitment" do
        expect(commitment.reload).to be_active
      end

      it "returns active status" do
        expect(json_response[:status]).to eq("active")
      end
    end

    context "when commitment is not paused" do
      let!(:commitment) { create(:commitment, user:) }

      before { post "/api/v1/commitments/#{commitment.id}/resume", headers: auth_headers }

      it "returns unprocessable_entity status" do
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "does not change status" do
        expect(commitment.reload).to be_active
      end
    end

    context "when not authenticated" do
      before { post "/api/v1/commitments/#{commitment.id}/resume" }

      it "returns unauthorized status" do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
