# frozen_string_literal: true

require 'spec_helper'

RSpec.describe NodeMutation::DeleteAction do
  subject {
    source = 'arr.map {}.flatten'
    node = Parser::CurrentRuby.parse(source)
    NodeMutation::DeleteAction.new(node, :dot, :message).process
  }

  it 'gets start' do
    expect(subject.start).to eq 'arr.map {}'.length
  end

  it 'gets end' do
    expect(subject.end).to eq 'arr.map {}.flatten'.length
  end

  it 'gets new_code' do
    expect(subject.new_code).to eq ''
  end

  context 'leading and_comma' do
    subject {
      source = 'foobar(foo, bar)'
      node = Parser::CurrentRuby.parse(source)
      NodeMutation::DeleteAction.new(node, 'arguments.-1', and_comma: true).process
    }

    it 'gets start' do
      expect(subject.start).to eq 'foobar(foo'.length
    end

    it 'gets end' do
      expect(subject.end).to eq 'foobar(foo, bar'.length
    end

    it 'gets new_code' do
      expect(subject.new_code).to eq ''
    end
  end

  context 'trailing and_comma' do
    subject {
      source = 'foobar(foo, bar)'
      node = Parser::CurrentRuby.parse(source)
      NodeMutation::DeleteAction.new(node, 'arguments.0', and_comma: true).process
    }

    it 'gets start' do
      expect(subject.start).to eq 'foobar('.length
    end

    it 'gets end' do
      expect(subject.end).to eq 'foobar(foo, '.length
    end

    it 'gets new_code' do
      expect(subject.new_code).to eq ''
    end
  end
end
