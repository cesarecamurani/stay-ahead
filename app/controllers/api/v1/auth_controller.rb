# frozen_string_literal: true

module Api
  module V1
    class AuthController < ApplicationController
      def login
        user = User.find_by(email: params[:email])

        unless user
          render json: { error: "Invalid email or password" }, status: :unauthorized
          return
        end

        if user.authenticate(params[:password])
          present_user(
            user,
            compact: true,
            message: "logged_in",
            token: JwtService.encode(user_id: user.id)
          )
        else
          render json: { error: "invalid_credentials" }, status: :unauthorized
        end
      end

      def logout
        render json: { message: "logged_out" }, status: :ok
      end
    end
  end
end
