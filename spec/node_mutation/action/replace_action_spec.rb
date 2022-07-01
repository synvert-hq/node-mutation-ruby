# frozen_string_literal: true

require 'spec_helper'

RSpec.describe NodeMutation::ReplaceAction do
  context 'replace with single line' do
    subject {
      source = 'FactoryBot.create(:user)'
      node = Parser::CurrentRuby.parse(source)
      NodeMutation::ReplaceAction.new(node, :receiver, :dot, :message, with: 'create').process
    }

    it 'gets start' do
      expect(subject.start).to eq 0
    end

    it 'gets end' do
      expect(subject.end).to eq 'FactoryBot.create'.length
    end

    it 'gets new_code' do
      expect(subject.new_code).to eq 'create'
    end
  end
end
