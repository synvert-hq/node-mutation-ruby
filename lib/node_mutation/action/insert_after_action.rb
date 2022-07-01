# frozen_string_literal: true

# InsertAfterAction to insert code next to the node.
class NodeMutation::InsertAfterAction < NodeMutation::Action
  private

  # Calculate the begin and end positions.
  def calculate_position
    @start = NodeMutation.adapter.get_end(@node)
    @end = @start
  end

  # Indent of the node.
  #
  # @param node [Parser::AST::Node]
  # @return [Integer] indent size
  def indent(node)
    ' ' * NodeMutation.adapter.get_start_loc(node).column
  end
end
