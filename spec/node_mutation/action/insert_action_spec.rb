# frozen_string_literal: true

require 'spec_helper'

RSpec.describe NodeMutation::InsertAction do
  let(:adapter) { NodeMutation::ParserAdapter.new }

  context 'at end' do
    subject {
      source = "  User.where(username: 'Richard')"
      node = Parser::CurrentRuby.parse(source)
      NodeMutation::InsertAction.new(node, '.first', at: 'end', adapter: adapter).process
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
      NodeMutation::InsertAction.new(node, 'URI.', at: 'beginning', adapter: adapter).process
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
      NodeMutation::InsertAction.new(node, '.active', to: 'receiver', at: 'end', adapter: adapter).process
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

  context 'trailing add_comma' do
    subject {
      source = <<~EOS
        obj = { foo: 1 }
      EOS
      node = Parser::CurrentRuby.parse(source)
      NodeMutation::InsertAction.new(
        node,
        'bar: 2',
        to: 'value.pairs.0',
        at: 'end',
        and_comma: true,
        adapter: adapter
      ).process
    }

    it 'gets start' do
      expect(subject.start).to eq "obj = { foo: 1".length
    end

    it 'gets end' do
      expect(subject.end).to eq "obj = { foo: 1".length
    end

    it 'gets new_code' do
      expect(subject.new_code).to eq ', bar: 2'
    end
  end

  context 'leading add_comma' do
    subject {
      source = <<~EOS
        obj = { bar: 2 }
      EOS
      node = Parser::CurrentRuby.parse(source)
      NodeMutation::InsertAction.new(
        node,
        'foo: 1',
        to: 'value.pairs.0',
        at: 'beginning',
        and_comma: true,
        adapter: adapter
      ).process
    }

    it 'gets start' do
      expect(subject.start).to eq "obj = { ".length
    end

    it 'gets end' do
      expect(subject.end).to eq "obj = { ".length
    end

    it 'gets new_code' do
      expect(subject.new_code).to eq 'foo: 1, '
    end
  end
end
