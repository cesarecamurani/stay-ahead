# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Forecasts", type: :request do
  include_context "authenticated request"
  include_context "shared config"

  describe "GET /api/v1/forecasts" do
    let(:from) { Date.current }
    let(:to) { Date.current + 60.days }
    let(:query_params) { { from: from.iso8601, to: to.iso8601 } }

    context "when user is authenticated" do
      let!(:one_time_commitment) do
        create(
          :commitment,
          :one_time,
          user:,
          name: "Insurance",
          category: :obligation,
          amount: 120.00,
          due_date: Date.current + 10.days
        )
      end
      let!(:recurring_commitment) do
        create(
          :commitment,
          user:,
          name: "Rent",
          category: :obligation,
          amount: 800.00,
          recurrence: :monthly,
          start_date: Date.current + 5.days
        )
      end

      let(:forecast_data) do
        {
          forecasts: ForecastGenerator.call(user:, from:, to:).map do |occurrence|
            {
              commitment_id: occurrence[:commitment_id],
              name: occurrence[:name],
              category: occurrence[:category],
              date: occurrence[:date].iso8601,
              amount: format("%.2f", occurrence[:amount])
            }
          end
        }
      end

      before { get "/api/v1/forecasts", params: query_params, headers: auth_headers }

      it "returns 200 status" do
        expect(response).to have_http_status(:ok)
      end

      it "returns forecast occurrences" do
        expect(json_response).to eq(forecast_data)
      end
    end

    context "when forecast occurrences span multiple dates" do
      let(:from) { Date.current }
      let(:to) { Date.current + 90.days }

      let!(:later_commitment) do
        create(
          :commitment,
          :one_time,
          user:,
          name: "Later payment",
          due_date: Date.current + 30.days
        )
      end
      let!(:earlier_commitment) do
        create(
          :commitment,
          :one_time,
          user:,
          name: "Earlier payment",
          due_date: Date.current + 5.days
        )
      end

      let(:forecast_dates) { json_response[:forecasts].map { |occurrence| occurrence[:date] } }

      before { get "/api/v1/forecasts", params: query_params, headers: auth_headers }

      it "returns forecast occurrences in chronological order" do
        expect(forecast_dates).to eq(forecast_dates.sort)
      end
    end

    context "when from parameter is missing" do
      before { get "/api/v1/forecasts", params: { to: to.iso8601 }, headers: auth_headers }

      it "returns bad request status" do
        expect(response).to have_http_status(:bad_request)
      end

      it "returns an error message" do
        expect(json_response[:error]).to eq("from and to parameters are required")
      end
    end

    context "when to parameter is missing" do
      before { get "/api/v1/forecasts", params: { from: from.iso8601 }, headers: auth_headers }

      it "returns bad request status" do
        expect(response).to have_http_status(:bad_request)
      end

      it "returns an error message" do
        expect(json_response[:error]).to eq("from and to parameters are required")
      end
    end

    context "when a date parameter cannot be parsed" do
      before do
        get "/api/v1/forecasts",
            params: { from: "not-a-date", to: to.iso8601 },
            headers: auth_headers
      end

      it "returns bad request status" do
        expect(response).to have_http_status(:bad_request)
      end

      it "returns an error message" do
        expect(json_response[:error]).to eq("invalid date parameter")
      end
    end

    context "when user is not authenticated" do
      before { get "/api/v1/forecasts", params: query_params, headers: {} }

      it "returns unauthorized status" do
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns unauthorized error" do
        expect(json_response[:error]).to eq("unauthorized")
      end
    end
  end
end
