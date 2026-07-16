# frozen_string_literal: true

require "rails_helper"

RSpec.describe PasswordComplexityValidator do
  subject(:model) { test_model_class.new(password:) }

  let(:test_model_class) do
    Class.new do
      include ActiveModel::Model
      include ActiveModel::Validations

      attr_accessor :password

      validates :password, password_complexity: true

      def self.name
        "PasswordComplexityTestModel"
      end
    end
  end

  let(:password) { "Password123!" }
  let(:errors) { model.errors[:password] }

  before { model.validate }

  it "is valid with a complex password" do
    expect(errors).to be_empty
  end

  context "when password is blank" do
    let(:password) { nil }

    it "does not add complexity errors" do
      expect(errors).to be_empty
    end
  end

  context "when password is too short" do
    let(:password) { "Short1!" }

    it "adds a length error" do
      expect(errors).to include("must be at least 12 characters")
    end
  end

  context "when password has no uppercase letter" do
    let(:password) { "password123!" }

    it "adds an uppercase error" do
      expect(errors).to include("must contain at least one uppercase letter")
    end
  end

  context "when password has no lowercase letter" do
    let(:password) { "PASSWORD123!" }

    it "adds a lowercase error" do
      expect(errors).to include("must contain at least one lowercase letter")
    end
  end

  context "when password has no number" do
    let(:password) { "Password!!!!" }

    it "adds a number error" do
      expect(errors).to include("must contain at least one number")
    end
  end

  context "when password has no special character" do
    let(:password) { "Password1234" }

    it "adds a special character error" do
      expect(errors).to include("must contain at least one special character")
    end
  end
end
