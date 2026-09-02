# frozen_string_literal: true

class CommitmentAssessmentSerializer < BaseSerializer
  def serialize
    {
      assessment: {
        affordable: object[:affordable],
        overexposed: object[:overexposed],
        worst_case_date: object[:worst_case_date],
        projected_monthly_commitments: money(object[:projected_monthly_commitments]),
        remaining_monthly_cash_flow: money(object[:remaining_monthly_cash_flow]),
        remaining_spendable_savings: money(object[:remaining_spendable_savings])
      }
    }
  end
end
