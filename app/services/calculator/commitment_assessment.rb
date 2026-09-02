# frozen_string_literal: true

module Calculator
  class CommitmentAssessment < Data.define(:user, :commitment)
    ASSESSABLE_STATUSES = %i[scheduled active].freeze

    def call
      commitment.one_time? ? one_time_assessment : recurring_assessment
    end

    private

    def recurring_assessment
      existing_commitments = assessable_recurring_commitments

      worst_case_date, projected_amount, remaining_cash_flow = assessment_dates(existing_commitments)
        .map { |date| monthly_position_on(date, existing_commitments) }
        .min_by { |position| position.last }

      affordable = remaining_cash_flow >= 0

      {
        affordable:,
        overexposed: !affordable,
        worst_case_date:,
        projected_monthly_commitments: projected_amount,
        remaining_monthly_cash_flow: remaining_cash_flow,
        remaining_spendable_savings: spendable_savings
      }
    end

    def one_time_assessment
      remaining_savings = commitment.savings? ? spendable_savings_after_contribution : spendable_savings - commitment.amount
      affordable = remaining_savings >= 0

      {
        affordable:,
        overexposed: !affordable,
        worst_case_date: commitment.due_date,
        projected_monthly_commitments: nil,
        remaining_monthly_cash_flow: nil,
        remaining_spendable_savings: remaining_savings
      }
    end

    def assessment_dates(existing_commitments)
      future_start_dates = existing_commitments.filter_map(&:start_date).select do |start_date|
        start_date >= commitment.start_date &&
          (commitment.end_date.nil? || start_date <= commitment.end_date)
      end

      ([commitment.start_date] + future_start_dates).uniq.sort
    end

    def monthly_position_on(date, existing_commitments)
      existing_amount = existing_commitments
        .select { |existing| active_on?(existing, date) }
        .sum(BigDecimal("0")) { |existing| Calculator::MonthlyAmount.call(existing) }

      projected_amount = existing_amount + Calculator::MonthlyAmount.call(commitment)

      [date, projected_amount, user.monthly_income - projected_amount]
    end

    def active_on?(existing, date)
      existing.start_date <= date && (existing.end_date.nil? || existing.end_date >= date)
    end

    def assessable_recurring_commitments
      user
        .commitments
        .where(status: ASSESSABLE_STATUSES)
        .where.not(recurrence: :one_time)
        .to_a
    end

    def spendable_savings
      [user.savings - user.protected_savings, BigDecimal("0")].max
    end

    def spendable_savings_after_contribution
      [user.savings + commitment.amount - user.protected_savings, BigDecimal("0")].max
    end
  end
end
