Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  # Defines the root path route ("/")
  # Only where the fake verifier is configured; production signs in via Clerk.
  if Rails.configuration.x.clerk.dev_sign_in
    post "dev-session" => "dev_sessions#create", as: :dev_session
    delete "dev-session" => "dev_sessions#destroy"
  end

  root "events#index"

  resources :events, only: :index, param: :tid

  post "events/:event_tid/votes/:direction" => "votes#create",
       as: :event_vote,
       constraints: { direction: /up|down/ }
end
