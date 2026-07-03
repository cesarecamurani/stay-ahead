# frozen_string_literal: true

class UserSerializer < BaseSerializer
  def initialize(user, compact: false)
    super(user)

    @compact = compact
  end

  def serialize
    return { id: object.id, email: object.email } if @compact

    {
      id: object.id,
      email: object.email,
      monthly_income: money(object.monthly_income),
      savings: money(object.savings),
      currency: object.currency
    }
  end
end
