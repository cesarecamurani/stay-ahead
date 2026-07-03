# frozen_string_literal: true

module Calculator
  class Breakdown < Data.define(:user)
    CATEGORIES = Commitment.categories.keys.freeze

    def call
      CATEGORIES.index_with(BigDecimal("0")).merge(category_totals)
    end

    private

    def category_totals
      active_commitments
        .group_by(&:category)
        .transform_values { |commitments| category_total(commitments) }
    end

    def category_total(commitments)
      commitments.sum do |commitment|
        Calculator::MonthlyAmount.call(commitment)
      end
    end

    def active_commitments
      user.commitments.active
    end
  end
end
