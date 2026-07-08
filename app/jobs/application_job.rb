# frozen_string_literal: true

class ApplicationJob < ActiveJob::Base
  private

  def log_transition_failure(commitment, action)
    Rails.logger.warn(
      "[#{self.class.name}] #{action} failed for Commitment #{commitment.id}: " \
      "#{commitment.errors.full_messages.to_sentence}"
    )
  end
end
