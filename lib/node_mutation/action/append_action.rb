# frozen_string_literal: true

# AppendAction appends code to the bottom of node body.
class NodeMutation::AppendAction < NodeMutation::Action
  def initialize(node, code)
    super(node, code)
    @type = :insert
  end

  private

  END_LENGTH = "\nend".length

  # Calculate the begin the end positions.
  def calculate_position
    @start = NodeMutation.adapter.get_end(@node) - NodeMutation.adapter.get_start_loc(@node).column - END_LENGTH
    @end = @start
  end

  # Indent of the node.
  #
  # @param node [Parser::AST::Node]
  # @return [String] n times whitesphace
  def indent(node)
    ' ' *  (NodeMutation.adapter.get_start_loc(node).column + NodeMutation.tab_width)
  end
end
