# frozen_string_literal: true

require 'spec_helper'

RSpec.describe NodeMutation::AppendAction do
  describe 'class node' do
    subject do
      source = "class User\n  has_many :posts\nend"
      node = Parser::CurrentRuby.parse(source)
      NodeMutation::AppendAction.new(node, "def as_json\n  super\nend").process
    end

    it 'gets start' do
      expect(subject.start).to eq "class User\n  has_many :posts".length
    end

    it 'gets end' do
      expect(subject.end).to eq "class User\n  has_many :posts".length
    end

    it 'gets new_code' do
      expect(subject.new_code).to eq "\n\n  def as_json\n    super\n  end"
    end
  end

  describe 'def node' do
    subject do
      source = "def teardown\n  do_something\nend"
      node = Parser::CurrentRuby.parse(source)
      NodeMutation::AppendAction.new(node, 'super').process
    end

    it 'gets start' do
      expect(subject.start).to eq "def teardown\n  do_something".length
    end

    it 'gets end' do
      expect(subject.end).to eq "def teardown\n  do_something".length
    end

    it 'gets new_code' do
      expect(subject.new_code).to eq "\n  super"
    end
  end
end
