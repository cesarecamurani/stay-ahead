# frozen_string_literal: true

require "rails_helper"

RSpec.describe CommitmentSerializer do
  subject(:serializer) { described_class.new(commitment) }

  let(:commitment) do
    build(
      :commitment,
      name: "Car Loan",
      category: :debt,
      recurrence: :monthly,
      status: :active,
      amount:,
      start_date: Date.new(2026, 1, 15),
      duration_months: 24,
      interest_rate:
    )
  end
  let(:amount) { BigDecimal("300.25") }
  let(:interest_rate) { BigDecimal("4.57") }

  let(:result) { serializer.serialize }

  describe "#serialize" do
    it "returns whitelisted fields" do
      expect(result.keys).to contain_exactly(
        :id, :name, :category, :recurrence, :status,
        :amount, :start_date, :due_date, :duration_months, :interest_rate
      )
    end

    it "returns commitment attributes" do
      expect(result).to include(
        id: commitment.id,
        name: "Car Loan",
        category: "debt",
        recurrence: "monthly",
        status: "active",
        start_date: Date.new(2026, 1, 15),
        duration_months: 24
      )
    end

    it "formats amount as money" do
      expect(result[:amount]).to eq("300.25")
    end

    it "formats interest_rate as decimal" do
      expect(result[:interest_rate]).to eq(4.57)
    end

    context "when interest_rate is nil" do
      let(:interest_rate) { nil }

      it "returns nil for interest_rate" do
        expect(result[:interest_rate]).to be_nil
      end
    end

    context "when duration_months is nil" do
      let(:commitment) { build(:commitment, duration_months: nil) }

      it "returns nil for duration_months" do
        expect(result[:duration_months]).to be_nil
      end
    end

    context "when commitment is one-time" do
      let(:commitment) do
        build(
          :commitment,
          :one_time,
          start_date: nil,
          due_date: Date.new(2026, 6, 1),
          duration_months: nil
        )
      end

      it "returns due_date and nil start_date" do
        expect(result[:due_date]).to eq(Date.new(2026, 6, 1))
        expect(result[:start_date]).to be_nil
      end
    end
  end

  describe ".serialize_collection" do
    let(:commitments) { [commitment, build(:commitment, name: "Rent")] }

    it "returns an array of serialized commitments" do
      result = described_class.serialize_collection(commitments)

      expect(result).to be_an(Array)
      expect(result.size).to eq(2)
      expect(result.first[:name]).to eq("Car Loan")
      expect(result.last[:name]).to eq("Rent")
    end
  end
end
