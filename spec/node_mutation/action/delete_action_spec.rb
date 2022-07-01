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
end
