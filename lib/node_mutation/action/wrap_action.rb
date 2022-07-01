# frozen_string_literal: true

# WrapAction to wrap node within a block, class or module.
#
# Note: if WrapAction is conflicted with another action (start and end are overlapped),
# we have to put those 2 actions into 2 within_file scopes.
class NodeMutation::WrapAction < NodeMutation::Action
  # Initialize a WrapAction.
  #
  # @param node [Node]
  # @param with [String] new code to wrap
  def initialize(node, with:)
    super(node, with)
    @indent = NodeMutation.adapter.get_start_loc(@node).column
  end

  # The rewritten source code.
  #
  # @return [String] rewritten code.
  def new_code
    "#{@code}\n#{' ' * @indent}" +
      NodeMutation.adapter.get_source(@node).split("\n").map { |line| "  #{line}" }
            .join("\n") +
      "\n#{' ' * @indent}end"
  end

  private

  # Calculate the begin the end positions.
  def calculate_position
    @start = NodeMutation.adapter.get_start(@node)
    @end = NodeMutation.adapter.get_end(@node)
  end
end
