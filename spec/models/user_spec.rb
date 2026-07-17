# frozen_string_literal: true

require "rails_helper"

RSpec.describe User, type: :model do
  subject(:user) { build(:user, currency:) }

  let(:currency) { "EUR" }

  describe "validations" do
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email).case_insensitive }
    it { is_expected.to validate_presence_of(:username) }
    it { is_expected.to validate_uniqueness_of(:username).case_insensitive }
    it { is_expected.to validate_length_of(:username).is_at_least(3).is_at_most(30) }
    it { is_expected.to allow_value("jane_doe").for(:username) }
    it { is_expected.to allow_value("user123").for(:username) }
    it { is_expected.not_to allow_value("ab").for(:username) }
    it { is_expected.not_to allow_value("user@name").for(:username) }
    it { is_expected.not_to allow_value("User Name").for(:username) }
    it { is_expected.to validate_numericality_of(:monthly_income).is_greater_than_or_equal_to(0).allow_nil }
    it { is_expected.to validate_numericality_of(:savings).is_greater_than_or_equal_to(0).allow_nil }

    context "when creating a user" do
      subject(:user) { build(:user, password:, password_confirmation:) }

      let(:password) { "Password123!" }
      let(:password_confirmation) { "Password123!" }

      context "when password is missing" do
        let(:password) { nil }
        let(:password_confirmation) { nil }

        it "requires a password" do
          expect(user).not_to be_valid
          expect(user.errors[:password]).to include("can't be blank")
        end
      end

      context "when password confirmation is missing" do
        let(:password_confirmation) { nil }

        it "requires password confirmation" do
          expect(user).not_to be_valid
          expect(user.errors[:password_confirmation]).to include("can't be blank")
        end
      end

      context "when password confirmation matches" do
        it "is valid" do
          expect(user).to be_valid
        end
      end

      context "when password confirmation does not match" do
        let(:password_confirmation) { "Different123!" }

        it "is invalid" do
          expect(user).not_to be_valid
          expect(user.errors[:password_confirmation]).to include("doesn't match Password")
        end
      end

      context "when password is too short" do
        let(:password) { "Short1!" }
        let(:password_confirmation) { password }

        it "is invalid" do
          expect(user).not_to be_valid
          expect(user.errors[:password]).to include("must be at least 12 characters")
        end
      end

      context "when password has no uppercase letter" do
        let(:password) { "password123!" }
        let(:password_confirmation) { password }

        it "is invalid" do
          expect(user).not_to be_valid
          expect(user.errors[:password]).to include("must contain at least one uppercase letter")
        end
      end

      context "when password has no lowercase letter" do
        let(:password) { "PASSWORD123!" }
        let(:password_confirmation) { password }

        it "is invalid" do
          expect(user).not_to be_valid
          expect(user.errors[:password]).to include("must contain at least one lowercase letter")
        end
      end

      context "when password has no number" do
        let(:password) { "Password!!!!" }
        let(:password_confirmation) { password }

        it "is invalid" do
          expect(user).not_to be_valid
          expect(user.errors[:password]).to include("must contain at least one number")
        end
      end

      context "when password has no special character" do
        let(:password) { "Password1234" }
        let(:password_confirmation) { password }

        it "is invalid" do
          expect(user).not_to be_valid
          expect(user.errors[:password]).to include("must contain at least one special character")
        end
      end
    end
  end

  describe "#valid_currency?" do
    context "when currency is blank" do
      let(:currency) { nil }

      before { user.validate }

      it "does not add an error" do
        expect(user.errors[:currency]).to be_empty
      end
    end

    context "when currency is valid" do
      before { user.validate }

      it "does not add an error" do
        expect(user.errors[:currency]).to be_empty
      end

      it "accepts other valid currencies" do
        expect(user.errors[:currency]).to be_empty
      end
    end

    context "when currency is invalid" do
      let(:currency) { "XXX" }
      let(:error_message) { "#{currency} is not a valid currency" }

      before { user.validate }

      it "adds an error" do
        expect(user.errors[:currency]).to include(error_message)
      end

      it "marks the user as invalid" do
        expect(user).to be_invalid
      end
    end
  end
end
