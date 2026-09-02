# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserSerializer do
  subject(:serializer) { described_class.new(user, compact:) }

  let(:user) { build(:user, monthly_income:, savings:, protected_savings:, currency:) }
  let(:monthly_income) { BigDecimal("5000.00") }
  let(:savings) { BigDecimal("15000.00") }
  let(:protected_savings) { BigDecimal("5000.00") }
  let(:currency) { "EUR" }
  let(:compact) { false }

  let(:result) { serializer.serialize }

  describe "#serialize" do
    context "with full profile" do
      it "returns id and email" do
        expect(result).to include(id: user.id, email: user.email, username: user.username)
      end

      it "formats monthly_income as money" do
        expect(result[:monthly_income]).to eq("5000.00")
      end

      it "formats savings as money" do
        expect(result[:savings]).to eq("15000.00")
      end

      it "formats protected savings as money" do
        expect(result[:protected_savings]).to eq("5000.00")
      end

      it "returns currency" do
        expect(result[:currency]).to eq("EUR")
      end

      context "when monthly_income is nil" do
        let(:monthly_income) { nil }

        it "returns nil for monthly_income" do
          expect(result[:monthly_income]).to be_nil
        end
      end

      context "when savings is nil" do
        let(:savings) { nil }

        it "returns nil for savings" do
          expect(result[:savings]).to be_nil
        end
      end

      context "when protected savings is nil" do
        let(:protected_savings) { nil }

        it "returns nil for protected savings" do
          expect(result[:protected_savings]).to be_nil
        end
      end
    end

    context "with compact mode" do
      let(:compact) { true }

      it "returns only id, email, and username" do
        expect(result).to eq(id: user.id, email: user.email, username: user.username)
      end

      it "does not include profile fields" do
        expect(result).not_to have_key(:monthly_income)
        expect(result).not_to have_key(:savings)
        expect(result).not_to have_key(:protected_savings)
        expect(result).not_to have_key(:currency)
      end
    end
  end
end
