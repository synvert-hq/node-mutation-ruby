# frozen_string_literal: true

require 'spec_helper'

RSpec.describe NodeMutation::RemoveAction do
  subject {
    source = "user = User.new params[:user]\nuser.save\nrender\n"
    node = Parser::CurrentRuby.parse(source).children[1]
    NodeMutation::RemoveAction.new(node).process
  }

  it 'gets start' do
    expect(subject.start).to eq "user = User.new params[:user]\n".length
  end

  it 'gets end' do
    expect(subject.end).to eq "user = User.new params[:user]\nuser.save\n".length
  end

  it 'gets new_code' do
    expect(subject.new_code).to eq ''
  end
end
