# The event store browser ships with rails_event_store. It is read-only, but it
# exposes every fact and every payload, so it is mounted in development only.
require "rails_event_store/browser" if Rails.env.development?

Rails.application.routes.draw do
  mount RailsEventStore::Browser => "/res" if Rails.env.development?

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

  get "sign-in"  => "sessions#new",     as: :sign_in
  get "sign-up"  => "sessions#sign_up",  as: :sign_up

  root "events#index"

  resources :events, only: :index, param: :tid

  post "events/:event_tid/votes/:direction" => "votes#create",
       as: :event_vote,
       constraints: { direction: /up|down/ }
end
