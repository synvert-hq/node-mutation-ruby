# frozen_string_literal: true

# AppendAction appends code to the bottom of node body.
class NodeMutation::AppendAction < NodeMutation::Action
  # Initialize an AppendAction.
  #
  # @param node [Node]
  # @param code [String] new code to append.
  # @param adapter [NodeMutation::Adapter]
  def initialize(node, code, adapter:)
    super(node, code, adapter: adapter)
    @type = :insert
  end

  private

  END_LENGTH = "\nend".length

  # Calculate the begin the end positions.
  def calculate_position
    node_end = @adapter.get_end(@node)
    node_source = @adapter.get_source(@node)
    last_line = node_source.split("\n").last
    @start = node_end - last_line.length - 1
    @end = @start
  end

  # Indent of the node.
  #
  # @param node [Parser::AST::Node]
  # @return [String] n times whitesphace
  def indent(node)
    ' ' *  (@adapter.get_start_loc(node).column + NodeMutation.tab_width)
  end
end
