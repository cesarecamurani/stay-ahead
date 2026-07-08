# frozen_string_literal: true

FactoryBot.define do
  factory :commitment do
    user
    name { "Netflix Subscription" }
    category { :obligation }
    recurrence { :monthly }
    amount { 15.0 }
    start_date { Date.today - 7.days }
    due_date { nil }
    interest_rate { 0.0 }
    duration_months { 12 }

    trait :scheduled do
      start_date { Date.current + 1.month }
    end

    trait :paused do
      after(:create, &:pause!)
    end

    trait :completed do
      end_date { Date.current - 1.day }

      after(:create, &:complete!)
    end

    trait :cancelled do
      after(:create, &:cancel!)
    end

    trait :one_time do
      recurrence { :one_time }
      due_date { Date.current }
      start_date { nil }
      duration_months { nil }
    end
  end
end
