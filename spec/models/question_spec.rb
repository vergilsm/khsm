require 'rails_helper'

RSpec.describe Question, type: :model do

  context 'validation check' do
    it {should validate_presence_of :text}
    it {should validate_presence_of :level}

    subject {FactoryBot.create(:question)}
    it {should validate_uniqueness_of(:text).case_insensitive}

    it {should validate_inclusion_of(:level).in_range(0..14)}

    # произвольная валидация
    it {should allow_value(14).for(:level)}
    it {should_not allow_value(15).for(:level)}
  end
end
