require 'rails_helper'
require 'support/my_spec_helper' # наш собственный класс с вспомогательными методами

RSpec.describe Game, type: :model do
  # пользователь для создания игр
  let(:user) {create(:user)}

  # игра с прописанными игровыми вопросами
  let(:game_w_questions) {create(:game_with_questions, user: user)}

  # Группа тестов на работу фабрики создания новых игр
  context 'Game Factory' do
    it 'Game.create_game! new correct game' do
      # генерим 60 вопросов с 4х запасом по полю level,
      # чтобы проверить работу RANDOM при создании игры
      generate_questions(60)

      game = nil
      # создaли игру, обернули в блок, на который накладываем проверки
      expect {
        game = Game.create_game_for_user!(user)
      }.to change(Game, :count).by(1).and(# проверка: Game.count изменился на 1 (создали в базе 1 игру)
        change(GameQuestion, :count).by(15).and(# GameQuestion.count +15
          change(Question, :count).by(0) # Game.count не должен измениться
        )
      )
      # проверяем статус и поля
      expect(game.user).to eq(user)
      expect(game.status).to eq(:in_progress)
      # проверяем корректность массива игровых вопросов
      expect(game.game_questions.size).to eq(15)
      expect(game.game_questions.map(&:level)).to eq (0..14).to_a
    end
  end

  # тесты на основную игровую логику
  context 'game mechanics' do

    # правильный ответ должен продолжать игру
    it 'answer correct continues game' do
      # текущий уровень игры и статус
      level = game_w_questions.current_level
      q = game_w_questions.current_game_question
      expect(game_w_questions.status).to eq(:in_progress)

      game_w_questions.answer_current_question!(q.correct_answer_key)

      # перешли на след. уровень
      expect(game_w_questions.current_level).to eq(level + 1)
      # ранее текущий вопрос стал предыдущим
      expect(game_w_questions.previous_game_question).to eq(q)
      expect(game_w_questions.current_game_question).not_to eq(q)
      # игра продолжается
      expect(game_w_questions.status).to eq(:in_progress)
      expect(game_w_questions.finished?).to be_falsey
    end

    # тест проверяет что юзеру зачислены деньги на счет и игра закончена
    it 'take money and finish the game' do
      # игра с новым вопросом
      q = game_w_questions.current_game_question
      # отвечаем правильно на вопрос
      game_w_questions.answer_current_question!(q.correct_answer_key)
      # забираем деньги
      game_w_questions.take_money!

      # Проверяем наличие приза
      prize = game_w_questions.prize
      expect(prize).to be > 0

      expect(game_w_questions.status).to eq :money
      expect(game_w_questions.finished?).to be_truthy
      expect(user.balance).to eq prize
    end

    # тесты на проверку результатов статуса игры
    # :won :fail :money :timeout
    context 'status' do

      # перед каждым тестом "завершаем игру"
      before(:each) do
        game_w_questions.finished_at = Time.now
        expect(game_w_questions.finished?).to be_truthy
      end

      it 'fail' do
        game_w_questions.is_failed = true
        expect(game_w_questions.status).to eq :fail
      end

      it 'timeout' do
        game_w_questions.created_at = 36.minutes.ago
        game_w_questions.is_failed = true
        expect(game_w_questions.status).to eq :timeout
      end

      it 'won' do
        game_w_questions.current_level = Question::QUESTION_LEVELS.max + 1
        expect(game_w_questions.status).to eq :won
      end

      it 'money' do
        game_w_questions.prize = 0
        expect(game_w_questions.status).to eq :money
      end
    end

    # тесты на методы доступа к состоянию игры
    context 'game condition' do

      # текущий неотвеченный вопрос
      it 'current_game_question' do
        expect(game_w_questions.current_game_question).to eq game_w_questions.game_questions[0]
      end

      # отвеченный вопрос игры
      it 'previous_game_question' do
        game_w_questions.current_level = 4
        expect(game_w_questions.previous_game_question).to eq game_w_questions.game_questions[3]
      end

      # для новой игры -1
      it 'previous_level' do
        game_w_questions.current_level = 2
        expect(game_w_questions.previous_level).to eq 1
      end
    end

    # группа тестов с разными ответами на текущий вопрос
    context 'answer_current_question!' do

      # ответ верный
      it 'correct answer' do
        game_w_questions.answer_current_question!('d')
        expect(game_w_questions.status).to eq(:in_progress)
      end

      # ответ неверный
      it 'incorrect answer' do
        game_w_questions.answer_current_question!('a')
        expect(game_w_questions.status).to eq :fail
      end

      # последний ответ(на миллион)
      it 'last answer' do
        user_before_balance = user.balance
        game_w_questions.current_level = Question::QUESTION_LEVELS.max
        game_w_questions.answer_current_question!('d')

        expect(game_w_questions.prize).to eq(Game::PRIZES[Question::QUESTION_LEVELS.max])
        expect(user.balance).to eq(user_before_balance + game_w_questions.prize)
        expect(game_w_questions.status).to eq :won
      end

      # ответ дан после изтечения времени
      it 'answer after the end of time' do
        game_w_questions.created_at = 36.minutes.ago

        expect(game_w_questions.answer_current_question!(game_w_questions.current_game_question.correct_answer_key)).to be_falsey
        expect(game_w_questions.status).to eq :timeout
      end
    end
  end
end
