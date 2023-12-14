# frozen_string_literal: true

require_relative "node_mutation/version"

class NodeMutation
  class MethodNotSupported < StandardError; end
  class ConflictActionError < StandardError; end
  class InvalidAdapterError < StandardError; end

  autoload :Actionable, "node_mutation/actionable"
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

  include Actionable

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

    source = +@source
    @transform_proc.call(@actions) if @transform_proc
    sorted_actions = sort_flatten_actions(flatten_actions)
    conflict_actions = get_conflict_actions(sorted_actions)
    if conflict_actions.size > 0 && strategy?(Strategy::THROW_ERROR)
      raise ConflictActionError, "mutation actions are conflicted"
    end

    actions = sort_flatten_actions(flat_actions(get_filter_actions(conflict_actions)))
    new_source = rewrite_source(source, actions)
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
