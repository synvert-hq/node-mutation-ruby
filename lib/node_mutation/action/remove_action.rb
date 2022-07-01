# frozen_string_literal: true

# RemoveAction to remove current node.
class NodeMutation::RemoveAction < NodeMutation::Action
  # Initialize a RemoveAction.
  #
  # @param node [Node]
  # @param options [Hash] options.
  # @option and_comma [Boolean] delete extra comma.
  def initialize(node, and_comma: false)
    super(node, nil)
    @and_comma = and_comma
  end

  # The rewritten code, always empty string.
  def new_code
    ''
  end

  private

  # Calculate the begin the end positions.
  def calculate_position
    if take_whole_line?
      @start = start_index
      @end = end_index
      squeeze_lines
    else
      @start = NodeMutation.adapter.get_start(@node)
      @end = NodeMutation.adapter.get_end(@node)
      squeeze_spaces
      remove_comma if @and_command
    end
  end

  # Check if the source code of current node takes the whole line.
  #
  # @return [Boolean]
  def take_whole_line?
    NodeMutation.adapter.get_source(@node) == file_source[start_index...end_index].strip
  end

  # Get the start position of the line
  def start_index
    index = file_source[0..NodeMutation.adapter.get_start(@node)].rindex("\n")
    index ? index + "\n".length : NodeMutation.adapter.get_start(@node)
  end

  # Get the end position of the line
  def end_index
    index = file_source[NodeMutation.adapter.get_end(@node)..-1].index("\n")
    index ? NodeMutation.adapter.get_end(@node) + index + "\n".length : NodeMutation.adapter.get_end(@node)
  end
end
