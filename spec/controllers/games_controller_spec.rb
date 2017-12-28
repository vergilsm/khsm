require 'rails_helper'
require 'support/my_spec_helper.rb'

RSpec.describe GamesController, type: :controller do

  # незалогиненный пользователь
  let(:user) {create(:user)}
  # админ
  let(:admin) {create(:user, is_admin: true)}
  # игра с прописанными игровыми вопросами
  let(:game_w_questions) {create(:game_with_questions, user: user)}

  context 'Anonim_user' do
    it 'kick from #show' do
      get :show, id: game_w_questions.id

      expect(response.status).not_to eq 200
      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:alert]).to be
    end

    it 'kick from #create' do
      post :create

      expect(response.status).not_to eq 200
      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:alert]).to be
    end

    it 'kick from  #answer' do
      put :answer, id: game_w_questions.id

      expect(response.status).not_to eq 200
      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:alert]).to be
    end

    it 'kick from #take_money' do
      put :take_money, id: game_w_questions.id

      expect(response.status).not_to eq 200
      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:alert]).to be
    end
  end

  # группа тестов на экшены контроллера, доступные залогиненному пользователю
  context 'Usual user' do

    # будет выполнятся перед каждым тестом внутри группы
    before(:each) do
      sign_in user
    end

    it 'creates game' do
      generate_questions(60)

      post :create

      game = assigns(:game)

      # проверяем состояние этой игры
      expect(game.finished?).to be_falsy
      expect(game.user).to eq user

      expect(response).to redirect_to game_path(game)
      expect(flash[:notice]).to be
    end

    # юзер видит свою игру
    it 'show game' do
      get :show, id: game_w_questions.id
      game = assigns(:game) # берем из контроллера поле game
      expect(game.finished?).to be_falsy
      expect(game.user).to eq user

      expect(response.status).to eq 200 # должен быть ответ http 200
      expect(response).to render_template('show') # должен отрендерить шаблон show
    end

    it 'answer correct' do
      put :answer, id: game_w_questions.id, letter: game_w_questions.current_game_question.correct_answer_key

      game = assigns(:game)

      expect(game.finished?).to be_falsy
      expect(game.current_level).to be > 0
      expect(response).to redirect_to game_path(game)
      expect(flash.empty?).to be_truthy # верный ответ не заполняет flash
    end

    # юзер ответил не верно
    it 'answer not correct' do
      # даем неверный ответ
      put :answer, id: game_w_questions.id, letter: 'b'

      game = assigns(:game)

      expect(game.finished?).to be_truthy # игра должна быть закончена
      expect(response).to redirect_to user_path(user)
      expect(flash[:alert]).to be
    end

    # проверка на то, что в чужую игру нельзя войти
    it 'show someone elses game' do
      # игра с новым юзером, созданным фабрикой
      alien_game = create(:game_with_questions)

      # пробуем зайти в игру текущим залогиненным пользователем
      get :show, id: alien_game.id

      expect(response.status).not_to eq(200) # статус не 200 ОК
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to be # во flash должна быть прописана ошибка
    end

    # проверка на то, что юзер забирает деньги до завершения игры
    it 'took the money?' do
      # проставляем текущий игровой уровень
      game_w_questions.update_attribute(:current_level, 4)

      put :take_money, id: game_w_questions.id
      game = assigns(:game) # поле game берем из контроллера

      expect(game.finished?).to be_truthy # игра должна быть окончена
      expect(game.prize).to eq 500 # приз равен сумме соответствуюшей уровню

      user.reload # пользователь изменился в БД надо его перезагрузить в коде
      expect(user.balance).to eq 500 # баланс юзера равен сумме приза
      expect(response).to redirect_to user_path(user)
      expect(flash[:warning]).to be
    end

    # тест на попытку создать новую игру, на незаконченной старой
    it 'create second game?' do
      # убедились что есть игра в работе
      expect(game_w_questions.finished?).to be_falsy
      # отправляем запрос на создание, убеждаемся что новых Game не создалось
      expect { post :create }.to change(Game, :count).by(0)

      game = assigns(:game) # поле game берем из контроллера
      expect(game).to be nil

      # редирект на страницу старой игры
      expect(response).to redirect_to game_path(game_w_questions)
      expect(flash[:alert]).to be
    end
  end
end
