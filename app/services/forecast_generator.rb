# frozen_string_literal: true

class ForecastGenerator
  ALLOWED_STATUSES = %i[scheduled active].freeze
  RECURRENCE_INTERVALS = {
    weekly:    { weeks: 1 },
    monthly:   { months: 1 },
    quarterly: { months: 3 },
    yearly:    { months: 12 }
  }.freeze

  def self.call(user:, from:, to:)
    new(user:, from:, to:).call
  end

  def initialize(user:, from:, to:)
    @user = user
    @from = from.to_date
    @to = to.to_date
  end

  def call
    return [] if from > to

    user
      .commitments
      .where(status: ALLOWED_STATUSES)
      .flat_map { |commitment| occurrences_for(commitment) }
      .sort_by { |occurrence| occurrence[:date] }
  end

  private

  attr_reader :user, :from, :to

  def occurrences_for(commitment)
    commitment.one_time? ? one_time_occurrences(commitment) : recurring_occurrences(commitment)
  end

  def one_time_occurrences(commitment)
    return [] if commitment.due_date.blank?
    return [] unless (from..to).cover?(commitment.due_date)

    [build_occurrence(commitment, commitment.due_date)]
  end

  def recurring_occurrences(commitment)
    return [] if commitment.start_date.blank?

    effective_to = [to, commitment.end_date].compact.min

    return [] if effective_to < commitment.start_date

    current = commitment.start_date

    while current < from && current <= effective_to
      current = next_occurrence_date(current, commitment.recurrence.to_sym)
    end

    occurrences = []

    while current <= effective_to
      occurrences << build_occurrence(commitment, current)
      current = next_occurrence_date(current, commitment.recurrence.to_sym)
    end

    occurrences
  end

  def next_occurrence_date(current, recurrence)
    current.advance(**RECURRENCE_INTERVALS.fetch(recurrence.to_sym))
  end

  def build_occurrence(commitment, date)
    {
      commitment_id: commitment.id,
      name: commitment.name,
      category: commitment.category,
      date:,
      amount: commitment.amount
    }
  end
end
