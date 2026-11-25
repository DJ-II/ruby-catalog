Rails.application.routes.draw do
  get 'up' => 'rails/health#show', as: :rails_health_check
  root 'home#index'
  get 'search', to: 'search#index', as: :search
  get 'tags/suggest', to: 'tags#index', as: :tag_suggestions

  get 'signup', to: 'registrations#new', as: :signup
  post 'signup', to: 'registrations#create'
  get 'login', to: 'sessions#new', as: :login
  post 'login', to: 'sessions#create'
  delete 'logout', to: 'sessions#destroy', as: :logout

  match 'auth/:provider/callback', to: 'oauth_callbacks#callback', via: [:get, :post], as: :oauth_callback
  get 'auth/failure', to: 'oauth_callbacks#failure', as: :oauth_failure
  get 'account/preferences', to: 'account/preferences#show', as: :account_preferences
  patch 'account/preferences', to: 'account/preferences#update'
  get 'account/connections', to: 'account/connections#index', as: :account_connections
  delete 'account/connections/:provider', to: 'account/connections#destroy', as: :account_connection

  delete 'users/:user_id/inventories/bulk_destroy', to: 'user_inventories#bulk_destroy', as: :bulk_destroy_user_inventories
  resources :users, only: :show
  resources :inventories do
    get :statistics, on: :member
    get :export, on: :member, to: 'inventory_exports#show'
    resource :fields, controller: :inventory_fields, only: [:edit, :update]
    resource :id_parts, controller: :inventory_id_parts, only: [:edit, :update]
    resources :accesses, controller: :inventory_accesses, only: [:index, :create] do
      get :suggest, on: :collection
      delete :bulk_destroy, on: :collection
    end
    resources :comments, path: :discussion, controller: :inventory_comments, only: [:index, :create]
    resources :items, except: :index do
      resource :like, controller: :item_likes, only: [:create, :destroy]
      delete :bulk_destroy, on: :collection
    end
  end
  namespace :admin do
    resources :users, only: [:index, :update, :destroy] do
      patch :manage, on: :collection
    end
  end
end
