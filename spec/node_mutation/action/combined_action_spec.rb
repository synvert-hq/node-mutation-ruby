# frozen_string_literal: true

require 'spec_helper'

RSpec.describe NodeMutation::CombinedAction do
  it 'combines multiple actions' do
    action = described_class.new
    action << double('action1', start: 1, end: 5)
    action << double('action2', start: 3, end: 7)
    action.process
    expect(action.start).to eq(1)
    expect(action.end).to eq(7)
  end
end