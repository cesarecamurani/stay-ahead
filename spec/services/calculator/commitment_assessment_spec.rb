# frozen_string_literal: true

require "rails_helper"

RSpec.describe Calculator::CommitmentAssessment do
  subject(:assessment) { described_class.new(user, candidate).call }

  let(:user) do
    create(
      :user,
      monthly_income: 4000,
      savings: 10_000,
      protected_savings: 3000
    )
  end

  describe "#call" do
    context "with a recurring commitment" do
      let(:candidate_start_date) { Date.current + 3.months }
      let(:candidate) do
        build(
          :commitment,
          user:,
          recurrence: :monthly,
          amount: 2500,
          start_date: candidate_start_date,
          duration_months: nil
        ).tap(&:valid?)
      end

      context "when an active commitment continues beyond the candidate start" do
        before do
          create(
            :commitment,
            user:,
            recurrence: :monthly,
            amount: 1000,
            duration_months: nil
          )
        end

        it "includes the commitment in the projected monthly position" do
          expect(assessment).to eq(
            affordable: true,
            overexposed: false,
            worst_case_date: candidate_start_date,
            projected_monthly_commitments: BigDecimal("3500"),
            remaining_monthly_cash_flow: BigDecimal("500"),
            remaining_spendable_savings: BigDecimal("7000")
          )
        end
      end

      context "when an active commitment ends before the candidate starts" do
        before do
          create(
            :commitment,
            user:,
            recurrence: :monthly,
            amount: 2000,
            start_date: Date.current - 1.year,
            end_date: candidate_start_date - 1.day
          )
        end

        it "excludes the completed commitment from the projected position" do
          expect(assessment).to include(
            affordable: true,
            overexposed: false,
            projected_monthly_commitments: BigDecimal("2500"),
            remaining_monthly_cash_flow: BigDecimal("1500")
          )
        end
      end

      context "when a scheduled commitment will be active by the candidate start" do
        before do
          create(
            :commitment,
            user:,
            recurrence: :monthly,
            amount: 2000,
            start_date: candidate_start_date - 1.month,
            duration_months: nil
          )
        end

        it "includes the scheduled commitment" do
          expect(assessment).to include(
            affordable: false,
            overexposed: true,
            worst_case_date: candidate_start_date,
            projected_monthly_commitments: BigDecimal("4500"),
            remaining_monthly_cash_flow: BigDecimal("-500")
          )
        end
      end

      context "when another commitment starts later while the candidate is active" do
        let(:later_start_date) { candidate_start_date + 1.month }

        before do
          create(
            :commitment,
            user:,
            recurrence: :monthly,
            amount: 2000,
            start_date: later_start_date,
            duration_months: nil
          )
        end

        it "returns the later, worst monthly position" do
          expect(assessment).to include(
            affordable: false,
            overexposed: true,
            worst_case_date: later_start_date,
            projected_monthly_commitments: BigDecimal("4500"),
            remaining_monthly_cash_flow: BigDecimal("-500")
          )
        end
      end
    end

    context "with a one-time commitment" do
      let(:due_date) { Date.current + 1.month }
      let(:category) { :obligation }
      let(:candidate) do
        build(
          :commitment,
          :one_time,
          user:,
          category:,
          amount:,
          due_date:
        ).tap(&:valid?)
      end

      context "when the amount preserves protected savings" do
        let(:amount) { 6000 }

        it "is affordable from spendable savings" do
          expect(assessment).to eq(
            affordable: true,
            overexposed: false,
            worst_case_date: due_date,
            projected_monthly_commitments: nil,
            remaining_monthly_cash_flow: nil,
            remaining_spendable_savings: BigDecimal("1000")
          )
        end
      end

      context "when the amount would use protected savings" do
        let(:amount) { 8000 }

        it "is overexposed" do
          expect(assessment).to include(
            affordable: false,
            overexposed: true,
            remaining_spendable_savings: BigDecimal("-1000")
          )
        end
      end

      context "when it adds to savings" do
        let(:amount) { 250 }
        let(:category) { :savings }

        it "is affordable and adds the amount to spendable savings" do
          expect(assessment).to include(
            affordable: true,
            overexposed: false,
            remaining_spendable_savings: BigDecimal("7250")
          )
        end
      end
    end
  end
end
