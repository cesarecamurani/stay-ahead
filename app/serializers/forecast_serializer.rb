# frozen_string_literal: true

class ForecastSerializer < BaseSerializer
  def serialize
    { forecasts: object.map { |occurrence| serialize_occurrence(occurrence) } }
  end

  private

  def serialize_occurrence(occurrence)
    {
      commitment_id: occurrence[:commitment_id],
      name: occurrence[:name],
      category: occurrence[:category],
      date: occurrence[:date],
      amount: money(occurrence[:amount])
    }
  end
end
