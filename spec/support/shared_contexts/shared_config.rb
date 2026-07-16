# frozen_string_literal: true

RSpec.shared_context "shared config" do
  let(:json_response) { JSON.parse(response.body, symbolize_names: true) }
  let(:email) { "user@example.com" }
  let(:password) { "Password123!" }
  let(:password_confirmation) { "Password123!" }
  let(:monthly_income) { 5000.0 }
  let(:savings) { 10000.0 }
  let(:currency) { "EUR" }
end
