# frozen_string_literal: true

require "rails_helper"

RSpec.describe ForecastSerializer do
  subject(:serializer) { described_class.new(occurrences) }

  let(:occurrences) do
    [
      {
        commitment_id: 1,
        name: "Netflix",
        category: "obligation",
        date: Date.new(2026, 7, 15),
        amount: BigDecimal("15.00")
      },
      {
        commitment_id: 2,
        name: "Gym",
        category: "service",
        date: Date.new(2026, 7, 20),
        amount: BigDecimal("50.50")
      }
    ]
  end

  describe "#serialize" do
    let(:result) { serializer.serialize }

    it "returns a hash with forecasts key" do
      expect(result).to have_key(:forecasts)
    end

    it "serializes each occurrence with the expected fields" do
      expect(result[:forecasts]).to eq([
        {
          commitment_id: 1,
          name: "Netflix",
          category: "obligation",
          date: Date.new(2026, 7, 15),
          amount: "15.00"
        },
        {
          commitment_id: 2,
          name: "Gym",
          category: "service",
          date: Date.new(2026, 7, 20),
          amount: "50.50"
        }
      ])
    end
  end
end
