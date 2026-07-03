Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :users, only: %i[create]
      resources :commitments, only: %i[index create show update] do
        member do
          post :pause
          post :cancel
          post :resume
        end
      end

      post   "/login",  to: "auth#login"
      delete "/logout", to: "auth#logout"

      get    "/me",     to: "users#me"
      patch  "/me",     to: "users#update"

      get "/summary",   to: "summary#show"
      get "/breakdown", to: "breakdown#show"
    end
  end
end
