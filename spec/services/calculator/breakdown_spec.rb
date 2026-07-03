# frozen_string_literal: true

require "rails_helper"

RSpec.describe Calculator::Breakdown do
  subject(:breakdown) { described_class.new(user) }

  let(:user) { create(:user) }

  describe "#call" do
    context "when there are active commitments" do
      before do
        create(
          :commitment,
          user:,
          category: :obligation,
          recurrence: :monthly,
          amount: 1200
        )

        create(
          :commitment,
          user:,
          category: :obligation,
          recurrence: :monthly,
          amount: 300
        )

        create(
          :commitment,
          user:,
          category: :service,
          recurrence: :monthly,
          amount: 15
        )
      end

      it "returns all categories" do
        expect(breakdown.call.keys).to match_array(Commitment.categories.keys)
      end

      it "sums monthly amounts by category" do
        expect(breakdown.call).to include(
          "obligation" => BigDecimal("1500"),
          "service" => BigDecimal("15")
        )
      end
    end

    context "when a commitment is paused" do
      before do
        create(
          :commitment,
          :paused,
          user:,
          category: :debt,
          recurrence: :monthly,
          amount: 500
        )
      end

      it "does not include paused commitments" do
        expect(breakdown.call["debt"]).to eq(BigDecimal("0"))
      end
    end

    context "when a commitment is scheduled" do
      before do
        create(
          :commitment,
          :scheduled,
          user:,
          category: :debt,
          recurrence: :monthly,
          amount: 500
        )
      end

      it "does not include scheduled commitments" do
        expect(breakdown.call["debt"]).to eq(BigDecimal("0"))
      end
    end

    context "when a commitment is completed" do
      before do
        create(
          :commitment,
          :completed,
          user:,
          category: :investment,
          recurrence: :monthly,
          amount: 200
        )
      end

      it "does not include completed commitments" do
        expect(breakdown.call["investment"]).to eq(BigDecimal("0"))
      end
    end

    context "when a commitment is cancelled" do
      before do
        create(
          :commitment,
          :cancelled,
          user:,
          category: :debt,
          recurrence: :monthly,
          amount: 500
        )
      end

      it "does not include cancelled commitments" do
        expect(breakdown.call["debt"]).to eq(BigDecimal("0"))
      end
    end

    context "when there are no commitments" do
      let(:expected) do
        Commitment.categories.keys.index_with(BigDecimal("0"))
      end

      it "returns all categories with zero amounts" do
        expect(breakdown.call).to eq(expected)
      end
    end
  end
end
