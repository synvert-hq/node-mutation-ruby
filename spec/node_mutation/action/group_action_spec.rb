# frozen_string_literal: true

require 'spec_helper'

RSpec.describe NodeMutation::GroupAction do
  let(:adapter) { NodeMutation::ParserAdapter.new }

  it 'composes of multiple actions' do
    source = 'obj = { foobar: 0 }'
    node = Parser::CurrentRuby.parse(source)
    action =
      described_class.new(adapter: adapter) do
        insert(node, 'foo: 1', to: 'value.pairs.0', at: 'beginning', and_comma: true)
        insert(node, 'bar: 2', to: 'value.pairs.-1', at: 'end', and_comma: true)
      end
    action.process
    expect(action.start).to eq('obj = { '.length)
    expect(action.end).to eq('obj = { foobar: 0'.length)
  end
end
