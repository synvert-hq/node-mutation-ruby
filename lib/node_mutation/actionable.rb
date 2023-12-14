# frozen_string_literal: true

module NodeMutation::Actionable
  # Append code to the ast node.
  # @param node [Node] ast node
  # @param code [String] new code to append
  # @example
  # source code of the ast node is
  #     def teardown
  #       clean_something
  #     end
  # then we call
  #     mutation.append(node, 'super')
  # the source code will be rewritten to
  #     def teardown
  #       clean_something
  #       super
  #     end
  def append(node, code)
    @actions << NodeMutation::AppendAction.new(node, code, adapter: @adapter).process
  end

  # Delete source code of the child ast node.
  # @param node [Node] ast node
  # @param selectors [Array<Symbol>] selector names of child node.
  # @param and_comma [Boolean] delete extra comma.
  # @example
  # source code of the ast node is
  #     FactoryBot.create(...)
  # then we call
  #     mutation.delete(node, :receiver, :dot)
  # the source code will be rewritten to
  #     create(...)
  def delete(node, *selectors, and_comma: false)
    @actions << NodeMutation::DeleteAction.new(node, *selectors, and_comma: and_comma, adapter: @adapter).process
  end

  # Insert code to the ast node.
  # @param node [Node] ast node
  # @param code [String] code need to be inserted.
  # @param at [String] insert position, beginning or end
  # @param to [String] where to insert, if it is nil, will insert to current node.
  # @param and_comma [Boolean] insert extra comma.
  # @example
  # source code of the ast node is
  #     open('http://test.com')
  # then we call
  #     mutation.insert(node, 'URI.', at: 'beginning')
  # the source code will be rewritten to
  #     URI.open('http://test.com')
  def insert(node, code, at: 'end', to: nil, and_comma: false)
    @actions << NodeMutation::InsertAction.new(node, code, at: at, to: to, and_comma: and_comma, adapter: @adapter).process
  end

  # Prepend code to the ast node.
  # @param node [Node] ast node
  # @param code [String] new code to prepend.
  # @example
  # source code of the ast node is
  #     def setup
  #       do_something
  #     end
  # then we call
  #     mutation.prepend(node, 'super')
  # the source code will be rewritten to
  #     def setup
  #       super
  #       do_something
  #     end
  def prepend(node, code)
    @actions << NodeMutation::PrependAction.new(node, code, adapter: @adapter).process
  end

  # Remove source code of the ast node.
  # @param node [Node] ast node
  # @param and_comma [Boolean] delete extra comma.
  # @example
  # source code of the ast node is
  #     puts "test"
  # then we call
  #     mutation.remove(node)
  # the source code will be removed
  def remove(node, and_comma: false)
    @actions << NodeMutation::RemoveAction.new(node, and_comma: and_comma, adapter: @adapter).process
  end

  # Replace child node of the ast node with new code.
  # @param node [Node] ast node
  # @param selectors [Array<Symbol>] selector names of child node.
  # @param with [String] code need to be replaced with.
  # @example
  # source code of the ast node is
  #     assert(object.empty?)
  # then we call
  #     mutation.replace(node, :message, with: 'assert_empty')
  #     mutation.replace(node, :arguments, with: '{{arguments.first.receiver}}')
  # the source code will be rewritten to
  #     assert_empty(object)
  def replace(node, *selectors, with:)
    @actions << NodeMutation::ReplaceAction.new(node, *selectors, with: with, adapter: @adapter).process
  end

  # Replace source code of the ast node with new code.
  # @param node [Node] ast node
  # @param code [String] code need to be replaced with.
  # @example
  # source code of the ast node is
  #     obj.stub(:foo => 1, :bar => 2)
  # then we call
  #     replace_with 'allow({{receiver}}).to receive_messages({{arguments}})'
  # the source code will be rewritten to
  #     allow(obj).to receive_messages(:foo => 1, :bar => 2)
  def replace_with(node, code)
    @actions << NodeMutation::ReplaceWithAction.new(node, code, adapter: @adapter).process
  end

  # Wrap source code of the ast node with prefix and suffix code.
  # @param node [Node] ast node
  # @param prefix [String] prefix code need to be wrapped with.
  # @param suffix [String] suffix code need to be wrapped with.
  # @param newline [Boolean] add newline after prefix and before suffix.
  # @example
  # source code of the ast node is
  #     class Foobar
  #     end
  # then we call
  #     wrap(node, prefix: 'module Synvert', suffix: 'end', newline: true)
  # the source code will be rewritten to
  #     module Synvert
  #       class Foobar
  #       end
  #     end
  def wrap(node, prefix:, suffix:, newline: false)
    if newline
      indentation = @adapter.get_start_loc(node).column
      group do
        insert node, prefix + "\n" + (' ' * indentation), at: 'beginning'
        insert node, "\n" + (' ' * indentation) + suffix, at: 'end'
        indent node
      end
    else
      group do
        insert node, prefix, at: 'beginning'
        insert node, suffix, at: 'end'
      end
    end
  end

  # Indent source code of the ast node
  # @param node [Node] ast node
  # @example
  # source code of ast node is
  #     class Foobar
  #     end
  # then we call
  #     indent(node)
  # the source code will be rewritten to
  #       class Foobar
  #       end
  def indent(node)
    @actions << NodeMutation::IndentAction.new(node, adapter: @adapter).process
  end

  # No operation.
  # @param node [Node] ast node
  def noop(node)
    @actions << NodeMutation::NoopAction.new(node, adapter: @adapter).process
  end

  # group multiple actions
  def group(&block)
    @actions << NodeMutation::GroupAction.new(adapter: @adapter, &block).process
  end
end