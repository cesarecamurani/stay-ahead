# frozen_string_literal: true

require "rails_helper"

RSpec.describe ForecastGenerator do
  let(:user) { create(:user) }

  describe ".call" do
    context "one-time commitments" do
      context "when due_date is inside the requested range" do
        let(:due_date) { Date.current + 20.days }
        let(:from) { Date.current + 10.days }
        let(:to) { Date.current + 30.days }

        let!(:commitment) do
          create(
            :commitment,
            :one_time,
            user:,
            name: "Laptop",
            category: :service,
            amount: 90.00,
            due_date:
          )
        end

        let(:result) { described_class.call(user:, from:, to:) }

        it "generates exactly one occurrence on due_date" do
          expect(result).to eq([
            {
              commitment_id: commitment.id,
              name: commitment.name,
              category: commitment.category,
              date: due_date,
              amount: commitment.amount
            }
          ])
        end
      end

      context "when due_date is outside the requested range" do
        let!(:commitment) do
          create(
            :commitment,
            :one_time,
            user:,
            name: "Laptop",
            category: :service,
            amount: 90.00,
            due_date: Date.current + 20.days
          )
        end

        let(:from) { Date.current + 21.days }
        let(:to) { Date.current + 30.days }

        let(:result) { described_class.call(user:, from:, to:) }

        it "returns an empty forecast" do
          expect(result).to be_empty
        end
      end

      context "when inside the requested range (no monthly spreading)" do
        let(:due_date) { Date.current + 20.days }
        let(:from) { Date.current + 10.days }
        let(:to) { Date.current + 110.days }

        let!(:commitment) do
          create(
            :commitment,
            :one_time,
            user:,
            name: "Yearly insurance",
            category: :service,
            amount: 100.00,
            due_date:
          )
        end

        let(:result) { described_class.call(user:, from:, to:) }

        it "uses the full amount for the single occurrence" do
          expect(result).to eq([
            {
              commitment_id: commitment.id,
              name: commitment.name,
              category: commitment.category,
              date: due_date,
              amount: commitment.amount
            }
          ])
        end
      end
    end

    context "recurring commitments" do
      context "weekly" do
        let(:start_date) { Date.current + 5.days }
        let(:to) { start_date + 21.days }
        let(:from) { start_date }

        let!(:commitment) do
          create(
            :commitment,
            user:,
            recurrence: :weekly,
            start_date:,
            duration_months: nil,
            end_date: nil,
            name: "Gym membership",
            category: :service,
            amount: 15.00
          )
        end

        let(:expected_pairs) do
          [
            [start_date, commitment.amount],
            [start_date + 7.days, commitment.amount],
            [start_date + 14.days, commitment.amount],
            [start_date + 21.days, commitment.amount]
          ]
        end

        let(:result) { described_class.call(user:, from:, to:) }

        it "generates correct weekly occurrences" do
          expect(
            result.map { |occurrence| [occurrence[:date], occurrence[:amount]] }
          ).to eq(expected_pairs)
        end
      end

      context "monthly" do
        let(:next_month) { Date.current.next_month }
        let(:start_date) { Date.new(next_month.year, next_month.month, 15) }
        let(:from) { start_date >> -1 }
        let(:to) { start_date >> 2 }

        let!(:commitment) do
          create(
            :commitment,
            user:,
            recurrence: :monthly,
            start_date:,
            duration_months: nil,
            end_date: nil,
            name: "Subscription",
            category: :service,
            amount: 50.00
          )
        end

        let(:expected_pairs) do
          [
            [start_date, commitment.amount],
            [start_date >> 1, commitment.amount],
            [start_date >> 2, commitment.amount]
          ]
        end

        let(:result) { described_class.call(user:, from:, to:) }

        it "generates correct monthly occurrences" do
          expect(
            result.map { |occurrence| [occurrence[:date], occurrence[:amount]] }
          ).to eq(expected_pairs)
        end
      end

      context "quarterly (3-month interval)" do
        let(:next_month) { Date.current.next_month }
        let(:start_date) { Date.new(next_month.year, next_month.month, 1) }
        let(:from) { start_date }
        let(:to) { start_date >> 9 }

        let!(:commitment) do
          create(
            :commitment,
            user:,
            recurrence: :quarterly,
            start_date:,
            duration_months: nil,
            end_date: nil,
            name: "Service contract",
            category: :service,
            amount: 300.00
          )
        end

        let(:expected_pairs) do
          [
            [start_date, commitment.amount],
            [start_date >> 3, commitment.amount],
            [start_date >> 6, commitment.amount],
            [start_date >> 9, commitment.amount]
          ]
        end

        let(:result) { described_class.call(user:, from:, to:) }

        it "generates correct quarterly occurrences" do
          expect(
            result.map { |occurrence| [occurrence[:date], occurrence[:amount]] }
          ).to eq(expected_pairs)
        end
      end

      context "yearly (12-month interval)" do
        let(:start_date) { Date.new(Date.current.next_month.year, Date.current.next_month.month, 1) }
        let(:from) { start_date >> -12 }
        let(:to) { start_date >> 12 }

        let!(:commitment) do
          create(
            :commitment,
            user:,
            recurrence: :yearly,
            start_date:,
            duration_months: nil,
            end_date: nil,
            name: "Insurance renewal",
            category: :service,
            amount: 600.00
          )
        end

        let(:expected_pairs) do
          [
            [start_date, commitment.amount],
            [start_date >> 12, commitment.amount]
          ]
        end

        let(:result) { described_class.call(user:, from:, to:) }

        it "generates correct yearly occurrences" do
          expect(
            result.map { |occurrence| [occurrence[:date], occurrence[:amount]] }
          ).to eq(expected_pairs)
        end
      end
    end

    context "end date handling" do
      context "when end_date is present" do
        let(:start_date) { Date.new(Date.current.year, 1, 1) }
        let(:end_date) { Date.new(Date.current.year, 6, 30) }
        let(:from) { start_date }
        let(:to) { Date.new(Date.current.year, 12, 31) }

        let!(:commitment) do
          create(
            :commitment,
            user:,
            recurrence: :monthly,
            start_date:,
            duration_months: nil,
            end_date:,
            name: "Rental",
            category: :obligation,
            amount: 1000.00
          )
        end

        let(:expected_pairs) do
          (0..5).map { |i| [start_date >> i, commitment.amount] }
        end

        let(:result) { described_class.call(user:, from:, to:) }

        it "stops generating occurrences after end_date" do
          expect(
            result.map { |occurrence| [occurrence[:date], occurrence[:amount]] }
          ).to eq(expected_pairs)
        end
      end

      context "when end_date is nil" do
        let(:next_month) { Date.current.next_month }
        let(:start_date) { Date.new(next_month.year, next_month.month, 15) }
        let(:from) { start_date }
        let(:to) { start_date >> 2 }

        let!(:commitment) do
          create(
            :commitment,
            user:,
            recurrence: :monthly,
            start_date:,
            duration_months: nil,
            end_date: nil,
            name: "Internet bill",
            category: :service,
            amount: 25.00
          )
        end

        let(:expected_pairs) do
          [
            [start_date, commitment.amount],
            [start_date >> 1, commitment.amount],
            [start_date >> 2, commitment.amount]
          ]
        end

        let(:result) { described_class.call(user:, from:, to:) }

        it "continues generating until the forecast end date" do
          expect(
            result.map { |occurrence| [occurrence[:date], occurrence[:amount]] }
          ).to eq(expected_pairs)
        end
      end
    end

    context "range filtering" do
      context "when occurrences are before from" do
        let(:start_date) { Date.current + 1.day }
        let(:from) { start_date + 7.days }
        let(:to) { start_date + 14.days }

        let!(:commitment) do
          create(
            :commitment,
            user:,
            recurrence: :weekly,
            start_date:,
            duration_months: nil,
            end_date: nil,
            name: "Weekly fee",
            category: :service,
            amount: 10.00
          )
        end

        let(:expected_pairs) do
          [
            [from, commitment.amount],
            [to, commitment.amount]
          ]
        end

        let(:result) { described_class.call(user:, from:, to:) }

        it "excludes occurrences before from" do
          expect(
            result.map { |occurrence| [occurrence[:date], occurrence[:amount]] }
          ).to eq(expected_pairs)
        end
      end

      context "when occurrences are after to" do
        let(:start_date) { Date.current + 1.day }
        let(:from) { start_date }
        let(:to) { start_date + 13.days }

        let!(:commitment) do
          create(
            :commitment,
            user:,
            recurrence: :weekly,
            start_date:,
            duration_months: nil,
            end_date: nil,
            name: "Weekly fee",
            category: :service,
            amount: 10.00
          )
        end

        let(:expected_pairs) do
          [
            [start_date, commitment.amount],
            [start_date + 7.days, commitment.amount]
          ]
        end

        let(:result) { described_class.call(user:, from:, to:) }

        it "excludes occurrences after to" do
          expect(
            result.map { |occurrence| [occurrence[:date], occurrence[:amount]] }
          ).to eq(expected_pairs)
        end
      end
    end
  end
end
