# frozen_string_literal: true

module Api
  module V1
    class CommitmentsController < ApplicationController
      before_action :authenticate_user!
      before_action :set_commitment, only: %i[show update pause cancel resume]

      def index
        present_collection(current_user.commitments, serializer: CommitmentSerializer)
      end

      def show
        present_json(commitment, serializer: CommitmentSerializer)
      end

      def create
        commitment = current_user.commitments.build(commitment_params)

        if commitment.save
          present_json(commitment, serializer: CommitmentSerializer, status: :created)
        else
          render json: { errors: commitment.errors.full_messages },
                 status: :unprocessable_entity
        end
      end

      def update
        if commitment.update(commitment_params)
          present_json(commitment, serializer: CommitmentSerializer)
        else
          render json: { errors: commitment.errors.full_messages },
                 status: :unprocessable_entity
        end
      end

      def pause
        if commitment.pause!
          present_json(commitment, serializer: CommitmentSerializer)
        else
          render json: { errors: commitment.errors.full_messages },
                 status: :unprocessable_entity
        end
      end

      def cancel
        if commitment.cancel!
          present_json(commitment, serializer: CommitmentSerializer)
        else
          render json: { errors: commitment.errors.full_messages },
                 status: :unprocessable_entity
        end
      end

      def resume
        if commitment.resume!
          present_json(commitment, serializer: CommitmentSerializer)
        else
          render json: { errors: commitment.errors.full_messages },
                 status: :unprocessable_entity
        end
      end

      private

      attr_reader :commitment

      def set_commitment
        @commitment = current_user.commitments.find_by(id: params[:id])

        render json: { error: "Commitment not found" }, status: :not_found unless @commitment
      end

      def commitment_params
        params.require(:commitment).permit(
          :name,
          :category,
          :recurrence,
          :amount,
          :start_date,
          :duration_months,
          :interest_rate
        )
      end
    end
  end
end
