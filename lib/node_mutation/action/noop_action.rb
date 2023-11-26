# frozen_string_literal: true

# NoopAction to do no operation.
class NodeMutation::NoopAction < NodeMutation::Action
  # Create a NoopAction
  def initialize(node, adapter:)
    super(node, nil, adapter: adapter)
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
    @start = @adapter.get_start(@node)
    @end = @adapter.get_end(@node)
  end
end
