# frozen_string_literal: true

# PrependAction to prepend code to the top of node body.
class NodeMutation::PrependAction < NodeMutation::Action
  # Initialize an PrependAction.
  #
  # @param node [Node]
  # @param code [String] new code to prepend.
  # @param adapter [NodeMutation::Adapter]
  def initialize(node, code, adapter:)
    super(node, code, adapter: adapter)
    @type = :insert
  end

  private

  # Calculate the begin and end positions.
  def calculate_position
    node_start = @adapter.get_start(@node)
    node_source = @adapter.get_source(@node)
    first_line = node_source.split("\n").first
    @start = node_start + first_line.length
    @end = @start
  end

  # Indent of the node.
  #
  # @param node [Parser::AST::Node]
  # @return [String] n times whitesphace
  def indent(node)
    ' ' * (@adapter.get_start_loc(node).column + NodeMutation.tab_width)
  end
end
