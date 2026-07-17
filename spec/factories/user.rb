# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "test#{n}@example.com" }
    sequence(:username) { |n| "user#{n}" }
    password { "Password123!" }
    password_confirmation { password }
    monthly_income { 4000.00 }
    savings { 1000.00 }
    currency { "EUR" }
  end
end
