# frozen_string_literal: true

require "rails_helper"

RSpec.describe Calculator::Summary do
  subject(:summary) { described_class.new(user) }

  let(:user) { create(:user, monthly_income: 5000, savings: 10_000) }

  describe "#call" do
    before do
      create(:commitment, user:, recurrence: :monthly, amount: 10)
    end

    let(:call_result) do
      {
        monthly_income: BigDecimal("5000"),
        savings: BigDecimal("10000"),
        monthly_commitments_amount: BigDecimal("10"),
        available_cash_flow: BigDecimal("4990"),
        savings_runway_months: BigDecimal("1000")
      }
    end

    it "returns the user's financial summary" do
      expect(summary.call).to eq(call_result)
    end

    context "when an active savings commitment exists" do
      before do
        create(:commitment, user:, category: :savings, recurrence: :monthly, amount: 250)
      end

      it "includes it in cash flow but excludes it from the savings runway expenses" do
        expect(summary.call).to include(
          savings: BigDecimal("10250"),
          monthly_commitments_amount: BigDecimal("260"),
          available_cash_flow: BigDecimal("4740"),
          savings_runway_months: BigDecimal("1025")
        )
      end
    end
  end

  describe "#monthly_commitments_amount" do
    context "when there are active commitments" do
      before do
        create(:commitment, user:, recurrence: :monthly, amount: 500)
        create(:commitment, user:, recurrence: :quarterly, amount: 300)
      end

      it "sums them all" do
        expect(summary.send(:monthly_commitments_amount)).to eq(BigDecimal("600"))
      end
    end

    context "when there are paused commitments" do
      before do
        create(:commitment, user:, recurrence: :monthly, amount: 500)
        create(:commitment, :paused, user:, recurrence: :quarterly, amount: 300)
      end

      it "excludes them from the sum" do
        expect(summary.send(:monthly_commitments_amount)).to eq(BigDecimal("500"))
      end
    end

    %i[scheduled completed cancelled].each do |trait|
      context "when a commitment is #{trait}" do
        before do
          create(:commitment, user:, recurrence: :monthly, amount: 500)
          create(:commitment, trait, user:, recurrence: :quarterly, amount: 300)
        end

        it "excludes it from the sum" do
          expect(summary.send(:monthly_commitments_amount)).to eq(BigDecimal("500"))
        end
      end
    end

    context "when there are no commitments" do
      it "returns zero" do
        expect(summary.send(:monthly_commitments_amount)).to eq(BigDecimal("0"))
      end
    end
  end

  describe "#available_cash_flow" do
    let(:amount) { BigDecimal("10") }

    context "when monthly_income is present" do
      it "calculates available cash flow as income minus commitments" do
        expect(summary.send(:available_cash_flow, amount)).to eq(BigDecimal("4990"))
      end
    end

    context "when monthly_income is nil" do
      let(:user) { create(:user, monthly_income: nil, savings: 10_000) }

      it "returns nil" do
        expect(summary.send(:available_cash_flow, amount)).to be_nil
      end
    end

    context "when there are no commitments" do
      let(:amount) { BigDecimal("0") }

      it "returns full income" do
        expect(summary.send(:available_cash_flow, amount)).to eq(BigDecimal("5000"))
      end
    end
  end

  describe "#savings_runway_months" do
    let(:amount) { BigDecimal("10") }

    context "when savings is present and commitments amount is not zero" do
      it "calculates savings runway months as savings divided by commitments" do
        expect(summary.send(:savings_runway_months, amount)).to eq(BigDecimal("1000"))
      end
    end

    context "when savings is nil" do
      let(:user) { create(:user, monthly_income: 5000, savings: nil) }

      it "returns nil" do
        expect(summary.send(:savings_runway_months, amount)).to be_nil
      end
    end

    context "when commitments amount is zero" do
      let(:amount) { BigDecimal("0") }

      it "returns nil" do
        expect(summary.send(:savings_runway_months, amount)).to be_nil
      end
    end
  end

  describe "#active_commitments" do
    context "when there are active and non-active commitments" do
      let!(:active_commitment) { create(:commitment, user:) }

      before do
        create(:commitment, :paused, user:)
        create(:commitment, :completed, user:)
      end

      it "returns only active commitments" do
        expect(summary.send(:active_commitments)).to contain_exactly(active_commitment)
      end
    end

    context "when there are no commitments" do
      it "returns empty array" do
        expect(summary.send(:active_commitments)).to eq([])
      end
    end
  end
end
