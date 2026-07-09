# frozen_string_literal: true

module Api
  module V1
    class ForecastsController < ApplicationController
      before_action :authenticate_user!
      before_action :set_date_range

      def index
        forecasts = ForecastGenerator.call(user: current_user, from:, to:)

        present_json(forecasts, serializer: ForecastSerializer)
      end

      private

      attr_reader :from, :to

      def set_date_range
        if params[:from].blank? || params[:to].blank?
          render json: { error: "from and to parameters are required" }, status: :bad_request
          return
        end

        @from = Date.iso8601(params[:from])
        @to = Date.iso8601(params[:to])
      rescue ArgumentError, TypeError
        render json: { error: "invalid date parameter" }, status: :bad_request
      end
    end
  end
end
