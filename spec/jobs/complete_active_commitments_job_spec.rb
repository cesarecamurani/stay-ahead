# frozen_string_literal: true

require "rails_helper"

RSpec.describe CompleteActiveCommitmentsJob, type: :job do
  include ActiveJob::TestHelper

  describe "retry configuration" do
    it "retries StandardError" do
      expect(described_class.rescue_handlers.map(&:first)).to include("StandardError")
    end
  end

  describe "#perform" do
    let!(:eligible) do
      create(:commitment, end_date: Date.current - 1.day)
    end
    let!(:no_end_date) { create(:commitment, duration_months: nil) }
    let!(:future_end) do
      create(:commitment, end_date: Date.current + 1.month)
    end
    let!(:scheduled_commitment) { create(:commitment, :scheduled) }

    it "completes active commitments ready for completion" do
      described_class.perform_now

      expect(eligible.reload).to be_completed
    end

    it "does not change commitments outside the scope" do
      described_class.perform_now

      expect(no_end_date.reload).to be_active
      expect(future_end.reload).to be_active
      expect(scheduled_commitment.reload).to be_scheduled
    end

    it "is idempotent on re-run" do
      described_class.perform_now
      described_class.perform_now

      expect(eligible.reload).to be_completed
    end

    context "when complete! returns false" do
      before do
        allow(Rails.logger).to receive(:warn)
        allow_any_instance_of(Commitment).to receive(:complete!).and_return(false)
      end

      it "logs and completes without raising" do
        expect { described_class.perform_now }.not_to raise_error
        expect(Rails.logger).to have_received(:warn).at_least(:once)
      end
    end

    context "when complete! raises an error" do
      before do
        allow_any_instance_of(Commitment).to receive(:complete!).and_raise(StandardError, "boom")
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
