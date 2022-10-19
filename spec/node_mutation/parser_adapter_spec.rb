# frozen_string_literal: true

require 'spec_helper'

RSpec.describe NodeMutation::ParserAdapter do
  let(:adapter) { described_class.new }

  describe '#get_source' do
    it 'gets for node' do
      source = 'params[:user][:email]'
      node = parse(source)
      expect(adapter.get_source(node)).to eq source
    end
  end

  describe '#rewritten_source' do
    it 'does not rewrite with unknown method' do
      source = 'class Synvert; end'
      node = parse(source)
      expect(adapter.rewritten_source(node, '{{foobar}}')).to eq '{{foobar}}'
    end

    it 'rewrites with node known method' do
      source = 'class Synvert; end'
      node = parse(source)
      expect(adapter.rewritten_source(node, '{{name}}')).to eq 'Synvert'
    end

    it 'rewrites for arguments' do
      source = 'test { |a, b| }'
      node = parse(source)
      expect(adapter.rewritten_source(node, '{{arguments}}')).to eq 'a, b'
    end

    it 'rewrites array with multi line given as argument for method' do
      source = <<~EOS.strip
        long_name_method([
          1,
          2,
          3
        ])
      EOS

      node = parse(source)
      expect(adapter.rewritten_source(node, '{{arguments}}')).to eq <<~EOS.strip
        [
          1,
          2,
          3
        ]
      EOS
    end

    it 'raises an error for unknown code' do
      source = 'Notifications::Updater.expects(:new).returns(@srv)'
      node = parse(source)
      expect {
        adapter.rewritten_source(node, '{{receiver.receiver}}).to receive({{receiver.arguments.first}).and_return({{caller.arguments.first}}')
      }.to raise_error('can not parse "{{receiver.receiver}}).to receive({{receiver.arguments.first}).and_return({{caller.arguments.first}}"')
    end
  end

  describe '#file_content' do
    it 'gets content of file' do
      source = <<~EOS
        class Synvert
          def foobar; end
        end
      EOS
      node = parse(source).body.first
      expect(adapter.file_content(node)).to eq source
    end
  end

  describe '#child_node_range' do
    context 'block node' do
      it 'checks caller' do
        node = parse('Factory.define :user do |user|; end')
        range = adapter.child_node_range(node, :caller)
        expect(range.start).to eq 0
        expect(range.end).to eq 20
      end

      it 'checks arguments' do
        node = parse('Factory.define :user do |user|; end')
        range = adapter.child_node_range(node, :arguments)
        expect(range.start).to eq 25
        expect(range.end).to eq 29
      end

      it 'checks pipes' do
        node = parse('Factory.define :user do |user|; end')
        range = adapter.child_node_range(node, :pipes)
        expect(range.start).to eq 24
        expect(range.end).to eq 30
      end

      it 'checks caller.receiver' do
        node = parse('Factory.define :user do |user|; end')
        range = adapter.child_node_range(node, 'caller.receiver')
        expect(range.start).to eq 0
        expect(range.end).to eq 7
      end

      it 'checks caller.message' do
        node = parse('Factory.define :user do |user|; end')
        range = adapter.child_node_range(node, 'caller.message')
        expect(range.start).to eq 8
        expect(range.end).to eq 14
      end
    end

    context 'class node' do
      it 'checks name' do
        node = parse('class Post < ActiveRecord::Base; end')
        range = adapter.child_node_range(node, :name)
        expect(range.start).to eq 6
        expect(range.end).to eq 10
      end

      it 'checks parent_class' do
        node = parse('class Post < ActiveRecord::Base; end')
        range = adapter.child_node_range(node, :parent_class)
        expect(range.start).to eq 13
        expect(range.end).to eq 31

        node = parse('class Post; end')
        range = adapter.child_node_range(node, :parent_class)
        expect(range).to be_nil
      end
    end

    context 'const node' do
      it 'checks name' do
        node = parse('Synvert')
        range = adapter.child_node_range(node, :name)
        expect(range.start).to eq 0
        expect(range.end).to eq 'Synvert'.length
      end
    end

    context 'csend node' do
      it 'checks receiver' do
        node = parse('foo&.bar(test)')
        range = adapter.child_node_range(node, :receiver)
        expect(range.start).to eq 0
        expect(range.end).to eq 3
      end

      it 'checks dot' do
        node = parse('foo&.bar(test)')
        range = adapter.child_node_range(node, :dot)
        expect(range.start).to eq 3
        expect(range.end).to eq 5
      end

      it 'checks message' do
        node = parse('foo&.bar(test)')
        range = adapter.child_node_range(node, :message)
        expect(range.start).to eq 5
        expect(range.end).to eq 8

        node = parse('foo&.bar = test')
        range = adapter.child_node_range(node, :message)
        expect(range.start).to eq 5
        expect(range.end).to eq 10
      end

      it 'checks arguments' do
        node = parse('foo&.bar(test)')
        range = adapter.child_node_range(node, :arguments)
        expect(range.start).to eq 9
        expect(range.end).to eq 13

        node = parse('foo&.bar')
        range = adapter.child_node_range(node, :arguments)
        expect(range).to be_nil
      end

      it 'checks parentheses' do
        node = parse('foo&.bar(test)')
        range = adapter.child_node_range(node, :parentheses)
        expect(range.start).to eq 8
        expect(range.end).to eq 14

        node = parse('foo&.bar')
        range = adapter.child_node_range(node, :parentheses)
        expect(range).to be_nil
      end
    end

    context 'def node' do
      it 'checks name' do
        node = parse('def foo(bar); end')
        range = adapter.child_node_range(node, :name)
        expect(range.start).to eq 4
        expect(range.end).to eq 7
      end

      it 'checks arguments' do
        node = parse('def foo(bar); end')
        range = adapter.child_node_range(node, :arguments)
        expect(range.start).to eq 8
        expect(range.end).to eq 11
      end

      it 'checks parentheses' do
        node = parse('def foo(bar); end')
        range = adapter.child_node_range(node, :parentheses)
        expect(range.start).to eq 7
        expect(range.end).to eq 12
      end
    end

    context 'defs node' do
      it 'checks self' do
        node = parse('def self.foo(bar); end')
        range = adapter.child_node_range(node, :self)
        expect(range.start).to eq 4
        expect(range.end).to eq 8
      end

      it 'checks dot' do
        node = parse('def self.foo(bar); end')
        range = adapter.child_node_range(node, :dot)
        expect(range.start).to eq 8
        expect(range.end).to eq 9
      end

      it 'checks name' do
        node = parse('def self.foo(bar); end')
        range = adapter.child_node_range(node, :name)
        expect(range.start).to eq 9
        expect(range.end).to eq 12
      end

      it 'checks arguments' do
        node = parse('def self.foo(bar); end')
        range = adapter.child_node_range(node, :arguments)
        expect(range.start).to eq 13
        expect(range.end).to eq 16
      end

      it 'checks parentheses' do
        node = parse('def self.foo(bar); end')
        range = adapter.child_node_range(node, :parentheses)
        expect(range.start).to eq 12
        expect(range.end).to eq 17
      end
    end

    context 'send node' do
      it 'checks receiver' do
        node = parse('foo.bar(test)')
        range = adapter.child_node_range(node, :receiver)
        expect(range.start).to eq 0
        expect(range.end).to eq 3

        node = parse('foobar(test)')
        range = adapter.child_node_range(node, :receiver)
        expect(range).to be_nil
      end

      it 'checks dot' do
        node = parse('foo.bar(test)')
        range = adapter.child_node_range(node, :dot)
        expect(range.start).to eq 3
        expect(range.end).to eq 4

        node = parse('foobar(test)')
        range = adapter.child_node_range(node, :dot)
        expect(range).to be_nil
      end

      it 'checks message' do
        node = parse('foo.bar(test)')
        range = adapter.child_node_range(node, :message)
        expect(range.start).to eq 4
        expect(range.end).to eq 7

        node = parse('foo.bar = test')
        range = adapter.child_node_range(node, :message)
        expect(range.start).to eq 4
        expect(range.end).to eq 9

        node = parse('foobar(test)')
        range = adapter.child_node_range(node, :message)
        expect(range.start).to eq 0
        expect(range.end).to eq 6
      end

      it 'checks arguments' do
        node = parse('foo.bar(test)')
        range = adapter.child_node_range(node, :arguments)
        expect(range.start).to eq 8
        expect(range.end).to eq 12

        node = parse('foobar(test)')
        range = adapter.child_node_range(node, :arguments)
        expect(range.start).to eq 7
        expect(range.end).to eq 11

        node = parse('foo.bar')
        range = adapter.child_node_range(node, :arguments)
        expect(range).to be_nil
      end

      it 'checks parentheses' do
        node = parse('foo.bar(test)')
        range = adapter.child_node_range(node, :parentheses)
        expect(range.start).to eq 7
        expect(range.end).to eq 13

        node = parse('foobar(test)')
        range = adapter.child_node_range(node, :parentheses)
        expect(range.start).to eq 6
        expect(range.end).to eq 12

        node = parse('foo.bar')
        range = adapter.child_node_range(node, :parentheses)
        expect(range).to be_nil
      end
    end

    context 'array' do
      it 'checks array by index' do
        node = parse('factory :admin, class: User do; end')
        range = adapter.child_node_range(node, 'caller.arguments.2')
        expect(range.start).to eq 16
        expect(range.end).to eq 27
      end

      it 'checks array by method' do
        node = parse('factory :admin, class: User do; end')
        range = adapter.child_node_range(node, 'caller.arguments.second')
        expect(range.start).to eq 16
        expect(range.end).to eq 27
      end

      it "checks array's value" do
        node = parse('factory :admin, class: User do; end')
        range = adapter.child_node_range(node, 'caller.arguments.second.class_value')
        expect(range.start).to eq 23
        expect(range.end).to eq 27
      end
    end
  end

  describe '#get_start' do
    it 'gets start count' do
      node = parse("class Synvert\nend")
      expect(adapter.get_start(node)).to eq 0
    end
  end

  describe '#get_end' do
    it 'gets end count' do
      code = "class Synvert\nend"
      node = parse(code)
      expect(adapter.get_end(node)).to eq code.length
    end
  end

  describe '#get_start_loc' do
    it 'gets start location' do
      node = parse("class Synvert\nend")
      start_loc = adapter.get_start_loc(node)
      expect(start_loc.line).to eq 1
      expect(start_loc.column).to eq 0
    end
  end

  describe '#get_end_loc' do
    it 'gets end location' do
      node = parse("class Synvert\nend")
      end_loc = adapter.get_end_loc(node)
      expect(end_loc.line).to eq 2
      expect(end_loc.column).to eq 3
    end
  end

  describe '#get_indent' do
    it 'get indent count' do
      node = parse("  class Synvert\n  end")
      expect(adapter.get_indent(node)).to eq 2
    end
  end
end
