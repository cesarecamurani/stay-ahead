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

      def assessment
        candidate = current_user.commitments.build(commitment_params)

        unless candidate.valid?
          render json: { errors: candidate.errors.full_messages }, status: :unprocessable_entity
          return
        end

        missing_fields = missing_assessment_profile_fields

        if missing_fields.any?
          render json: {
            errors: missing_fields.map { |field| "#{field.to_s.humanize} must be set" }
          }, status: :unprocessable_entity
          return
        end

        result = Calculator::CommitmentAssessment.new(current_user, candidate).call

        present_json(result, serializer: CommitmentAssessmentSerializer)
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
          :due_date,
          :duration_months,
          :interest_rate
        )
      end

      def missing_assessment_profile_fields
        %i[monthly_income savings protected_savings].select do |field|
          current_user.public_send(field).nil?
        end
      end
    end
  end
end
