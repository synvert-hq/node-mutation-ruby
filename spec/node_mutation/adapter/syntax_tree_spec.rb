# frozen_string_literal: true

require 'spec_helper'

RSpec.describe NodeMutation::SyntaxTreeAdapter do
  let(:adapter) { described_class.new }

  describe '#get_source' do
    it 'gets for node' do
      source = 'foo.bar(a, b)'
      node = syntax_tree_parse(source)
      expect(adapter.get_source(node)).to eq source
    end

    it 'gets for child node' do
      source = 'foo.bar(a, b)'
      node = syntax_tree_parse(source)
      expect(adapter.get_source(node.message)).to eq 'bar'
    end

    it 'gets for array' do
      source = 'foo.bar(a, b)'
      node = syntax_tree_parse(source)
      expect(adapter.get_source(node.arguments.arguments)).to eq 'a, b'
    end
  end

  describe '#rewritten_source' do
    it 'rewrites with node known method' do
      source = 'class Synvert; end'
      node = syntax_tree_parse(source)
      expect(adapter.rewritten_source(node, '{{constant}}')).to eq 'Synvert'
    end

    it 'rewrites for arguments' do
      source = 'foo.bar(a, b)'
      node = syntax_tree_parse(source)
      expect(adapter.rewritten_source(node, '{{arguments.arguments}}')).to eq 'a, b'
    end

    it 'rewrites for last argument' do
      source = 'foo.bar(a, b)'
      node = syntax_tree_parse(source)
      expect(adapter.rewritten_source(node, '{{arguments.arguments.parts.-1}}')).to eq 'b'
    end

    it 'rewrites for HashLiteral' do
      source = 'after_commit :do_index, on: :create, if: :indexable?'
      node = syntax_tree_parse(source)
      expect(adapter.rewritten_source(node, '{{arguments.parts.-1}}')).to eq 'on: :create, if: :indexable?'
    end

    it 'rewrites for HashLiteral assoc' do
      source = 'after_commit :do_index, on: :create, if: :indexable?'
      node = syntax_tree_parse(source)
      expect(adapter.rewritten_source(node, '{{arguments.parts.-1.on_assoc}}')).to eq 'on: :create'
      node = node.arguments.parts.last
      expect(adapter.rewritten_source(node, '{{on_assoc}}')).to eq 'on: :create'
    end

    it 'rewrites array with multi line given as argument for method' do
      source = <<~EOS.strip
        long_name_method([
          1,
          2,
          3
        ])
      EOS

      node = syntax_tree_parse(source)
      expect(adapter.rewritten_source(node, '{{arguments.arguments.parts}}')).to eq <<~EOS.strip
        [
          1,
          2,
          3
        ]
      EOS
    end

    it 'rewriters for string receiver' do
      source = 'find(:first)'
      node = syntax_tree_parse(source)
      expect(adapter.rewritten_source(node, '{{message.value}}')).to eq 'find'
    end

    it 'rewrites for to_symbol' do
      source = "'foobar'"
      node = syntax_tree_parse(source)
      expect(adapter.rewritten_source(node, '{{to_symbol}}')).to eq ':foobar'
    end

    it 'rewrites for to_single_quote' do
      source = '"foobar"'
      node = syntax_tree_parse(source)
      expect(adapter.rewritten_source(node, '{{to_single_quote}}')).to eq "'foobar'"
    end

    it 'rewriters for nil receiver' do
      source = 'find(:first)'
      node = syntax_tree_parse(source)
      expect(adapter.rewritten_source(node, '{{receiver}}')).to eq ''
    end

    it 'raises an error with unknown method' do
      source = 'class Synvert; end'
      node = syntax_tree_parse(source)
      expect {
        adapter.rewritten_source(node, '{{foobar}}')
      }.to raise_error('foobar is not supported for class Synvert; end')
    end

    it 'raises an error for unknown code' do
      source = 'Notifications::Updater.expects(:new).returns(@srv)'
      node = syntax_tree_parse(source)
      expect {
        adapter.rewritten_source(
          node,
          '{{receiver.receiver}}).to receive({{receiver.arguments.first}).and_return({{caller.arguments.first}}'
        )
      }.to raise_error('first}) is not supported for (:new)')
    end
  end

  describe '#file_source' do
    it 'gets content of file' do
      source = <<~EOS
        class Synvert
          def foobar; end
        end
      EOS
      node = syntax_tree_parse(source)
      expect(adapter.file_source(node)).to eq source
    end
  end

  describe '#child_node_range' do
    context 'ArgParen node' do
      it 'checks arguments' do
        node = syntax_tree_parse('test(foo, bar)')
        range = adapter.child_node_range(node, 'arguments.arguments')
        expect(range.start).to eq 5
        expect(range.end).to eq 13
      end
    end

    context 'Assign node' do
      it 'checks target' do
        node = syntax_tree_parse('foo = bar')
        range = adapter.child_node_range(node, :target)
        expect(range.start).to eq 0
        expect(range.end).to eq 3
      end

      it 'checks value' do
        node = syntax_tree_parse('foo = bar')
        range = adapter.child_node_range(node, :value)
        expect(range.start).to eq 6
        expect(range.end).to eq 9
      end
    end

    context 'BlockNode node' do
      it 'checks block.opening' do
        node = syntax_tree_parse('Factory.define :user do |user|; end')
        range = adapter.child_node_range(node, 'block.opening')
        expect(range.start).to eq 21
        expect(range.end).to eq 23
      end

      it 'checks block.block_var' do
        node = syntax_tree_parse('Factory.define :user do |user|; end')
        range = adapter.child_node_range(node, 'block.block_var')
        expect(range.start).to eq 24
        expect(range.end).to eq 30
      end

      it 'checks block.bodystmt' do
        node = syntax_tree_parse('Factory.define :user do |user|; end')
        range = adapter.child_node_range(node, 'block.bodystmt')
        expect(range.start).to eq 30
        expect(range.end).to eq 32
      end
    end

    context 'Call node' do
      it 'checks receiver' do
        node = syntax_tree_parse('foo.bar(test)')
        range = adapter.child_node_range(node, :receiver)
        expect(range.start).to eq 0
        expect(range.end).to eq 3
      end

      it 'checks operator' do
        node = syntax_tree_parse('foo.bar(test)')
        range = adapter.child_node_range(node, :operator)
        expect(range.start).to eq 3
        expect(range.end).to eq 4
      end

      it 'checks message' do
        node = syntax_tree_parse('foo.bar(test)')
        range = adapter.child_node_range(node, :message)
        expect(range.start).to eq 4
        expect(range.end).to eq 7
      end

      it 'checks arguments' do
        node = syntax_tree_parse('foo.bar(test)')
        range = adapter.child_node_range(node, :arguments)
        expect(range.start).to eq 7
        expect(range.end).to eq 13

        node = syntax_tree_parse('foo.bar')
        range = adapter.child_node_range(node, :arguments)
        expect(range).to be_nil
      end
    end

    context 'ClassDefinition node' do
      it 'checks constant' do
        node = syntax_tree_parse('class Post < ActiveRecord::Base; end')
        range = adapter.child_node_range(node, :constant)
        expect(range.start).to eq 6
        expect(range.end).to eq 10
      end

      it 'checks superclass' do
        node = syntax_tree_parse('class Post < ActiveRecord::Base; end')
        range = adapter.child_node_range(node, :superclass)
        expect(range.start).to eq 13
        expect(range.end).to eq 31

        node = syntax_tree_parse('class Post; end')
        range = adapter.child_node_range(node, :superclass)
        expect(range).to be_nil
      end
    end

    context 'CommandCall node' do
      it 'checks receiver' do
        node = syntax_tree_parse('Factory.define :user do |user|; end')
        range = adapter.child_node_range(node, :receiver)
        expect(range.start).to eq 0
        expect(range.end).to eq 7
      end

      it 'checks operator' do
        node = syntax_tree_parse('Factory.define :user do |user|; end')
        range = adapter.child_node_range(node, :operator)
        expect(range.start).to eq 7
        expect(range.end).to eq 8
      end

      it 'checks message' do
        node = syntax_tree_parse('Factory.define :user do |user|; end')
        range = adapter.child_node_range(node, :message)
        expect(range.start).to eq 8
        expect(range.end).to eq 14
      end

      it 'checks arguments' do
        node = syntax_tree_parse('Factory.define :user do |user|; end')
        range = adapter.child_node_range(node, :arguments)
        expect(range.start).to eq 15
        expect(range.end).to eq 20
      end

      it 'checks block' do
        node = syntax_tree_parse('Factory.define :user do |user|; end')
        range = adapter.child_node_range(node, :block)
        expect(range.start).to eq 21
        expect(range.end).to eq 35
      end
    end

    context 'ConstPathRef node' do
      it 'checks parent' do
        node = syntax_tree_parse('Foo::Bar')
        range = adapter.child_node_range(node, :parent)
        expect(range.start).to eq 0
        expect(range.end).to eq 3
      end

      it 'checks constant' do
        node = syntax_tree_parse('Foo::Bar')
        range = adapter.child_node_range(node, :constant)
        expect(range.start).to eq 5
        expect(range.end).to eq 8
      end
    end

    context 'DefNode node' do
      it 'checks target' do
        node = syntax_tree_parse('def foo(bar); end')
        range = adapter.child_node_range(node, :target)
        expect(range).to be_nil

        node = syntax_tree_parse('def self.foo(bar); end')
        range = adapter.child_node_range(node, :target)
        expect(range.start).to eq 4
        expect(range.end).to eq 8
      end

      it 'checks operator' do
        node = syntax_tree_parse('def foo(bar); end')
        range = adapter.child_node_range(node, :operator)
        expect(range).to be_nil

        node = syntax_tree_parse('def self.foo(bar); end')
        range = adapter.child_node_range(node, :operator)
        expect(range.start).to eq 8
        expect(range.end).to eq 9
      end

      it 'checks name' do
        node = syntax_tree_parse('def foo(bar); end')
        range = adapter.child_node_range(node, :name)
        expect(range.start).to eq 4
        expect(range.end).to eq 7

        node = syntax_tree_parse('def self.foo(bar); end')
        range = adapter.child_node_range(node, :name)
        expect(range.start).to eq 9
        expect(range.end).to eq 12
      end

      it 'checks params' do
        node = syntax_tree_parse('def foo(bar); end')
        range = adapter.child_node_range(node, :params)
        expect(range.start).to eq 7
        expect(range.end).to eq 12

        node = syntax_tree_parse('def self.foo(bar); end')
        range = adapter.child_node_range(node, :params)
        expect(range.start).to eq 12
        expect(range.end).to eq 17
      end

      it 'checks bodystmt' do
        node = syntax_tree_parse('def foo(bar); end')
        range = adapter.child_node_range(node, :bodystmt)
        expect(range.start).to eq 12
        expect(range.end).to eq 14

        node = syntax_tree_parse('def self.foo(bar); end')
        range = adapter.child_node_range(node, :bodystmt)
        expect(range.start).to eq 17
        expect(range.end).to eq 19
      end
    end

    context 'Field node' do
      it 'checks parent' do
        node = syntax_tree_parse('foo&.bar = test')
        range = adapter.child_node_range(node, 'target.parent')
        expect(range.start).to eq 0
        expect(range.end).to eq 3
      end

      it 'checks operator' do
        node = syntax_tree_parse('foo&.bar = test')
        range = adapter.child_node_range(node, 'target.operator')
        expect(range.start).to eq 3
        expect(range.end).to eq 5
      end

      it 'checks name' do
        node = syntax_tree_parse('foo&.bar = test')
        range = adapter.child_node_range(node, 'target.name')
        expect(range.start).to eq 5
        expect(range.end).to eq 8
      end
    end

    context 'HashLiteral node' do
      it 'checks foo_assoc' do
        node = syntax_tree_parse("{ foo: 'foo', bar: 'bar' }")
        range = adapter.child_node_range(node, :foo_assoc)
        expect(range.start).to eq 2
        expect(range.end).to eq 12
      end

      it "checks foo_value" do
        node = syntax_tree_parse("{ foo: 'foo', bar: 'bar' }")
        range = adapter.child_node_range(node, :foo_value)
        expect(range.start).to eq 7
        expect(range.end).to eq 12
      end
    end

    context 'MAssign node' do
      it 'checks target' do
        node = syntax_tree_parse("foo, bar = 'foo', 'bar'")
        range = adapter.child_node_range(node, :target)
        expect(range.start).to eq 0
        expect(range.end).to eq 8
      end

      it 'checks value' do
        node = syntax_tree_parse("foo, bar = 'foo', 'bar'")
        range = adapter.child_node_range(node, :value)
        expect(range.start).to eq 11
        expect(range.end).to eq 23
      end
    end

    context 'MLHS node' do
      it 'checks parts' do
        node = syntax_tree_parse("foo, bar = 'foo', 'bar'")
        range = adapter.child_node_range(node, 'target.parts')
        expect(range.start).to eq 0
        expect(range.end).to eq 8
      end
    end

    context 'MRHS node' do
      it 'checks parts' do
        node = syntax_tree_parse("foo, bar = 'foo', 'bar'")
        range = adapter.child_node_range(node, 'value.parts')
        expect(range.start).to eq 11
        expect(range.end).to eq 23
      end
    end

    context 'OpAssign node' do
      it 'checks target' do
        node = syntax_tree_parse('foo &&= bar')
        range = adapter.child_node_range(node, :target)
        expect(range.start).to eq 0
        expect(range.end).to eq 3
      end

      it 'checks operator' do
        node = syntax_tree_parse('foo &&= bar')
        range = adapter.child_node_range(node, :operator)
        expect(range.start).to eq 4
        expect(range.end).to eq 7
      end

      it 'checks value' do
        node = syntax_tree_parse('foo &&= bar')
        range = adapter.child_node_range(node, :value)
        expect(range.start).to eq 8
        expect(range.end).to eq 11
      end
    end

    context 'VarRef node' do
      it 'checks CVar value' do
        node = syntax_tree_parse('@@foo')
        range = adapter.child_node_range(node, :value)
        expect(range.start).to eq 0
        expect(range.end).to eq 5
      end

      it 'checks GVar value' do
        node = syntax_tree_parse('$foo')
        range = adapter.child_node_range(node, :value)
        expect(range.start).to eq 0
        expect(range.end).to eq 4
      end

      it 'checks IVar value' do
        node = syntax_tree_parse('@foo')
        range = adapter.child_node_range(node, :value)
        expect(range.start).to eq 0
        expect(range.end).to eq 4
      end

      it 'checks VarField value' do
        node = syntax_tree_parse('foo = bar')
        range = adapter.child_node_range(node, 'target.value')
        expect(range.start).to eq 0
        expect(range.end).to eq 3
      end

      it 'checks value' do
        node = syntax_tree_parse('Synvert')
        range = adapter.child_node_range(node, :value)
        expect(range.start).to eq 0
        expect(range.end).to eq 'Synvert'.length
      end
    end

    context 'VCall node' do
      it 'checks value' do
        node = syntax_tree_parse('foo = bar')
        range = adapter.child_node_range(node, 'value.value')
        expect(range.start).to eq 6
        expect(range.end).to eq 9
      end
    end

    context 'array' do
      it 'checks array by index' do
        node = syntax_tree_parse('factory :admin, class: User do; end')
        range = adapter.child_node_range(node, 'arguments.parts.1')
        expect(range.start).to eq 16
        expect(range.end).to eq 27
      end

      it 'checks array by method' do
        node = syntax_tree_parse('factory :admin, class: User do; end')
        range = adapter.child_node_range(node, 'arguments.parts.last')
        expect(range.start).to eq 16
        expect(range.end).to eq 27
      end
    end

    context 'unknown' do
      it 'checks unknown child name for node' do
        node = syntax_tree_parse('foo.bar(test)')
        expect {
          adapter.child_node_range(node, :unknown)
        }.to raise_error(NodeMutation::MethodNotSupported, "unknown is not supported for foo.bar(test)")
      end

      it 'checks unknown child name for array node' do
        node = syntax_tree_parse('foo.bar(foo, bar)')
        expect {
          adapter.child_node_range(node, "arguments.unknown")
        }.to raise_error(NodeMutation::MethodNotSupported, "unknown is not supported for (foo, bar)")
      end
    end
  end

  describe '#get_start' do
    it 'gets start position' do
      node = syntax_tree_parse("class Synvert\nend")
      expect(adapter.get_start(node)).to eq 0
    end

    it 'gets start position for constant child' do
      node = syntax_tree_parse("class Synvert\nend")
      expect(adapter.get_start(node, :constant)).to eq 'class '.length
    end
  end

  describe '#get_end' do
    it 'gets end position' do
      node = syntax_tree_parse("class Synvert\nend")
      expect(adapter.get_end(node)).to eq "class Synvert\nend".length
    end

    it 'gets end position for constant child' do
      node = syntax_tree_parse("class Synvert\nend")
      expect(adapter.get_end(node, :constant)).to eq 'class Synvert'.length
    end
  end

  describe '#get_start_loc' do
    it 'gets start location' do
      node = syntax_tree_parse("class Synvert\nend")
      start_loc = adapter.get_start_loc(node)
      expect(start_loc.line).to eq 1
      expect(start_loc.column).to eq 0
    end

    it 'gets start location for constant child' do
      node = syntax_tree_parse("class Synvert\nend")
      start_loc = adapter.get_start_loc(node, :constant)
      expect(start_loc.line).to eq 1
      expect(start_loc.column).to eq 'class '.length
    end
  end

  describe '#get_end_loc' do
    it 'gets end location' do
      node = syntax_tree_parse("class Synvert\nend")
      end_loc = adapter.get_end_loc(node)
      expect(end_loc.line).to eq 2
      expect(end_loc.column).to eq 3
    end

    it 'gets end location for constant child' do
      node = syntax_tree_parse("class Synvert\nend")
      end_loc = adapter.get_end_loc(node, :constant)
      expect(end_loc.line).to eq 1
      expect(end_loc.column).to eq 'class Synvert'.length
    end
  end

  describe '#get_indent' do
    it 'get indent count' do
      node = syntax_tree_parse("  class Synvert\n  end")
      expect(adapter.get_indent(node)).to eq 2
    end
  end
end
