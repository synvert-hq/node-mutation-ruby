# frozen_string_literal: true

# NoopAction to do no operation.
class NodeMutation::NoopAction < NodeMutation::Action
  # Create a NoopAction
  def initialize(node)
    super(node, nil)
  end

  # The rewritten source code with proper indent.
  #
  # @return [String] rewritten code.
  def new_code
    return nil
  end

  private

  # Calculate the begin the end positions.
  def calculate_position
    @start = NodeMutation.adapter.get_start(@node)
    @end = NodeMutation.adapter.get_end(@node)
  end
end
