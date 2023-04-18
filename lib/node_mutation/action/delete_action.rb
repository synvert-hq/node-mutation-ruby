# frozen_string_literal: true

# DeleteAction deletes child nodes.
class NodeMutation::DeleteAction < NodeMutation::Action
  # Initialize a DeleteAction.
  #
  # @param node [Node]
  # @param selectors [Array<Symbol, String>] used to select child nodes
  # @option and_comma [Boolean] delete extra comma.
  def initialize(node, *selectors, and_comma: false)
    super(node, nil)
    @selectors = selectors
    @and_comma = and_comma
    @type = :delete
  end

  # The rewritten code, always empty string.
  def new_code
    ''
  end

  private

  # Calculate the begin and end positions.
  def calculate_position
    @start = @selectors.map { |selector| NodeMutation.adapter.child_node_range(@node, selector) }
                       .compact.map(&:start).min
    @end = @selectors.map { |selector| NodeMutation.adapter.child_node_range(@node, selector) }
                     .compact.map(&:end).max
    remove_comma if @and_comma
    remove_whitespace
  end
end
