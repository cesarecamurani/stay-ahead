# frozen_string_literal: true

class CommitmentSerializer < BaseSerializer
  def self.serialize_collection(commitments)
    commitments.map { |commitment| new(commitment).serialize }
  end

  def serialize
    {
      id: object.id,
      name: object.name,
      category: object.category,
      recurrence: object.recurrence,
      status: object.status,
      amount: money(object.amount),
      **date_fields,
      duration_months: object.duration_months,
      interest_rate: decimal(object.interest_rate)
    }
  end

  private

  def date_fields
    if object.one_time?
      { due_date: object.due_date }
    else
      { start_date: object.start_date }
    end
  end
end
