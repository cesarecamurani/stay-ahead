# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Users", type: :request do
  include_context "shared config"

  describe "POST /api/v1/users" do
    context "with valid parameters" do
      let(:valid_attributes) do
        {
          email:,
          username:,
          password:,
          password_confirmation:,
          monthly_income:,
          savings:,
          protected_savings:,
          currency:
        }
      end

      subject(:send_request) { post "/api/v1/users", params: { user: valid_attributes } }

      it "creates a user" do
        expect { send_request }.to change(User, :count).by(1)
      end

      it "stores the user's protected savings preference" do
        send_request

        expect(User.order(:created_at).last.protected_savings).to eq(BigDecimal("3000"))
      end

      context "when the request is sent" do
        before { send_request }

        it "returns created status" do
          expect(response).to have_http_status(:created)
        end

        it "returns a token" do
          expect(json_response[:token]).to be_present
        end

        it "returns user email" do
          expect(json_response[:user][:email]).to eq(email)
        end

        it "returns user username" do
          expect(json_response[:user][:username]).to eq(username)
        end

        it "returns user id" do
          expect(json_response[:user][:id]).to be_present
        end

        it "returns registered message" do
          expect(json_response[:message]).to eq("registered")
        end

        it "does not expose sensitive fields" do
          expect(json_response[:user]).not_to have_key(:password_digest)
        end
      end
    end

    context "with missing email" do
      let(:invalid_attributes) { { username:, password:, password_confirmation: } }

      before { post "/api/v1/users", params: { user: invalid_attributes } }

      it "does not create a user" do
        expect(User.count).to eq(0)
      end

      it "returns unprocessable_entity status" do
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns error messages" do
        expect(json_response[:errors]).to include("Email can't be blank")
      end
    end

    context "with missing password" do
      let(:invalid_attributes) { { email:, username:, password_confirmation: } }

      before { post "/api/v1/users", params: { user: invalid_attributes } }

      it "does not create a user" do
        expect(User.count).to eq(0)
      end

      it "returns unprocessable_entity status" do
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns error messages" do
        expect(json_response[:errors]).to include("Password can't be blank")
      end
    end

    context "with missing password confirmation" do
      let(:invalid_attributes) { { email:, username:, password: } }

      before { post "/api/v1/users", params: { user: invalid_attributes } }

      it "does not create a user" do
        expect(User.count).to eq(0)
      end

      it "returns unprocessable_entity status" do
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns error messages" do
        expect(json_response[:errors]).to include("Password confirmation can't be blank")
      end
    end

    context "with mismatched password confirmation" do
      let(:invalid_attributes) do
        {
          email:,
          username:,
          password:,
          password_confirmation: "Different123!"
        }
      end

      before { post "/api/v1/users", params: { user: invalid_attributes } }

      it "does not create a user" do
        expect(User.count).to eq(0)
      end

      it "returns unprocessable_entity status" do
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns error messages" do
        expect(json_response[:errors]).to include("Password confirmation doesn't match Password")
      end
    end

    context "with missing username" do
      let(:invalid_attributes) { { email:, password:, password_confirmation: } }

      before { post "/api/v1/users", params: { user: invalid_attributes } }

      it "does not create a user" do
        expect(User.count).to eq(0)
      end

      it "returns unprocessable_entity status" do
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns error messages" do
        expect(json_response[:errors]).to include("Username can't be blank")
      end
    end

    context "with duplicate username" do
      let(:invalid_attributes) do
        {
          email: "other@example.com",
          username:,
          password:,
          password_confirmation:
        }
      end

      before do
        create(:user, username:)
        post "/api/v1/users", params: { user: invalid_attributes }
      end

      it "does not create a user" do
        expect(User.count).to eq(1)
      end

      it "returns unprocessable_entity status" do
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns error messages" do
        expect(json_response[:errors]).to include("Username has already been taken")
      end
    end
  end
end
