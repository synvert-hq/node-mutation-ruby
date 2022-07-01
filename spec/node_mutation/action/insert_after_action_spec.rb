# frozen_string_literal: true

require 'spec_helper'

RSpec.describe NodeMutation::InsertAfterAction do
  subject {
    source = '  include Foo'
    node = Parser::CurrentRuby.parse(source)
    NodeMutation::InsertAfterAction.new(node, 'include Bar').process
  }

  it 'gets start' do
    expect(subject.start).to eq '  include Foo'.length
  end

  it 'gets end' do
    expect(subject.end).to eq '  include Foo'.length
  end

  it 'gets new_code' do
    expect(subject.new_code).to eq "\n  include Bar"
  end
end
