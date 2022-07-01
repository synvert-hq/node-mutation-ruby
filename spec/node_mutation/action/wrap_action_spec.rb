# frozen_string_literal: true

require 'spec_helper'

RSpec.describe NodeMutation::WrapAction do
  subject {
    source = "class Bar\nend"
    node = Parser::CurrentRuby.parse(source)
    NodeMutation::WrapAction.new(node, with: 'module Foo').process
  }

  it 'gets start' do
    expect(subject.start).to eq 0
  end

  it 'gets end' do
    expect(subject.end).to eq "class Bar\nend".length
  end

  it 'gets new_code' do
    expect(subject.new_code).to eq <<~EOS.strip
      module Foo
        class Bar
        end
      end
    EOS
  end
end
