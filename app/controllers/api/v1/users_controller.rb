# frozen_string_literal: true

module Api
  module V1
    class UsersController < ApplicationController
      before_action :authenticate_user!, only: %i[me update]

      def create
        user = User.new(user_params)

        if user.save
          present_user(
            user,
            status: :created,
            compact: true,
            message: "registered",
            token: JwtService.encode(user_id: user.id)
          )
        else
          render json: { errors: user.errors.full_messages },
                 status: :unprocessable_entity
        end
      end

      def update
        if current_user.update(profile_params)
          present_user(current_user)
        else
          render json: { errors: current_user.errors.full_messages },
                 status: :unprocessable_entity
        end
      end

      def me
        present_user(current_user)
      end

      private

      def user_params
        params.require(:user).permit(
          :email,
          :username,
          :password,
          :password_confirmation,
          :monthly_income,
          :savings,
          :currency
        )
      end

      def profile_params
        params.require(:user).permit(
          :username,
          :monthly_income,
          :savings,
          :currency
        )
      end
    end
  end
end
