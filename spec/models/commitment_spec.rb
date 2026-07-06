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
