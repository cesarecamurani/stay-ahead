# frozen_string_literal: true

module Calculator
  class Summary < Data.define(:user)
    def call
      commitments_amount = monthly_commitments_amount

      {
        monthly_income: user.monthly_income,
        savings: user.savings,
        monthly_commitments_amount: commitments_amount,
        available_cash_flow: available_cash_flow(commitments_amount),
        savings_runway_months: savings_runway_months(commitments_amount)
      }
    end

    private

    def monthly_commitments_amount
      active_commitments.sum do |commitment|
        Calculator::MonthlyAmount.call(commitment)
      end
    end

    def available_cash_flow(monthly_commitments_amount)
      return if user.monthly_income.nil?

      user.monthly_income - monthly_commitments_amount
    end

    def savings_runway_months(monthly_commitments_amount)
      return if user.savings.nil?
      return if monthly_commitments_amount.zero?

      user.savings / monthly_commitments_amount
    end

    def active_commitments
      user.commitments.active
    end
  end
end
