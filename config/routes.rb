Rails.application.routes.draw do
  root 'users#index'

  devise_for :users

  # в профиле юзера показываем его игры, на главной - список лучших игроков
  resources :users, only: [:index, :show]

  resources :games, only: [:create, :show] do
    put 'help', on: :member # доп. метод ресурса - помощь зала
    put 'answer', on: :member # доп. метод ресурса - ответ на текущий вопрос
    put 'take_money', on: :member # доп. метод ресурса - игрок берет деньги
  end

  # Ресурс в единственном числе - ВопросЫ
  # для загрузки админом сразу пачки вопросОВ
  resource :questions, only: [:new, :create]
end
