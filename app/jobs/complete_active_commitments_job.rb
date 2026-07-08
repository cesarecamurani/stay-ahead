# frozen_string_literal: true

class CompleteActiveCommitmentsJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform
    Commitment.ready_to_complete.find_each do |commitment|
      unless commitment.complete!
        log_transition_failure(commitment, "complete!")
      end
    end
  end
end
