# frozen_string_literal: true

require_relative "node_mutation/version"

class NodeMutation
  class MethodNotSupported < StandardError; end
  class ConflictActionError < StandardError; end
  class InvalidAdapterError < StandardError; end

  autoload :Adapter, "node_mutation/adapter"
  autoload :ParserAdapter, "node_mutation/adapter/parser"
  autoload :SyntaxTreeAdapter, "node_mutation/adapter/syntax_tree"
  autoload :Action, 'node_mutation/action'
  autoload :AppendAction, 'node_mutation/action/append_action'
  autoload :GroupAction, 'node_mutation/action/group_action'
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
  autoload :Helper, 'node_mutation/helper'

  # @!attribute [r] actions
  #   @return [Array<NodeMutation::Struct::Action>]
  attr_reader :actions, :adapter

  # @!attribute [rw] transform_proc
  #  @return [Proc] proc to transfor the actions
  attr_accessor :transform_proc

  class << self
    # Configure NodeMutation
    # @param [Hash] options options to configure
    # @option options [NodeMutation::Strategy] :strategy the strategy
    # @option options [Integer] :tab_width the tab width
    def configure(options)
      if options[:strategy]
        @strategy = options[:strategy]
      end
      if options[:tab_width]
        @tab_width = options[:tab_width].to_i
      end
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
  # @param adapter [Symbol] :parser or :syntax_tree
  def initialize(source, adapter:)
    @source = source
    @actions = []
    @adapter = get_adapter_instance(adapter)
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
    @actions << AppendAction.new(node, code, adapter: @adapter).process
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
    @actions << DeleteAction.new(node, *selectors, and_comma: and_comma, adapter: @adapter).process
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
    @actions << InsertAction.new(node, code, at: at, to: to, and_comma: and_comma, adapter: @adapter).process
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
    @actions << PrependAction.new(node, code, adapter: @adapter).process
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
    @actions << RemoveAction.new(node, and_comma: and_comma, adapter: @adapter).process
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
    @actions << ReplaceAction.new(node, *selectors, with: with, adapter: @adapter).process
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
    @actions << ReplaceWithAction.new(node, code, adapter: @adapter).process
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
    @actions << IndentAction.new(node, adapter: @adapter).process
  end

  # No operation.
  # @param node [Node] ast node
  def noop(node)
    @actions << NoopAction.new(node, adapter: @adapter).process
  end

  # group multiple actions
  def group
    current_actions = @actions
    group_action = GroupAction.new
    @actions = group_action.actions
    yield
    @actions = current_actions
    @actions << group_action.process
  end

  # Process actions and return the new source.
  #
  # If there's an action range conflict,
  # it will raise a ConflictActionError if strategy is set to THROW_ERROR,
  # it will process all non conflicted actions and return `{ conflict: true }`
  # if strategy is set to KEEP_RUNNING.
  # @return {NodeMutation::Result}
  def process
    @actions = optimize_group_actions(@actions)

    flatten_actions = flat_actions(@actions)
    if flatten_actions.length == 0
      return NodeMutation::Result.new(affected: false, conflicted: false)
    end

    @transform_proc.call(@actions) if @transform_proc
    sorted_actions = sort_flatten_actions(flatten_actions)
    conflict_actions = get_conflict_actions(sorted_actions)
    if conflict_actions.size > 0 && strategy?(Strategy::THROW_ERROR)
      raise ConflictActionError, "mutation actions are conflicted"
    end

    actions = sort_flatten_actions(flat_actions(get_filter_actions(conflict_actions)))
    new_source = rewrite_source(+@source, actions)
    result = NodeMutation::Result.new(affected: true, conflicted: !conflict_actions.empty?)
    result.new_source = new_source
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
    @actions = optimize_group_actions(@actions)

    flatten_actions = flat_actions(@actions)
    if flatten_actions.length == 0
      return NodeMutation::Result.new(affected: false, conflicted: false)
    end

    @transform_proc.call(@actions) if @transform_proc
    sorted_actions = sort_flatten_actions(flatten_actions)
    conflict_actions = get_conflict_actions(sorted_actions)
    if conflict_actions.size > 0 && strategy?(Strategy::THROW_ERROR)
      raise ConflictActionError, "mutation actions are conflicted"
    end

    result = NodeMutation::Result.new(affected: true, conflicted: !conflict_actions.empty?)
    actions = sort_actions(get_filter_actions(conflict_actions))
    result.actions = actions.map(&:to_struct)
    result
  end

  private

  # Optimizes a list of actions, recursively optimizing any nested group actions.
  # @param actions [Array<NodeMutation::Action>]
  # @return [Array<NodeMutation::Action>] optimized actions
  def optimize_group_actions(actions)
    actions.map do |action|
      if action.is_a?(GroupAction)
        # If the group action contains only one action, replace the group action with that action
        if action.actions.length === 1
          return optimize_group_actions(action.actions)
        end

        # If the group action contains more than one action, optimize its sub-actions
        action.actions = optimize_group_actions(action.actions)
      end
      action
    end
  end

  # It flats a series of actions by removing any GroupAction
  # objects that contain only a single action. This is done recursively.
  # @param actions [Array<NodeMutation::Action>]
  # @return [Array<NodeMutation::Action>] flatten actions
  def flat_actions(actions)
    flatten_actions = []
    actions.each do |action|
      if action.is_a?(GroupAction)
        flatten_actions += flat_actions(action.actions)
      else
        flatten_actions << action
      end
    end
    flatten_actions
  end

  # Recusively sort actions by start position and end position.
  # @param actions [Array<NodeMutation::Action>]
  # @return [Array<NodeMutation::Action>] sorted actions
  def sort_actions(actions)
    actions.each do |action|
      if action.is_a?(GroupAction)
        action.actions = sort_actions(action.actions)
      end
    end
    actions.sort_by { |action| [action.start, action.end] }
  end

  # Sort actions by start position and end position.
  # @param actions [Array<NodeMutation::Action>]
  # @return [Array<NodeMutation::Action>] sorted actions
  def sort_flatten_actions(flatten_actions)
    flatten_actions.sort_by { |action| [action.start, action.end] }
  end

  # Rewrite source code with actions.
  # @param source [String] source code
  # @param actions [Array<NodeMutation::Action>] actions
  # @return [String] new source code
  def rewrite_source(source, actions)
    actions.reverse_each do |action|
      if action.is_a?(GroupAction)
        source = rewrite_source(source, action.actions)
      else
        source[action.start...action.end] = action.new_code if action.new_code
      end
    end
    source
  end

  # It changes source code from bottom to top, and it can change source code twice at the same time,
  # So if there is an overlap between two actions, it removes the conflict actions and operate them in the next loop.
  # @param actions [Array<NodeMutation::Action>]
  # @return [Array<NodeMutation::Action>] conflict actions
  def get_conflict_actions(actions)
    i = actions.length - 1
    j = i - 1
    conflict_actions = []
    return [] if i < 0

    begin_pos = actions[i].start
    end_pos = actions[i].end
    while j > -1
      # if we have two actions with overlapped range.
      if begin_pos < actions[j].end
        conflict_actions << actions[j]
      else
        i = j
        begin_pos = actions[i].start
        end_pos = actions[i].end
      end
      j -= 1
    end
    conflict_actions
  end

  # It filters conflict actions from actions.
  # @param actions [Array<NodeMutation::Action>]
  # @return [Array<NodeMutation::Action>] filtered actions
  def get_filter_actions(conflict_actions)
    @actions.select do |action|
      if action.is_a?(GroupAction)
        action.actions.all? { |child_action| !conflict_actions.include?(child_action) }
      else
        !conflict_actions.include?(action)
      end
    end
  end

  def strategy?(strategy)
    NodeMutation.strategy & strategy == strategy
  end

  def get_adapter_instance(adapter)
    case adapter.to_sym
    when :parser
      ParserAdapter.new
    when :syntax_tree
      SyntaxTreeAdapter.new
    else
      raise InvalidAdapterError, "adapter #{adapter} is not supported"
    end
  end
end
