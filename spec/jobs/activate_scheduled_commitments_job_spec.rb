# frozen_string_literal: true

require "rails_helper"

RSpec.describe ActivateScheduledCommitmentsJob, type: :job do
  include ActiveJob::TestHelper

  describe "retry configuration" do
    it "retries StandardError" do
      expect(described_class.rescue_handlers.map(&:first)).to include("StandardError")
    end
  end

  describe "#perform" do
    let!(:eligible) do
      create(:commitment, :scheduled).tap do |commitment|
        commitment.update_columns(start_date: Date.current - 1.day, status: Commitment.statuses[:scheduled])
      end
    end
    let!(:eligible_one_time) do
      create(:commitment, :one_time, due_date: Date.current - 1.day).tap do |commitment|
        commitment.update_columns(status: Commitment.statuses[:scheduled])
      end
    end
    let!(:future_start) { create(:commitment, :scheduled) }
    let!(:active_commitment) { create(:commitment) }

    it "activates scheduled commitments ready for activation" do
      described_class.perform_now

      expect(eligible.reload).to be_active
    end

    it "does not change commitments outside the scope" do
      described_class.perform_now

      expect(future_start.reload).to be_scheduled
      expect(active_commitment.reload).to be_active
      expect(eligible_one_time.reload).to be_scheduled
    end

    it "is idempotent on re-run" do
      described_class.perform_now
      described_class.perform_now

      expect(eligible.reload).to be_active
    end

    context "when activate! returns false" do
      before do
        allow(Rails.logger).to receive(:warn)
        allow_any_instance_of(Commitment).to receive(:activate!).and_return(false)
      end

      it "logs and completes without raising" do
        expect { described_class.perform_now }.not_to raise_error
        expect(Rails.logger).to have_received(:warn).at_least(:once)
      end
    end

    context "when activate! raises an error" do
      before do
        allow_any_instance_of(Commitment).to receive(:activate!).and_raise(StandardError, "boom")
      end

      it "re-enqueues the job for retry" do
        described_class.perform_later

        expect {
          perform_enqueued_jobs(only: described_class)
        }.to have_enqueued_job(described_class)
      end
    end
  end
end
