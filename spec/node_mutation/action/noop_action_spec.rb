# frozen_string_literal: true

require 'spec_helper'

RSpec.describe NodeMutation::NoopAction do
  let(:adapter) { NodeMutation::ParserAdapter.new }

  subject {
    source = 'post = FactoryGirl.create_list :post, 2'
    node = Parser::CurrentRuby.parse(source).children[1]
    NodeMutation::NoopAction.new(node, adapter: adapter).process
  }

  it 'gets start' do
    expect(subject.start).to eq 'post = '.length
  end

  it 'gets end' do
    expect(subject.end).to eq 'post = FactoryGirl.create_list :post, 2'.length
  end

  it 'gets new_code' do
    expect(subject.new_code).to be_nil
  end
end
