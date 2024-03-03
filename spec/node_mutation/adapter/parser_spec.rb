# frozen_string_literal: true

require 'spec_helper'

RSpec.describe NodeMutation::ParserAdapter do
  let(:adapter) { described_class.new }

  describe '#get_source' do
    it 'gets for node' do
      source = 'params[:user][:email]'
      node = parser_parse(source)
      expect(adapter.get_source(node)).to eq source
    end
  end

  describe '#rewritten_source' do
    it 'rewrites with node known method' do
      source = 'class Synvert; end'
      node = parser_parse(source)
      expect(adapter.rewritten_source(node, '{{name}}')).to eq 'Synvert'
    end

    it 'rewrites for arguments' do
      source = 'test { |a, b| }'
      node = parser_parse(source)
      expect(adapter.rewritten_source(node, '{{arguments}}')).to eq 'a, b'
    end

    it 'rewrites for last argument' do
      source = 'test { |a, b| }'
      node = parser_parse(source)
      expect(adapter.rewritten_source(node, '{{arguments.-1}}')).to eq 'b'
    end

    it 'rewrites for hash' do
      source = 'after_commit :do_index, on: :create, if: :indexable?'
      node = parser_parse(source)
      expect(adapter.rewritten_source(node, '{{arguments.-1}}')).to eq 'on: :create, if: :indexable?'
    end

    it 'rewrites for hash pair' do
      source = 'after_commit :do_index, on: :create, if: :indexable?'
      node = parser_parse(source)
      expect(adapter.rewritten_source(node, '{{arguments.-1.on_pair}}')).to eq 'on: :create'
      node = node.arguments.last
      expect(adapter.rewritten_source(node, '{{on_pair}}')).to eq 'on: :create'
    end

    it 'rewrites for hash value' do
      source = 'after_commit :do_index, on: :create, if: :indexable?'
      node = parser_parse(source)
      expect(adapter.rewritten_source(node, '{{arguments.-1.on_value}}')).to eq ':create'
      node = node.arguments.last
      expect(adapter.rewritten_source(node, '{{on_value}}')).to eq ':create'
    end

    it 'rewrites array with multi line given as argument for method' do
      source = <<~EOS.strip
        long_name_method([
          1,
          2,
          3
        ])
      EOS

      node = parser_parse(source)
      expect(adapter.rewritten_source(node, '{{arguments}}')).to eq <<~EOS.strip
        [
          1,
          2,
          3
        ]
      EOS
    end

    it 'rewrites for to_symbol' do
      source = "'foobar'"
      node = parser_parse(source)
      expect(adapter.rewritten_source(node, '{{to_symbol}}')).to eq ':foobar'
    end

    it 'rewrites for to_string' do
      source = ":foobar"
      node = parser_parse(source)
      expect(adapter.rewritten_source(node, '{{to_string}}')).to eq 'foobar'
    end

    it 'rewrites for to_single_quote' do
      source = '"foobar"'
      node = parser_parse(source)
      expect(adapter.rewritten_source(node, '{{to_single_quote}}')).to eq "'foobar'"
    end

    it 'rewrites for to_double_quote' do
      source = "'foobar'"
      node = parser_parse(source)
      expect(adapter.rewritten_source(node, '{{to_double_quote}}')).to eq '"foobar"'
    end

    describe '#to_lambda_literal' do
      context 'lambda node' do
        it 'converts to lambda literal without arguments' do
          source = 'lambda { foobar }'
          node = parser_parse(source)
          expect(adapter.rewritten_source(node, '{{to_lambda_literal}}')).to eq '-> { foobar }'
        end

        it 'converts to lambda literal with arguments' do
          source = 'lambda { |x, y| foobar }'
          node = parser_parse(source)
          expect(adapter.rewritten_source(node, '{{to_lambda_literal}}')).to eq '->(x, y) { foobar }'
        end
      end
    end

    it 'rewrites for strip_curly_braces' do
      source = "{ foo: 'bar' }"
      node = parser_parse(source)
      expect(adapter.rewritten_source(node, '{{strip_curly_braces}}')).to eq "foo: 'bar'"
    end

    it 'rewrites for wrap_curly_braces' do
      source = "test(foo: 'bar')"
      node = parser_parse(source).arguments.first
      expect(adapter.rewritten_source(node, '{{wrap_curly_braces}}')).to eq "{ foo: 'bar' }"
    end

    it 'rewriters for nil receiver' do
      source = 'find(:first)'
      node = parser_parse(source)
      expect(adapter.rewritten_source(node, '{{receiver}}')).to eq ''
    end

    it 'raises an error with unknown method' do
      source = 'class Synvert; end'
      node = parser_parse(source)
      expect {
        adapter.rewritten_source(node, '{{foobar}}')
      }.to raise_error('foobar is not supported for class Synvert; end')
    end

    it 'raises an error for unknown code' do
      source = 'Notifications::Updater.expects(:new).returns(@srv)'
      node = parser_parse(source)
      expect {
        adapter.rewritten_source(
          node,
          '{{receiver.receiver}}).to receive({{receiver.arguments.first}).and_return({{caller.arguments.first}}'
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
      node = parser_parse(source).body.first
      expect(adapter.file_source(node)).to eq source
    end
  end

  describe '#child_node_range' do
    context 'and_asgn' do
      it 'checks variable' do
        node = parser_parse('foo &&= bar')
        range = adapter.child_node_range(node, :variable)
        expect(range.start).to eq 0
        expect(range.end).to eq 3
      end

      it 'checks value' do
        node = parser_parse('foo &&= bar')
        range = adapter.child_node_range(node, :value)
        expect(range.start).to eq 8
        expect(range.end).to eq 11
      end
    end

    context 'arg node' do
      it 'checks name' do
        node = parser_parse('def foobar(foo, bar); end')
        range = adapter.child_node_range(node, 'arguments.0')
        expect(range.start).to eq 11
        expect(range.end).to eq 14
      end
    end

    context 'array node' do
      it 'checks array by index' do
        node = parser_parse('factory :admin, class: User do; end')
        range = adapter.child_node_range(node, 'caller.arguments.1')
        expect(range.start).to eq 16
        expect(range.end).to eq 27
      end

      it 'checks array by method' do
        node = parser_parse('factory :admin, class: User do; end')
        range = adapter.child_node_range(node, 'caller.arguments.last')
        expect(range.start).to eq 16
        expect(range.end).to eq 27
      end

      it "checks array's value" do
        node = parser_parse('factory :admin, class: User do; end')
        range = adapter.child_node_range(node, 'caller.arguments.last.class_value')
        expect(range.start).to eq 23
        expect(range.end).to eq 27
      end
    end

    context 'block node' do
      it 'checks caller' do
        node = parser_parse('Factory.define :user do |user|; end')
        range = adapter.child_node_range(node, :caller)
        expect(range.start).to eq 0
        expect(range.end).to eq 20
      end

      it 'checks arguments' do
        node = parser_parse('Factory.define :user do |user|; end')
        range = adapter.child_node_range(node, :arguments)
        expect(range.start).to eq 25
        expect(range.end).to eq 29

        node = parser_parse('Factory.define :user do; end')
        range = adapter.child_node_range(node, :arguments)
        expect(range).to be_nil
      end

      it 'checks pipes' do
        node = parser_parse('Factory.define :user do |user|; end')
        range = adapter.child_node_range(node, :pipes)
        expect(range.start).to eq 24
        expect(range.end).to eq 30

        node = parser_parse('Factory.define :user do; end')
        range = adapter.child_node_range(node, :pipes)
        expect(range).to be_nil
      end

      it 'checks caller.receiver' do
        node = parser_parse('Factory.define :user do |user|; end')
        range = adapter.child_node_range(node, 'caller.receiver')
        expect(range.start).to eq 0
        expect(range.end).to eq 7
      end

      it 'checks caller.message' do
        node = parser_parse('Factory.define :user do |user|; end')
        range = adapter.child_node_range(node, 'caller.message')
        expect(range.start).to eq 8
        expect(range.end).to eq 14
      end

      it 'checks body' do
        node = parser_parse("Factory.define :user do |user|; name { 'Test' }; end")
        range = adapter.child_node_range(node, :body)
        expect(range.start).to eq 32
        expect(range.end).to eq 47

        node = parser_parse("Factory.define :user do; end")
        range = adapter.child_node_range(node, :body)
        expect(range).to be_nil
      end
    end

    context 'class node' do
      it 'checks name' do
        node = parser_parse('class Post < ActiveRecord::Base; end')
        range = adapter.child_node_range(node, :name)
        expect(range.start).to eq 6
        expect(range.end).to eq 10
      end

      it 'checks parent_class' do
        node = parser_parse('class Post < ActiveRecord::Base; end')
        range = adapter.child_node_range(node, :parent_class)
        expect(range.start).to eq 13
        expect(range.end).to eq 31

        node = parser_parse('class Post; end')
        range = adapter.child_node_range(node, :parent_class)
        expect(range).to be_nil
      end

      it 'checks body' do
        node = parser_parse('class Post < ActiveRecord::Base; def title; end; end')
        range = adapter.child_node_range(node, :body)
        expect(range.start).to eq 33
        expect(range.end).to eq 47

        node = parser_parse('class Post < ActiveRecord::Base; end')
        range = adapter.child_node_range(node, :body)
        expect(range).to be_nil
      end
    end

    context 'const node' do
      it 'checks name' do
        node = parser_parse('Synvert')
        range = adapter.child_node_range(node, :name)
        expect(range.start).to eq 0
        expect(range.end).to eq 'Synvert'.length
      end

      it 'checks coloncolon' do
        node = parser_parse('Foo::Bar')
        range = adapter.child_node_range(node, :double_colon)
        expect(range.start).to eq 'Foo'.length
        expect(range.end).to eq 'Foo::'.length
      end
    end

    context 'csend node' do
      it 'checks receiver' do
        node = parser_parse('foo&.bar(test)')
        range = adapter.child_node_range(node, :receiver)
        expect(range.start).to eq 0
        expect(range.end).to eq 3
      end

      it 'checks dot' do
        node = parser_parse('foo&.bar(test)')
        range = adapter.child_node_range(node, :dot)
        expect(range.start).to eq 3
        expect(range.end).to eq 5
      end

      it 'checks message' do
        node = parser_parse('foo&.bar(test)')
        range = adapter.child_node_range(node, :message)
        expect(range.start).to eq 5
        expect(range.end).to eq 8

        node = parser_parse('foo&.bar = test')
        range = adapter.child_node_range(node, :message)
        expect(range.start).to eq 5
        expect(range.end).to eq 10
      end

      it 'checks arguments' do
        node = parser_parse('foo&.bar(test)')
        range = adapter.child_node_range(node, :arguments)
        expect(range.start).to eq 9
        expect(range.end).to eq 13

        node = parser_parse('foo&.bar')
        range = adapter.child_node_range(node, :arguments)
        expect(range).to be_nil
      end

      it 'checks parentheses' do
        node = parser_parse('foo&.bar(test)')
        range = adapter.child_node_range(node, :parentheses)
        expect(range.start).to eq 8
        expect(range.end).to eq 14

        node = parser_parse('foo&.bar')
        range = adapter.child_node_range(node, :parentheses)
        expect(range).to be_nil
      end
    end

    context 'cvasgn node' do
      it 'checks variable' do
        node = parser_parse('@@foo = bar')
        range = adapter.child_node_range(node, :variable)
        expect(range.start).to eq 0
        expect(range.end).to eq 5
      end

      it 'checks value' do
        node = parser_parse('@@foo = bar')
        range = adapter.child_node_range(node, :value)
        expect(range.start).to eq 8
        expect(range.end).to eq 11
      end
    end

    context 'def node' do
      it 'checks name' do
        node = parser_parse('def foo(bar); end')
        range = adapter.child_node_range(node, :name)
        expect(range.start).to eq 4
        expect(range.end).to eq 7
      end

      it 'checks arguments' do
        node = parser_parse('def foo(bar); end')
        range = adapter.child_node_range(node, :arguments)
        expect(range.start).to eq 8
        expect(range.end).to eq 11

        node = parser_parse('def foo; end')
        range = adapter.child_node_range(node, :arguments)
        expect(range).to be_nil
      end

      it 'checks parentheses' do
        node = parser_parse('def foo(bar); end')
        range = adapter.child_node_range(node, :parentheses)
        expect(range.start).to eq 7
        expect(range.end).to eq 12
      end

      it 'checks body' do
        node = parser_parse("def foo(bar); 'foobar'; end")
        range = adapter.child_node_range(node, :body)
        expect(range.start).to eq 14
        expect(range.end).to eq 22

        node = parser_parse('def foo(bar); end')
        range = adapter.child_node_range(node, :body)
        expect(range).to be_nil
      end
    end

    context 'defs node' do
      it 'checks self' do
        node = parser_parse('def self.foo(bar); end')
        range = adapter.child_node_range(node, :self)
        expect(range.start).to eq 4
        expect(range.end).to eq 8
      end

      it 'checks dot' do
        node = parser_parse('def self.foo(bar); end')
        range = adapter.child_node_range(node, :dot)
        expect(range.start).to eq 8
        expect(range.end).to eq 9
      end

      it 'checks name' do
        node = parser_parse('def self.foo(bar); end')
        range = adapter.child_node_range(node, :name)
        expect(range.start).to eq 9
        expect(range.end).to eq 12
      end

      it 'checks arguments' do
        node = parser_parse('def self.foo(bar); end')
        range = adapter.child_node_range(node, :arguments)
        expect(range.start).to eq 13
        expect(range.end).to eq 16

        node = parser_parse('def self.foo; end')
        range = adapter.child_node_range(node, :arguments)
        expect(range).to be_nil
      end

      it 'checks parentheses' do
        node = parser_parse('def self.foo(bar); end')
        range = adapter.child_node_range(node, :parentheses)
        expect(range.start).to eq 12
        expect(range.end).to eq 17
      end

      it 'checks body' do
        node = parser_parse("def self.foo(bar); 'foobar'; end")
        range = adapter.child_node_range(node, :body)
        expect(range.start).to eq 19
        expect(range.end).to eq 27

        node = parser_parse('def self.foo(bar); end')
        range = adapter.child_node_range(node, :body)
        expect(range).to be_nil
      end
    end

    context 'float' do
      it 'checks value' do
        code = '1.1'
        node = parser_parse(code)
        range = adapter.child_node_range(node, :value)
        expect(range.start).to eq 0
        expect(range.end).to eq code.length
      end
    end

    context 'gvasgn node' do
      it 'checks variable' do
        node = parser_parse('$foo = bar')
        range = adapter.child_node_range(node, :variable)
        expect(range.start).to eq 0
        expect(range.end).to eq 4
      end

      it 'checks value' do
        node = parser_parse('$foo = bar')
        range = adapter.child_node_range(node, :value)
        expect(range.start).to eq 7
        expect(range.end).to eq 10
      end
    end

    context 'hash node' do
      it 'checks foo_pair' do
        node = parser_parse("{ foo: 'foo', bar: 'bar' }")
        range = adapter.child_node_range(node, :foo_pair)
        expect(range.start).to eq 2
        expect(range.end).to eq 12
      end

      it 'checks foo_value' do
        node = parser_parse("{ foo: 'foo', bar: 'bar' }")
        range = adapter.child_node_range(node, :foo_value)
        expect(range.start).to eq 7
        expect(range.end).to eq 12
      end
    end

    context 'int' do
      it 'checks value' do
        code = '1'
        node = parser_parse(code)
        range = adapter.child_node_range(node, :value)
        expect(range.start).to eq 0
        expect(range.end).to eq code.length
      end
    end

    context 'ivasgn node' do
      it 'checks variable' do
        node = parser_parse('@foo = bar')
        range = adapter.child_node_range(node, :variable)
        expect(range.start).to eq 0
        expect(range.end).to eq 4
      end

      it 'checks value' do
        node = parser_parse('@foo = bar')
        range = adapter.child_node_range(node, :value)
        expect(range.start).to eq 7
        expect(range.end).to eq 10
      end
    end

    context 'lvasgn node' do
      it 'checks variable' do
        node = parser_parse('foo = bar')
        range = adapter.child_node_range(node, :variable)
        expect(range.start).to eq 0
        expect(range.end).to eq 3
      end

      it 'checks value' do
        node = parser_parse('foo = bar')
        range = adapter.child_node_range(node, :value)
        expect(range.start).to eq 6
        expect(range.end).to eq 9
      end
    end

    context 'or_asgn node' do
      it 'checks variable' do
        node = parser_parse('foo ||= bar')
        range = adapter.child_node_range(node, :variable)
        expect(range.start).to eq 0
        expect(range.end).to eq 3
      end

      it 'checks value' do
        node = parser_parse('foo ||= bar')
        range = adapter.child_node_range(node, :value)
        expect(range.start).to eq 8
        expect(range.end).to eq 11
      end
    end

    context 'mvasgn node' do
      it 'checks variable' do
        node = parser_parse("foo, bar = 'foo', 'bar'")
        range = adapter.child_node_range(node, :variable)
        expect(range.start).to eq 0
        expect(range.end).to eq 8
      end

      it 'checks value' do
        node = parser_parse("foo, bar = 'foo', 'bar'")
        range = adapter.child_node_range(node, :value)
        expect(range.start).to eq 11
        expect(range.end).to eq 23
      end
    end

    context 'send node' do
      it 'checks receiver' do
        node = parser_parse('foo.bar(test)')
        range = adapter.child_node_range(node, :receiver)
        expect(range.start).to eq 0
        expect(range.end).to eq 3

        node = parser_parse('foobar(test)')
        range = adapter.child_node_range(node, :receiver)
        expect(range).to be_nil
      end

      it 'checks dot' do
        node = parser_parse('foo.bar(test)')
        range = adapter.child_node_range(node, :dot)
        expect(range.start).to eq 3
        expect(range.end).to eq 4

        node = parser_parse('foobar(test)')
        range = adapter.child_node_range(node, :dot)
        expect(range).to be_nil
      end

      it 'checks message' do
        node = parser_parse('foo.bar(test)')
        range = adapter.child_node_range(node, :message)
        expect(range.start).to eq 4
        expect(range.end).to eq 7

        node = parser_parse('foo.bar = test')
        range = adapter.child_node_range(node, :message)
        expect(range.start).to eq 4
        expect(range.end).to eq 9

        node = parser_parse('foobar(test)')
        range = adapter.child_node_range(node, :message)
        expect(range.start).to eq 0
        expect(range.end).to eq 6
      end

      it 'checks arguments' do
        node = parser_parse('foo.bar(arg1, arg2)')
        range = adapter.child_node_range(node, :arguments)
        expect(range.start).to eq 8
        expect(range.end).to eq 18

        range = adapter.child_node_range(node, 'arguments.0')
        expect(range.start).to eq 8
        expect(range.end).to eq 12

        range = adapter.child_node_range(node, 'arguments.-1')
        expect(range.start).to eq 14
        expect(range.end).to eq 18

        node = parser_parse('foobar(arg1, arg2)')
        range = adapter.child_node_range(node, :arguments)
        expect(range.start).to eq 7
        expect(range.end).to eq 17

        node = parser_parse('foo.bar')
        range = adapter.child_node_range(node, :arguments)
        expect(range).to be_nil
      end

      it 'checks parentheses' do
        node = parser_parse('foo.bar(test)')
        range = adapter.child_node_range(node, :parentheses)
        expect(range.start).to eq 7
        expect(range.end).to eq 13

        node = parser_parse('foobar(test)')
        range = adapter.child_node_range(node, :parentheses)
        expect(range.start).to eq 6
        expect(range.end).to eq 12

        node = parser_parse('foo.bar')
        range = adapter.child_node_range(node, :parentheses)
        expect(range).to be_nil
      end

      it 'checks unknown child name for node' do
        node = parser_parse('foo.bar(test)')
        expect {
          adapter.child_node_range(node, :unknown)
        }.to raise_error(NodeMutation::MethodNotSupported, "unknown is not supported for foo.bar(test)")
      end

      it 'checks unknown child name for array node' do
        node = parser_parse('foo.bar(foo, bar)')
        expect {
          adapter.child_node_range(node, "arguments.unknown")
        }.to raise_error(NodeMutation::MethodNotSupported, "unknown is not supported for foo, bar")
      end
    end

    context 'str' do
      it 'checks value' do
        code = "'foobar'"
        node = parser_parse(code)
        range = adapter.child_node_range(node, :value)
        expect(range.start).to eq 1
        expect(range.end).to eq code.length - 1
      end
    end

    context 'sym' do
      it 'checks value' do
        code = ':foobar'
        node = parser_parse(code)
        range = adapter.child_node_range(node, :value)
        expect(range.start).to eq 0
        expect(range.end).to eq code.length
      end
    end
  end

  describe '#get_start' do
    it 'gets start position' do
      node = parser_parse("class Synvert\nend")
      expect(adapter.get_start(node)).to eq 0
    end

    it 'gets start position for name child' do
      node = parser_parse("class Synvert\nend")
      expect(adapter.get_start(node, :name)).to eq 'class '.length
    end
  end

  describe '#get_end' do
    it 'gets end position' do
      node = parser_parse("class Synvert\nend")
      expect(adapter.get_end(node)).to eq "class Synvert\nend".length
    end

    it 'gets end position for name child' do
      node = parser_parse("class Synvert\nend")
      expect(adapter.get_end(node, :name)).to eq 'class Synvert'.length
    end
  end

  describe '#get_start_loc' do
    it 'gets start location' do
      node = parser_parse("class Synvert\nend")
      start_loc = adapter.get_start_loc(node)
      expect(start_loc.line).to eq 1
      expect(start_loc.column).to eq 0
    end

    it 'gets start location for name child' do
      node = parser_parse("class Synvert\nend")
      start_loc = adapter.get_start_loc(node, :name)
      expect(start_loc.line).to eq 1
      expect(start_loc.column).to eq 'class '.length
    end
  end

  describe '#get_end_loc' do
    it 'gets end location' do
      node = parser_parse("class Synvert\nend")
      end_loc = adapter.get_end_loc(node)
      expect(end_loc.line).to eq 2
      expect(end_loc.column).to eq 3
    end

    it 'gets end location for name child' do
      node = parser_parse("class Synvert\nend")
      end_loc = adapter.get_end_loc(node, :name)
      expect(end_loc.line).to eq 1
      expect(end_loc.column).to eq 'class Synvert'.length
    end
  end
end
