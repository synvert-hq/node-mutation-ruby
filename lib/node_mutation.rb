# frozen_string_literal: true

require 'ostruct'
require 'active_support/core_ext/array'

require_relative "node_mutation/version"

class NodeMutation
  class MethodNotSupported < StandardError; end
  class ConflictActionError < StandardError; end

  KEEP_RUNNING = 1
  THROW_ERROR = 2

  autoload :Adapter, "node_mutation/adapter"
  autoload :ParserAdapter, "node_mutation/parser_adapter"
  autoload :Action, 'node_mutation/action'
  autoload :AppendAction, 'node_mutation/action/append_action'
  autoload :DeleteAction, 'node_mutation/action/delete_action'
  autoload :InsertAction, 'node_mutation/action/insert_action'
  autoload :InsertAfterAction, 'node_mutation/action/insert_after_action'
  autoload :RemoveAction, 'node_mutation/action/remove_action'
  autoload :PrependAction, 'node_mutation/action/prepend_action'
  autoload :ReplaceAction, 'node_mutation/action/replace_action'
  autoload :ReplaceWithAction, 'node_mutation/action/replace_with_action'
  autoload :WrapAction, 'node_mutation/action/wrap_action'
  autoload :NoopAction, 'node_mutation/action/noop_action'
  autoload :Result, 'node_mutation/result'

  attr_reader :actions

  # Configure NodeMutation
  # @param [Hash] options options to configure
  # @option options [NodeMutation::Adapter] :adapter the adpater
  def self.configure(options)
    if options[:adapter]
      @adapter = options[:adapter]
    end
    if options[:strategy]
      @strategy = options[:strategy]
    end
  end

  # Get the adapter
  # @return [NodeMutation::Adapter] current adapter, by default is {NodeMutation::ParserAdapter}
  def self.adapter
    @adapter ||= ParserAdapter.new
  end

  # Get the strategy
  # @return [Integer] current strategy, could be {NodeMutation::KEEP_RUNNING} or {NodeMutation::THROW_ERROR},
  # by default is {NodeMutation::KEEP_RUNNING}
  def self.strategy
    @strategy ||= KEEP_RUNNING
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
  # @param options [Hash]
  # @option and_comma [Boolean] delete extra comma.
  # @example
  # source code of the ast node is
  #     FactoryBot.create(...)
  # then we call
  #     mutation.delete(node, :receiver, :dot)
  # the source code will be rewritten to
  #     create(...)
  def delete(node, *selectors, **options)
    @actions << DeleteAction.new(node, *selectors, **options).process
  end

  # Insert code to the ast node.
  # @param node [Node] ast node
  # @param code [String] code need to be inserted.
  # @param at [String] insert position, beginning or end
  # @param to [String] where to insert, if it is nil, will insert to current node.
  # @example
  # source code of the ast node is
  #     open('http://test.com')
  # then we call
  #     mutation.insert(node, 'URI.', at: 'beginning')
  # the source code will be rewritten to
  #     URI.open('http://test.com')
  def insert(node, code, at: 'end', to: nil)
    @actions << InsertAction.new(node, code, at: at, to: to).process
  end

  # Insert code next to the ast node.
  # @param node [Node] ast node
  # @param code [String] new code to insert.
  # @example
  # source code of the ast node is
  #     Synvert::Application.config.secret_token = "0447aa931d42918bfb934750bb78257088fb671186b5d1b6f9fddf126fc8a14d34f1d045cefab3900751c3da121a8dd929aec9bafe975f1cabb48232b4002e4e"
  # then we call
  #     mutation.insert_after(node, "{{receiver}}.secret_key_base = \"#{SecureRandom.hex(64)}\"")
  # the source code will be rewritten to
  #     Synvert::Application.config.secret_token = "0447aa931d42918bfb934750bb78257088fb671186b5d1b6f9fddf126fc8a14d34f1d045cefab3900751c3da121a8dd929aec9bafe975f1cabb48232b4002e4e"
  #     Synvert::Application.config.secret_key_base = "bf4f3f46924ecd9adcb6515681c78144545bba454420973a274d7021ff946b8ef043a95ca1a15a9d1b75f9fbdf85d1a3afaf22f4e3c2f3f78e24a0a188b581df"
  def insert_after(node, code)
    @actions << InsertAfterAction.new(node, code).process
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
  # @param options [Hash] options.
  # @option and_comma [Boolean] delete extra comma.
  # @example
  # source code of the ast node is
  #     puts "test"
  # then we call
  #     mutation.remove(node)
  # the source code will be removed
  def remove(node, **options)
    @actions << RemoveAction.new(node, **options).process
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

  # Wrap source code of the ast node with new code.
  # @param node [Node] ast node
  # @param with [String] code need to be wrapped with.
  # @example
  # source code of the ast node is
  #     class Foobar
  #     end
  # then we call
  #     wrap(node, with: 'module Synvert')
  # the source code will be rewritten to
  #     module Synvert
  #       class Foobar
  #       end
  #     end
  def wrap(node, with:)
    @actions << WrapAction.new(node, with: with).process
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

    conflict_actions = []
    source = +@source
    @actions.sort_by! { |action| [action.start, action.end] }
    conflict_actions = get_conflict_actions
    if conflict_actions.size > 0 && NodeMutation.strategy == THROW_ERROR
      raise ConflictActionError, "mutation actions are conflicted"
    end
    @actions.reverse_each do |action|
      source[action.start...action.end] = action.new_code
    end
    NodeMutation::Result.new(
      affected: true,
      conflicted: !conflict_actions.empty?,
      new_source: source
    )
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
      return NodeMutation::Result.new(affected: false, conflicted: false, actions: [])
    end

    conflict_actions = []
    @actions.sort_by! { |action| [action.start, action.end] }
    conflict_actions = get_conflict_actions
    if conflict_actions.size > 0 && NodeMutation.strategy == THROW_ERROR
      raise ConflictActionError, "mutation actions are conflicted"
    end
    NodeMutation::Result.new(
      affected: true,
      conflicted: !conflict_actions.empty?,
      actions: format_actions(@actions)
    )
  end

  private

  # It changes source code from bottom to top, and it can change source code twice at the same time,
  # So if there is an overlap between two actions, it removes the conflict actions and operate them in the next loop.
  def get_conflict_actions
    i = @actions.length - 1
    j = i - 1
    conflict_actions = []
    return [] if i < 0

    start = @actions[i].start
    while j > -1
      if start < @actions[j].end
        conflict_actions << @actions.delete_at(j)
      else
        i = j
        start = @actions[i].start
      end
      j -= 1
    end
    conflict_actions
  end

  def format_actions(actions)
    actions.map { |action| OpenStruct.new(start: action.start, end: action.end, new_code: action.new_code ) }
  end
end
