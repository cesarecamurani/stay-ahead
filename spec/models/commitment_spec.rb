# frozen_string_literal: true

require "rails_helper"

RSpec.describe Commitment, type: :model do
  subject(:commitment) do
    build(
      :commitment,
      start_date:,
      duration_months:,
      status:
    )
  end

  let(:start_date) { Date.current - 1.month }
  let(:duration_months) { 3 }
  let(:status) { :active }

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:category) }
    it { is_expected.to validate_presence_of(:recurrence) }
    it { is_expected.to validate_numericality_of(:amount).is_greater_than(0) }
    it { is_expected.to validate_comparison_of(:end_date).is_greater_than(:start_date).allow_nil }
    it { is_expected.to validate_numericality_of(:interest_rate).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:duration_months).is_greater_than(0).only_integer }

    it "rejects an unknown category" do
      commitment = build(:commitment, category: "aaa")

      expect(commitment).not_to be_valid
      expect(commitment.errors[:category]).to include("is not included in the list")
    end

    it "rejects an unknown recurrence" do
      commitment = build(:commitment, recurrence: "aaa")

      expect(commitment).not_to be_valid
      expect(commitment.errors[:recurrence]).to include("is not included in the list")
    end

    it "rejects recurring commitments without start_date" do
      commitment = build(:commitment, recurrence: :monthly, start_date: nil, due_date: Date.current)

      expect(commitment).not_to be_valid
      expect(commitment.errors[:start_date]).to include("can't be blank")
    end

    it "rejects recurring commitments with due_date" do
      commitment = build(:commitment, recurrence: :monthly, due_date: Date.current, start_date: Date.current)

      expect(commitment).not_to be_valid
      expect(commitment.errors[:due_date]).to include("must be blank")
    end

    it "rejects one-time commitments without due_date" do
      commitment = build(:commitment, recurrence: :one_time, start_date: nil, due_date: nil)

      expect(commitment).not_to be_valid
      expect(commitment.errors[:due_date]).to include("can't be blank")
    end

    it "rejects one-time commitments with start_date" do
      commitment = build(:commitment, :one_time, start_date: Date.current)

      expect(commitment).not_to be_valid
      expect(commitment.errors[:start_date]).to include("must be blank")
    end

    it "allows one-time commitments without start_date" do
      commitment = build(:commitment, :one_time, start_date: nil)

      expect(commitment).to be_valid
    end
  end

  describe "initial status on create" do
    subject(:commitment) { build(:commitment, start_date:) }

    context "when start_date is today or in the past" do
      let(:start_date) { Date.current }

      it "sets status to active" do
        commitment.save!

        expect(commitment).to be_active
      end
    end

    context "when start_date is in the future" do
      let(:start_date) { Date.current + 1.month }

      it "sets status to scheduled" do
        commitment.save!

        expect(commitment).to be_scheduled
      end
    end
  end

  describe "initial status on create for one-time commitments" do
    subject(:commitment) { build(:commitment, :one_time, due_date:) }

    context "when due_date is in the past" do
      let(:due_date) { Date.current - 1.day }

      it "sets status to completed" do
        commitment.save!

        expect(commitment).to be_completed
      end
    end

    context "when due_date is in the future" do
      let(:due_date) { Date.current + 1.month }

      it "sets status to scheduled" do
        commitment.save!

        expect(commitment).to be_scheduled
      end
    end
  end

  describe "end_date on create" do
    subject(:commitment) { build(:commitment, start_date:, duration_months:, end_date:) }

    let(:start_date) { Date.new(2026, 1, 15) }
    let(:duration_months) { 12 }
    let(:end_date) { nil }

    context "with a fixed duration" do
      it "calculates end_date from start_date and duration_months" do
        commitment.save!

        expect(commitment.end_date).to eq(start_date + 12.months)
      end
    end

    context "without duration_months" do
      let(:duration_months) { nil }

      it "keeps end_date nil" do
        commitment.save!

        expect(commitment.end_date).to be_nil
      end
    end

    context "with an explicit end_date" do
      let(:end_date) { start_date + 6.months }

      it "preserves the provided end_date" do
        commitment.save!

        expect(commitment.end_date).to eq(start_date + 6.months)
      end
    end
  end

  describe ".active" do
    let!(:active_commitment) { create(:commitment) }
    let!(:scheduled_commitment) { create(:commitment, :scheduled) }
    let!(:paused_commitment) { create(:commitment, :paused) }
    let!(:completed_commitment) { create(:commitment, :completed) }
    let!(:cancelled_commitment) { create(:commitment, :cancelled) }

    it "includes active commitments" do
      expect(described_class.active).to include(active_commitment)
    end

    it "excludes scheduled commitments" do
      expect(described_class.active).not_to include(scheduled_commitment)
    end

    it "excludes paused commitments" do
      expect(described_class.active).not_to include(paused_commitment)
    end

    it "excludes completed commitments" do
      expect(described_class.active).not_to include(completed_commitment)
    end

    it "excludes cancelled commitments" do
      expect(described_class.active).not_to include(cancelled_commitment)
    end
  end

  describe "#pause!" do
    let(:commitment) { create(:commitment) }

    it "transitions to paused" do
      expect(commitment.pause!).to be true
      expect(commitment).to be_paused
    end

    context "with a new commitment" do
      let(:commitment) { Commitment.new }

      it "returns false without persisting" do
        expect(commitment).not_to be_persisted

        expect(commitment.pause!).to be false

        expect(commitment).not_to be_persisted
      end

      it "adds an error" do
        commitment.pause!

        expect(commitment.errors[:status]).to eq(["cannot transition a new commitment"])
      end
    end

    context "when not active" do
      let(:commitment) { create(:commitment, :scheduled) }

      it "returns false and adds an error" do
        expect(commitment.pause!).to be false
        expect(commitment.errors[:status]).to be_present
        expect(commitment).to be_scheduled
      end
    end
  end

  describe "#cancel!" do
    context "with a new commitment" do
      let(:commitment) { Commitment.new }

      it "returns false without persisting" do
        expect(commitment).not_to be_persisted

        expect(commitment.cancel!).to be false

        expect(commitment).not_to be_persisted
      end

      it "adds an error" do
        commitment.cancel!

        expect(commitment.errors[:status]).to eq(["cannot transition a new commitment"])
      end
    end

    %i[scheduled active paused].each do |from_status|
      context "when #{from_status}" do
        let(:commitment) do
          case from_status
          when :scheduled then create(:commitment, :scheduled)
          when :active then create(:commitment)
          when :paused then create(:commitment, :paused)
          end
        end

        it "transitions to cancelled" do
          expect(commitment.cancel!).to be true
          expect(commitment).to be_cancelled
        end
      end
    end

    context "when completed" do
      let(:commitment) { create(:commitment, :completed) }

      it "returns false and adds an error" do
        expect(commitment.cancel!).to be false
        expect(commitment.errors[:status]).to be_present
        expect(commitment).to be_completed
      end
    end

    context "when cancelled" do
      let(:commitment) { create(:commitment, :cancelled) }

      it "returns false and adds an error" do
        expect(commitment.cancel!).to be false
        expect(commitment.errors[:status]).to be_present
        expect(commitment).to be_cancelled
      end
    end
  end

  describe ".ready_to_activate" do
    let!(:eligible) do
      create(:commitment, :scheduled).tap do |commitment|
        commitment.update_columns(start_date: Date.current - 1.day, status: Commitment.statuses[:scheduled])
      end
    end

    let!(:future_start) { create(:commitment, :scheduled) }
    let!(:active_commitment) { create(:commitment) }

    it "includes scheduled commitments with start_date on or before today" do
      expect(described_class.ready_to_activate).to include(eligible)
    end

    it "excludes scheduled commitments with a future start_date" do
      expect(described_class.ready_to_activate).not_to include(future_start)
    end

    it "excludes non-scheduled commitments" do
      expect(described_class.ready_to_activate).not_to include(active_commitment)
    end
  end

  describe ".ready_to_complete" do
    let!(:eligible) do
      create(:commitment, end_date: Date.current - 1.day)
    end
    let!(:eligible_one_time) do
      create(:commitment, :one_time, due_date: Date.current - 1.day).tap do |commitment|
        commitment.update_columns(status: Commitment.statuses[:scheduled])
      end
    end
    let!(:no_end_date) { create(:commitment, duration_months: nil) }
    let!(:future_end) do
      create(:commitment, end_date: Date.current + 1.month)
    end
    let!(:scheduled_commitment) { create(:commitment, :scheduled) }
    let!(:future_one_time) do
      create(:commitment, :one_time, due_date: Date.current + 1.month).tap do |commitment|
        commitment.update_columns(status: Commitment.statuses[:scheduled])
      end
    end

    it "includes recurring active commitments with end_date on or before today" do
      expect(described_class.ready_to_complete).to include(eligible)
    end

    it "includes scheduled one-time commitments with due_date on or before today" do
      expect(described_class.ready_to_complete).to include(eligible_one_time)
    end

    it "excludes active commitments without an end_date" do
      expect(described_class.ready_to_complete).not_to include(no_end_date)
    end

    it "excludes active commitments with a future end_date" do
      expect(described_class.ready_to_complete).not_to include(future_end)
    end

    it "excludes scheduled recurring commitments" do
      expect(described_class.ready_to_complete).not_to include(scheduled_commitment)
    end

    it "excludes scheduled one-time commitments with a future due_date" do
      expect(described_class.ready_to_complete).not_to include(future_one_time)
    end
  end

  describe "#activate!" do
    let(:commitment) do
      create(:commitment, :scheduled).tap do |record|
        record.update_columns(start_date: Date.current - 1.day, status: Commitment.statuses[:scheduled])
        record.reload
      end
    end

    it "transitions to active" do
      expect(commitment.activate!).to be true
      expect(commitment).to be_active
    end

    context "when already active" do
      let(:commitment) { create(:commitment) }

      it "returns false and adds an error" do
        expect(commitment.activate!).to be false
        expect(commitment.errors[:status]).to be_present
        expect(commitment).to be_active
      end
    end

    context "when start_date is in the future" do
      let(:commitment) { create(:commitment, :scheduled) }

      it "returns false without transitioning" do
        expect(commitment.activate!).to be false
        expect(commitment.errors[:start_date]).to eq(["cannot be in the future"])
        expect(commitment).to be_scheduled
      end
    end

    context "when start_date is missing" do
      let(:commitment) do
        create(:commitment, :scheduled).tap do |record|
          record.update_columns(start_date: nil, status: Commitment.statuses[:scheduled])
          record.reload
        end
      end

      it "returns false without transitioning" do
        expect(commitment.activate!).to be false
        expect(commitment.errors[:start_date]).to eq(["cannot be blank"])
        expect(commitment).to be_scheduled
      end
    end
  end

  describe "#complete!" do
    let(:commitment) do
      create(:commitment, end_date: Date.current - 1.day)
    end

    it "transitions to completed" do
      expect(commitment.complete!).to be true
      expect(commitment).to be_completed
    end

    context "when end_date is missing" do
      let(:commitment) { create(:commitment, duration_months: nil) }

      it "returns false without transitioning" do
        expect(commitment.complete!).to be false
        expect(commitment.errors[:end_date]).to eq(["cannot be blank"])
        expect(commitment).to be_active
      end
    end

    context "when end_date is in the future" do
      let(:commitment) do
        create(:commitment, end_date: Date.current + 1.month)
      end

      it "returns false without transitioning" do
        expect(commitment.complete!).to be false
        expect(commitment.errors[:end_date]).to eq(["cannot be in the future"])
        expect(commitment).to be_active
      end
    end

    context "when already completed" do
      let(:commitment) { create(:commitment, :completed) }

      it "returns false and adds an error" do
        expect(commitment.complete!).to be false
        expect(commitment.errors[:status]).to be_present
        expect(commitment).to be_completed
      end
    end
  end

  describe "#resume!" do
    let(:commitment) { create(:commitment, :paused) }

    it "transitions to active" do
      expect(commitment.resume!).to be true
      expect(commitment).to be_active
    end

    context "with a new commitment" do
      let(:commitment) { Commitment.new }

      it "returns false without persisting" do
        expect(commitment).not_to be_persisted

        expect(commitment.resume!).to be false

        expect(commitment).not_to be_persisted
      end

      it "adds an error" do
        commitment.resume!

        expect(commitment.errors[:status]).to eq(["cannot transition a new commitment"])
      end
    end

    context "when not paused" do
      let(:commitment) { create(:commitment) }

      it "returns false and adds an error" do
        expect(commitment.resume!).to be false
        expect(commitment.errors[:status]).to be_present
        expect(commitment).to be_active
      end
    end
  end
end
