# frozen_string_literal: true

# PrependAction to prepend code to the top of node body.
class NodeMutation::PrependAction < NodeMutation::Action
  def initialize(node, code)
    super(node, code)
    @type = :insert
  end

  private

  # Calculate the begin and end positions.
  def calculate_position
    node_start = NodeMutation.adapter.get_start(@node)
    node_source = NodeMutation.adapter.get_source(@node)
    first_line = node_source.split("\n").first
    @start = first_line.end_with?("do") ? node_start + first_line.rindex("do") + "do".length : node_start + first_line.length
    @end = @start
  end

  # Indent of the node.
  #
  # @param node [Parser::AST::Node]
  # @return [String] n times whitesphace
  def indent(node)
    ' ' * (NodeMutation.adapter.get_start_loc(node).column + NodeMutation.tab_width)
  end
end
