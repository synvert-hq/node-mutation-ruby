# frozen_string_literal: true

# ReplaceAction to replace child node with code.
class NodeMutation::ReplaceAction < NodeMutation::Action
  # Initailize a ReplaceAction.
  #
  # @param node [Node]
  # @param selectors [Array<Symbol|String>] used to select child nodes
  # @param with [String] the new code
  def initialize(node, *selectors, adapter:, with:)
    super(node, with, adapter: adapter)
    @selectors = selectors
    @type = :replace
  end

  # The rewritten source code.
  #
  # @return [String] rewritten code.
  def new_code
    rewritten_source
  end

  private

  # Calculate the begin the end positions.
  def calculate_position
    @start = @selectors.map { |selector| @adapter.child_node_range(@node, selector).start }.min
    @end = @selectors.map { |selector| @adapter.child_node_range(@node, selector).end }.max
  end
end
