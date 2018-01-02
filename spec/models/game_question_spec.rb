require 'rails_helper'

RSpec.describe GameQuestion, type: :model do

  let(:game_question) {create(:game_question, a: 2, b: 1, c: 4, d: 3)}

  context 'game status' do
    it 'correct .variants' do
      expect(game_question.variants).to eq({'a' => game_question.question.answer2,
                                            'b' => game_question.question.answer1,
                                            'c' => game_question.question.answer4,
                                            'd' => game_question.question.answer3,
                                          })
    end

    it 'correct .answer_correct?' do
      expect(game_question.answer_correct?('b')).to be_truthy
    end

    it 'correct .text and .level delegate' do
      expect(game_question.text).to eq game_question.question.text
      expect(game_question.level).to eq game_question.question.level
    end

    it 'correct_answer_key' do
      expect(game_question.correct_answer_key).to eq 'b'
    end
  end

  # группа тестов на помощь игроку
  context 'user helpers' do
    it 'correct audience_help' do
      # убедимся что подсказки есть, пока нет нужного ключа
      expect(game_question.help_hash).not_to include(:audience_help)

      # вызываем подсказку
      game_question.add_audience_help
      # мы не можем знать распределение, но можем проверить хотя бы наличие нужных ключей
      expect(game_question.help_hash).to include(:audience_help)
      expect(game_question.help_hash[:audience_help].keys).to contain_exactly('a', 'b', 'c', 'd')
    end
  end
end
