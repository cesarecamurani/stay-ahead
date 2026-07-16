# frozen_string_literal: true

class PasswordComplexityValidator < ActiveModel::EachValidator
  RULES = {
    /[A-Z]/ => "must contain at least one uppercase letter",
    /[a-z]/ => "must contain at least one lowercase letter",
    /[0-9]/ => "must contain at least one number",
    /[^A-Za-z0-9]/ => "must contain at least one special character"
  }.freeze

  def validate_each(record, attribute, value)
    return if value.blank?

    record.errors.add(attribute, "must be at least 12 characters") if value.length < 12

    RULES.each do |regex, message|
      record.errors.add(attribute, message) unless value.match?(regex)
    end
  end
end
