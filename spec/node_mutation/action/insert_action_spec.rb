# frozen_string_literal: true

require 'spec_helper'

RSpec.describe NodeMutation::InsertAction do
  context 'at end' do
    subject {
      source = "  User.where(username: 'Richard')"
      node = Parser::CurrentRuby.parse(source)
      NodeMutation::InsertAction.new(node, '.first', at: 'end').process
    }

    it 'gets start' do
      expect(subject.start).to eq "  User.where(username: 'Richard')".length
    end

    it 'gets end' do
      expect(subject.end).to eq "  User.where(username: 'Richard')".length
    end

    it 'gets new_code' do
      expect(subject.new_code).to eq '.first'
    end
  end

  context 'at beginning' do
    subject {
      source = "  open('http://test.com')"
      node = Parser::CurrentRuby.parse(source)
      NodeMutation::InsertAction.new(node, 'URI.', at: 'beginning').process
    }

    it 'gets start' do
      expect(subject.start).to eq 2
    end

    it 'gets end' do
      expect(subject.end).to eq 2
    end

    it 'gets new_code' do
      expect(subject.new_code).to eq 'URI.'
    end
  end

  context 'to receiver' do
    subject {
      source = "User.where(username: 'Richard')"
      node = Parser::CurrentRuby.parse(source)
      NodeMutation::InsertAction.new(node, '.active', to: 'receiver', at: 'end').process
    }

    it 'gets start' do
      expect(subject.start).to eq "User".length
    end

    it 'gets end' do
      expect(subject.end).to eq "User".length
    end

    it 'gets new_code' do
      expect(subject.new_code).to eq '.active'
    end
  end
end
