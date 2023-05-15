# frozen_string_literal: true

require_relative "node_mutation/version"

class NodeMutation
  class MethodNotSupported < StandardError; end
  class ConflictActionError < StandardError; end

  autoload :Adapter, "node_mutation/adapter"
  autoload :ParserAdapter, "node_mutation/adapter/parser"
  autoload :SyntaxTreeAdapter, "node_mutation/adapter/syntax_tree"
  autoload :Action, 'node_mutation/action'
  autoload :AppendAction, 'node_mutation/action/append_action'
  autoload :DeleteAction, 'node_mutation/action/delete_action'
  autoload :IndentAction, 'node_mutation/action/indent_action'
  autoload :InsertAction, 'node_mutation/action/insert_action'
  autoload :RemoveAction, 'node_mutation/action/remove_action'
  autoload :PrependAction, 'node_mutation/action/prepend_action'
  autoload :ReplaceAction, 'node_mutation/action/replace_action'
  autoload :ReplaceWithAction, 'node_mutation/action/replace_with_action'
  autoload :NoopAction, 'node_mutation/action/noop_action'
  autoload :Result, 'node_mutation/result'
  autoload :Strategy, 'node_mutation/strategy'
  autoload :Struct, 'node_mutation/struct'

  # @!attribute [r] actions
  #   @return [Array<NodeMutation::Struct::Action>]
  attr_reader :actions

  # @!attribute [rw] transform_proc
  #  @return [Proc] proc to transfor the actions
  attr_accessor :transform_proc

  class << self
    # Configure NodeMutation
    # @param [Hash] options options to configure
    # @option options [NodeMutation::Adapter] :adapter the adpater
    # @option options [NodeMutation::Strategy] :strategy the strategy
    # @option options [Integer] :tab_width the tab width
    def configure(options)
      if options[:adapter]
        @adapter = options[:adapter]
      end
      if options[:strategy]
        @strategy = options[:strategy]
      end
      if options[:tab_width]
        @tab_width = options[:tab_width].to_i
      end
    end

    # Get the adapter
    # @return [NodeMutation::Adapter] current adapter, by default is {NodeMutation::ParserAdapter}
    def adapter
      @adapter ||= ParserAdapter.new
    end

    # Get the strategy
    # @return [Integer] current strategy, could be {NodeMutation::Strategy::KEEP_RUNNING} or {NodeMutation::Strategy::THROW_ERROR},
    # by default is {NodeMutation::Strategy::KEEP_RUNNING}
    def strategy
      @strategy ||= Strategy::KEEP_RUNNING
    end

    # Get tab width
    # @return [Integer] tab width, by default is 2
    def tab_width
      @tab_width ||= 2
    end
  end

  # Initialize a NodeMutation.
  # @param source [String] file source
  def initialize(source)
    @source = source
    @actions = []
  end

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
    @actions << AppendAction.new(node, code).process
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
    @actions << DeleteAction.new(node, *selectors, and_comma: and_comma).process
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
    @actions << InsertAction.new(node, code, at: at, to: to, and_comma: and_comma).process
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
    @actions << PrependAction.new(node, code).process
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
    @actions << RemoveAction.new(node, and_comma: and_comma).process
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
    @actions << ReplaceAction.new(node, *selectors, with: with).process
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
    @actions << ReplaceWithAction.new(node, code).process
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
      indentation = NodeMutation.adapter.get_start_loc(node).column
      @actions << InsertAction.new(node, prefix + "\n" + ' ' * indentation, at: 'beginning').process
      @actions << InsertAction.new(node, "\n" + ' ' * indentation + suffix, at: 'end').process
      @actions << IndentAction.new(node).process
    else
      @actions << InsertAction.new(node, prefix, at: 'beginning').process
      @actions << InsertAction.new(node, suffix, at: 'end').process
    end
  end

  # No operation.
  # @param node [Node] ast node
  def noop(node)
    @actions << NoopAction.new(node).process
  end

  # Process actions and return the new source.
  #
  # If there's an action range conflict,
  # it will raise a ConflictActionError if strategy is set to THROW_ERROR,
  # it will process all non conflicted actions and return `{ conflict: true }`
  # if strategy is set to KEEP_RUNNING.
  # @return {NodeMutation::Result}
  def process
    if @actions.length == 0
      return NodeMutation::Result.new(affected: false, conflicted: false)
    end

    source = +@source
    @transform_proc.call(@actions) if @transform_proc
    @actions.sort_by! { |action| [action.start, action.end] }
    conflict_actions = get_conflict_actions
    if conflict_actions.size > 0 && strategy?(Strategy::THROW_ERROR)
      raise ConflictActionError, "mutation actions are conflicted"
    end

    @actions.reverse_each do |action|
      source[action.start...action.end] = action.new_code if action.new_code
    end
    result = NodeMutation::Result.new(affected: true, conflicted: !conflict_actions.empty?)
    result.new_source = source
    result
  end

  # Test actions and return the actions.
  #
  # If there's an action range conflict,
  # it will raise a ConflictActionError if strategy is set to THROW_ERROR,
  # it will process all non conflicted actions and return `{ conflict: true }`
  # if strategy is set to KEEP_RUNNING.
  # @return {NodeMutation::Result}
  def test
    if @actions.length == 0
      return NodeMutation::Result.new(affected: false, conflicted: false)
    end

    @transform_proc.call(@actions) if @transform_proc
    @actions.sort_by! { |action| [action.start, action.end] }
    conflict_actions = get_conflict_actions
    if conflict_actions.size > 0 && strategy?(Strategy::THROW_ERROR)
      raise ConflictActionError, "mutation actions are conflicted"
    end

    result = NodeMutation::Result.new(affected: true, conflicted: !conflict_actions.empty?)
    result.actions = @actions
    result
  end

  private

  # It changes source code from bottom to top, and it can change source code twice at the same time,
  # So if there is an overlap between two actions, it removes the conflict actions and operate them in the next loop.
  def get_conflict_actions
    i = @actions.length - 1
    j = i - 1
    conflict_actions = []
    return [] if i < 0

    begin_pos = @actions[i].start
    end_pos = @actions[i].end
    while j > -1
      # if we have two actions with overlapped range.
      if begin_pos < @actions[j].end
        conflict_actions << @actions.delete_at(j)
      else
        i = j
        begin_pos = @actions[i].start
        end_pos = @actions[i].end
      end
      j -= 1
    end
    conflict_actions
  end

  def strategy?(strategy)
    NodeMutation.strategy & strategy == strategy
  end
end
