# frozen_string_literal: true

# ReplaceWithAction to replace code.
class NodeMutation::ReplaceWithAction < NodeMutation::Action
  def initialize(node, code)
    super(node, code)
    @type = :replace
  end

  # The rewritten source code with proper indent.
  #
  # @return [String] rewritten code.
  def new_code
    if rewritten_source.include?("\n")
      new_code = []
      rewritten_source.split("\n").each_with_index do |line, index|
        new_code << (index == 0 ? line : indent + line)
      end
      new_code.join("\n")
    else
      rewritten_source
    end
  end

  private

  # Calculate the begin the end positions.
  def calculate_position
    @start = NodeMutation.adapter.get_start(@node)
    @end = NodeMutation.adapter.get_end(@node)
  end

  # Indent of the node
  #
  # @return [String] n times whitesphace
  def indent
    ' ' * NodeMutation.adapter.get_start_loc(@node).column
  end
end
