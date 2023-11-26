# frozen_string_literal: true

# IndentAction to indent code.
class NodeMutation::IndentAction < NodeMutation::Action
  # Initialize a IndentAction.
  #
  # @param node [Node]
  # @param tab_size [Integer] tab size
  # @param adapter [NodeMutation::Adapter]
  def initialize(node, tab_size = 1, adapter:)
    super(node, nil, adapter: adapter)
    @tab_size = tab_size
    @type = :replace
  end

  # The rewritten source code with proper indent.
  #
  # @return [String] rewritten code.
  def new_code
    source = @adapter.get_source(@node)
    source.each_line.map { |line| (' ' * NodeMutation.tab_width * @tab_size) + line }
          .join
  end

  private

  # Calculate the begin the end positions.
  def calculate_position
    @start = @adapter.get_start(@node)
    @end = @adapter.get_end(@node)
  end
end
