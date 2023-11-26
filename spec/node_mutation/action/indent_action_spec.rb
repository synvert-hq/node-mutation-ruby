# frozen_string_literal: true

require 'spec_helper'

RSpec.describe NodeMutation::IndentAction do
  let(:adapter) { NodeMutation::ParserAdapter.new }
  let(:source) { "  foo\n  bar\n  foobar" }

  subject {
    node = Parser::CurrentRuby.parse(source)
    NodeMutation::IndentAction.new(node, adapter: adapter).process
  }

  it 'gets start' do
    expect(subject.start).to eq '  '.length
  end

  it 'gets end' do
    expect(subject.end).to eq source.length
  end

  it 'gets new_code' do
    expect(subject.new_code).to eq "  foo\n    bar\n    foobar"
  end
end
