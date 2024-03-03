# frozen_string_literal: true

require 'spec_helper'

RSpec.describe NodeMutation::PrismAdapter do
  let(:adapter) { described_class.new }

  describe '#get_source' do
    it 'gets for node' do
      source = 'foo.bar(a, b)'
      node = prism_parse(source)
      expect(adapter.get_source(node)).to eq source
    end

    it 'gets for child node' do
      source = 'foo.bar(a, b)'
      node = prism_parse(source)
      expect(adapter.get_source(node.receiver)).to eq 'foo'
    end

    it 'gets for array' do
      source = 'foo.bar(a, b)'
      node = prism_parse(source)
      expect(adapter.get_source(node.arguments.arguments)).to eq 'a, b'
    end
  end

  describe '#rewritten_source' do
    it 'rewrites with node known method' do
      source = 'class Synvert; end'
      node = prism_parse(source)
      expect(adapter.rewritten_source(node, '{{constant_path}}')).to eq 'Synvert'
    end

    it 'rewrites for arguments' do
      source = 'foo.bar(a, b)'
      node = prism_parse(source)
      expect(adapter.rewritten_source(node, '{{arguments.arguments}}')).to eq 'a, b'
    end

    it 'rewrites for last argument' do
      source = 'foo.bar(a, b)'
      node = prism_parse(source)
      expect(adapter.rewritten_source(node, '{{arguments.arguments.-1}}')).to eq 'b'
    end

    it 'rewrites for HashNode' do
      source = 'after_commit :do_index, on: :create, if: :indexable?'
      node = prism_parse(source)
      expect(adapter.rewritten_source(node, '{{arguments.arguments.-1}}')).to eq 'on: :create, if: :indexable?'
    end

    it 'rewrites for HashNode eleement' do
      source = 'after_commit :do_index, on: :create, if: :indexable?'
      node = prism_parse(source)
      expect(adapter.rewritten_source(node, '{{arguments.arguments.-1.on_element}}')).to eq 'on: :create'
      node = node.arguments.arguments.last
      expect(adapter.rewritten_source(node, '{{on_element}}')).to eq 'on: :create'
    end

    it 'rewrites array with multi line given as argument for method' do
      source = <<~EOS.strip
        long_name_method([
          1,
          2,
          3
        ])
      EOS

      node = prism_parse(source)
      expect(adapter.rewritten_source(node, '{{arguments.arguments}}')).to eq <<~EOS.strip
        [
          1,
          2,
          3
        ]
      EOS
    end

    it 'rewriters for string receiver' do
      source = 'find(:first)'
      node = prism_parse(source)
      expect(adapter.rewritten_source(node, '{{name}}')).to eq 'find'
    end

    it 'rewrites for to_symbol' do
      source = "'foobar'"
      node = prism_parse(source)
      expect(adapter.rewritten_source(node, '{{to_symbol}}')).to eq ':foobar'
    end

    it 'rewrites for to_string' do
      source = ":foobar"
      node = prism_parse(source)
      expect(adapter.rewritten_source(node, '{{to_string}}')).to eq 'foobar'
    end

    it 'rewrites for to_single_quote' do
      source = '"foobar"'
      node = prism_parse(source)
      expect(adapter.rewritten_source(node, '{{to_single_quote}}')).to eq "'foobar'"
    end

    it 'rewrites for to_double_quote' do
      source = "'foobar'"
      node = prism_parse(source)
      expect(adapter.rewritten_source(node, '{{to_double_quote}}')).to eq '"foobar"'
    end

    describe '#to_lambda_literal' do
      context 'lambda node' do
        it 'converts to lambda literal without arguments' do
          source = 'lambda { foobar }'
          node = prism_parse(source)
          expect(adapter.rewritten_source(node, '{{to_lambda_literal}}')).to eq '-> { foobar }'
        end

        it 'converts to lambda literal with arguments' do
          source = 'lambda { |x, y| foobar }'
          node = prism_parse(source)
          expect(adapter.rewritten_source(node, '{{to_lambda_literal}}')).to eq '->(x, y) { foobar }'
        end
      end
    end

    it 'rewrites for strip_curly_braces' do
      source = "{ foo: 'bar' }"
      node = prism_parse(source)
      expect(adapter.rewritten_source(node, '{{strip_curly_braces}}')).to eq "foo: 'bar'"
    end

    it 'rewrites for wrap_curly_braces' do
      source = "test(foo: 'bar')"
      node = prism_parse(source).arguments.arguments.first
      expect(adapter.rewritten_source(node, '{{wrap_curly_braces}}')).to eq "{ foo: 'bar' }"
    end

    it 'rewriters for nil receiver' do
      source = 'find(:first)'
      node = prism_parse(source)
      expect(adapter.rewritten_source(node, '{{receiver}}')).to eq ''
    end

    it 'raises an error with unknown method' do
      source = 'class Synvert; end'
      node = prism_parse(source)
      expect {
        adapter.rewritten_source(node, '{{foobar}}')
      }.to raise_error('foobar is not supported for class Synvert; end')
    end

    it 'raises an error for unknown code' do
      source = 'Notifications::Updater.expects(:new).returns(@srv)'
      node = prism_parse(source)
      expect {
        adapter.rewritten_source(
          node,
          '{{receiver.receiver}}).to receive({{receiver.arguments.first}).and_return({{receiver.arguments.first}}'
        )
      }.to raise_error('first}) is not supported for :new')
    end
  end

  describe '#file_source' do
    it 'gets content of file' do
      source = <<~EOS
        class Synvert
          def foobar; end
        end
      EOS
      node = prism_parse(source)
      expect(adapter.file_source(node)).to eq source
    end
  end

  describe '#child_node_range' do
    context 'CallNode' do
      it 'checks arguments' do
        node = prism_parse('test(foo, bar)')
        range = adapter.child_node_range(node, 'arguments.arguments')
        expect(range.start).to eq 5
        expect(range.end).to eq 13
      end

      it 'checks call_operator' do
        node = prism_parse('foo&.bar = test')
        range = adapter.child_node_range(node, 'call_operator')
        expect(range.start).to eq 3
        expect(range.end).to eq 5
      end

      it 'checks message' do
        node = prism_parse('foo&.bar = test')
        range = adapter.child_node_range(node, 'message')
        expect(range.start).to eq 5
        expect(range.end).to eq 8
      end

      it 'checks message' do
        node = prism_parse("foo | bar")
        range = adapter.child_node_range(node, :message)
        expect(range.start).to eq 4
        expect(range.end).to eq 5
      end

      it 'checks name' do
        node = prism_parse('foo&.bar = test')
        range = adapter.child_node_range(node, 'name')
        expect(range.start).to eq 5
        expect(range.end).to eq 8
      end

      it 'checks name' do
        node = prism_parse("foo | bar")
        range = adapter.child_node_range(node, :name)
        expect(range.start).to eq 4
        expect(range.end).to eq 5
      end

      it 'checks block.opening' do
        node = prism_parse('Factory.define :user do |user|; end')
        range = adapter.child_node_range(node, 'block.opening')
        expect(range.start).to eq 21
        expect(range.end).to eq 23
      end

      it 'checks block.parameters' do
        node = prism_parse('Factory.define :user do |user|; end')
        range = adapter.child_node_range(node, 'block.parameters')
        expect(range.start).to eq 24
        expect(range.end).to eq 30
      end

      it 'checks block.body' do
        node = prism_parse('Factory.define :user do |user|; user; end')
        range = adapter.child_node_range(node, 'block.body')
        expect(range.start).to eq 32
        expect(range.end).to eq 36
      end

      it 'checks receiver' do
        node = prism_parse('foo.bar(test)')
        range = adapter.child_node_range(node, :receiver)
        expect(range.start).to eq 0
        expect(range.end).to eq 3
      end

      it 'checks call_operator' do
        node = prism_parse('foo.bar(test)')
        range = adapter.child_node_range(node, :call_operator)
        expect(range.start).to eq 3
        expect(range.end).to eq 4
      end

      it 'checks message' do
        node = prism_parse('foo.bar(test)')
        range = adapter.child_node_range(node, :message)
        expect(range.start).to eq 4
        expect(range.end).to eq 7
      end

      it 'checks arguments' do
        node = prism_parse('foo.bar(test)')
        range = adapter.child_node_range(node, :arguments)
        expect(range.start).to eq 8
        expect(range.end).to eq 12

        node = prism_parse('foo.bar')
        range = adapter.child_node_range(node, :arguments)
        expect(range).to be_nil
      end
    end

    context 'ClassNode' do
      it 'checks constant_path' do
        node = prism_parse('class Post < ActiveRecord::Base; end')
        range = adapter.child_node_range(node, :constant_path)
        expect(range.start).to eq 6
        expect(range.end).to eq 10
      end

      it 'checks superclass' do
        node = prism_parse('class Post < ActiveRecord::Base; end')
        range = adapter.child_node_range(node, :superclass)
        expect(range.start).to eq 13
        expect(range.end).to eq 31

        node = prism_parse('class Post; end')
        range = adapter.child_node_range(node, :superclass)
        expect(range).to be_nil
      end
    end

    context 'ConstantPathNode' do
      it 'checks parent' do
        node = prism_parse('Foo::Bar')
        range = adapter.child_node_range(node, :parent)
        expect(range.start).to eq 0
        expect(range.end).to eq 3
      end

      it 'checks child' do
        node = prism_parse('Foo::Bar')
        range = adapter.child_node_range(node, :child)
        expect(range.start).to eq 5
        expect(range.end).to eq 8
      end
    end

    context 'DefNode' do
      it 'checks receiver' do
        node = prism_parse('def foo(bar); end')
        range = adapter.child_node_range(node, :receiver)
        expect(range).to be_nil

        node = prism_parse('def self.foo(bar); end')
        range = adapter.child_node_range(node, :receiver)
        expect(range.start).to eq 4
        expect(range.end).to eq 8
      end

      it 'checks operator' do
        node = prism_parse('def foo(bar); end')
        range = adapter.child_node_range(node, :operator)
        expect(range).to be_nil

        node = prism_parse('def self.foo(bar); end')
        range = adapter.child_node_range(node, :operator)
        expect(range.start).to eq 8
        expect(range.end).to eq 9
      end

      it 'checks name' do
        node = prism_parse('def foo(bar); end')
        range = adapter.child_node_range(node, :name)
        expect(range.start).to eq 4
        expect(range.end).to eq 7

        node = prism_parse('def self.foo(bar); end')
        range = adapter.child_node_range(node, :name)
        expect(range.start).to eq 9
        expect(range.end).to eq 12
      end

      it 'checks parameters' do
        node = prism_parse('def foo(bar); end')
        range = adapter.child_node_range(node, :parameters)
        expect(range.start).to eq 8
        expect(range.end).to eq 11

        node = prism_parse('def self.foo(bar); end')
        range = adapter.child_node_range(node, :parameters)
        expect(range.start).to eq 13
        expect(range.end).to eq 16
      end

      it 'checks body' do
        node = prism_parse('def foo(bar); bar; end')
        range = adapter.child_node_range(node, :body)
        expect(range.start).to eq 14
        expect(range.end).to eq 17

        node = prism_parse('def self.foo(bar); bar; end')
        range = adapter.child_node_range(node, :body)
        expect(range.start).to eq 19
        expect(range.end).to eq 22
      end
    end

    context 'HashNode' do
      it 'checks foo_element' do
        node = prism_parse("{ foo: 'foo', bar: 'bar' }")
        range = adapter.child_node_range(node, :foo_element)
        expect(range.start).to eq 2
        expect(range.end).to eq 12
      end

      it "checks foo_value" do
        node = prism_parse("{ foo: 'foo', bar: 'bar' }")
        range = adapter.child_node_range(node, :foo_value)
        expect(range.start).to eq 7
        expect(range.end).to eq 12
      end
    end

    context 'LocalVariableAndWriteNode' do
      it 'checks name' do
        node = prism_parse('foo &&= bar')
        range = adapter.child_node_range(node, :name)
        expect(range.start).to eq 0
        expect(range.end).to eq 3
      end

      it 'checks operator' do
        node = prism_parse('foo &&= bar')
        range = adapter.child_node_range(node, :operator)
        expect(range.start).to eq 4
        expect(range.end).to eq 7
      end

      it 'checks value' do
        node = prism_parse('foo &&= bar')
        range = adapter.child_node_range(node, :value)
        expect(range.start).to eq 8
        expect(range.end).to eq 11
      end
    end

    context 'LocalVariableReadNode' do
      it 'checks name' do
        node = prism_parse('def test(foo); foo; end').body.body.first
        range = adapter.child_node_range(node, :name)
        expect(range.start).to eq 15
        expect(range.end).to eq 18
      end
    end

    context 'LocalVariableWriteNode' do
      it 'checks name' do
        node = prism_parse('foo = bar')
        range = adapter.child_node_range(node, :name)
        expect(range.start).to eq 0
        expect(range.end).to eq 3
      end

      it 'checks operator' do
        node = prism_parse('foo = bar')
        range = adapter.child_node_range(node, :operator)
        expect(range.start).to eq 4
        expect(range.end).to eq 5
      end

      it 'checks value' do
        node = prism_parse('foo = bar')
        range = adapter.child_node_range(node, :value)
        expect(range.start).to eq 6
        expect(range.end).to eq 9
      end
    end

    context 'MultiWriteNode' do
      it 'checks lefts' do
        node = prism_parse("foo, bar = 'foo', 'bar'")
        range = adapter.child_node_range(node, :lefts)
        expect(range.start).to eq 0
        expect(range.end).to eq 8
      end

      it 'checks value' do
        node = prism_parse("foo, bar = 'foo', 'bar'")
        range = adapter.child_node_range(node, :value)
        expect(range.start).to eq 11
        expect(range.end).to eq 23
      end
    end

    context 'array' do
      it 'checks array by index' do
        node = prism_parse('factory :admin, class: User do; end')
        range = adapter.child_node_range(node, 'arguments.arguments.1')
        expect(range.start).to eq 16
        expect(range.end).to eq 27
      end

      it 'checks array by method' do
        node = prism_parse('factory :admin, class: User do; end')
        range = adapter.child_node_range(node, 'arguments.arguments.last')
        expect(range.start).to eq 16
        expect(range.end).to eq 27
      end
    end

    context 'unknown' do
      it 'checks unknown child name for node' do
        node = prism_parse('foo.bar(test)')
        expect {
          adapter.child_node_range(node, :unknown)
        }.to raise_error(NodeMutation::MethodNotSupported, "unknown is not supported for foo.bar(test)")
      end

      it 'checks unknown child name for array node' do
        node = prism_parse('foo.bar(foo, bar)')
        expect {
          adapter.child_node_range(node, "arguments.unknown")
        }.to raise_error(NodeMutation::MethodNotSupported, "unknown is not supported for foo, bar")
      end
    end
  end

  describe '#get_start' do
    it 'gets start position' do
      node = prism_parse("class Synvert\nend")
      expect(adapter.get_start(node)).to eq 0
    end

    it 'gets start position for constant child' do
      node = prism_parse("class Synvert\nend")
      expect(adapter.get_start(node, :constant_path)).to eq 'class '.length
    end
  end

  describe '#get_end' do
    it 'gets end position' do
      node = prism_parse("class Synvert\nend")
      expect(adapter.get_end(node)).to eq "class Synvert\nend".length
    end

    it 'gets end position for constant child' do
      node = prism_parse("class Synvert\nend")
      expect(adapter.get_end(node, :constant_path)).to eq 'class Synvert'.length
    end
  end

  describe '#get_start_loc' do
    it 'gets start location' do
      node = prism_parse("class Synvert\nend")
      start_loc = adapter.get_start_loc(node)
      expect(start_loc.line).to eq 1
      expect(start_loc.column).to eq 0
    end

    it 'gets start location for constant child' do
      node = prism_parse("class Synvert\nend")
      start_loc = adapter.get_start_loc(node, :constant_path)
      expect(start_loc.line).to eq 1
      expect(start_loc.column).to eq 'class '.length
    end
  end

  describe '#get_end_loc' do
    it 'gets end location' do
      node = prism_parse("class Synvert\nend")
      end_loc = adapter.get_end_loc(node)
      expect(end_loc.line).to eq 2
      expect(end_loc.column).to eq 3
    end

    it 'gets end location for constant child' do
      node = prism_parse("class Synvert\nend")
      end_loc = adapter.get_end_loc(node, :constant_path)
      expect(end_loc.line).to eq 1
      expect(end_loc.column).to eq 'class Synvert'.length
    end
  end
end
