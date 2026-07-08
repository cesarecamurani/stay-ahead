# frozen_string_literal: true

class ActivateScheduledCommitmentsJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform
    Commitment.ready_to_activate.find_each do |commitment|
      unless commitment.activate!
        log_transition_failure(commitment, "activate!")
      end
    end
  end
end
