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
    @start = NodeMutation.adapter.get_start(@node)
    @end = NodeMutation.adapter.get_end(@node)
    remove_comma if @and_comma
    remove_whitespace
    remove_newline if take_whole_line?
  end

  def remove_newline
    leading_count = 1
    loop do
      if file_source[@start - leading_count] == "\n"
        break
      elsif ["\t", ' '].include?(file_source[@start - leading_count])
        leading_count += 1
      else
        break
      end
    end

    trailing_count = 0
    loop do
      if file_source[@end + trailing_count] == "\n"
        break
      elsif ["\t", ' '].include?(file_source[@end + trailing_count])
        trailing_count += 1
      else
        break
      end
    end

    if file_source[@end + trailing_count] == "\n"
      @end += trailing_count + 1
      return
    end

    if file_source[@start - leading_count] == "\n"
      @start -= leading_count
    end
  end

  # Check if the source code of current node takes the whole line.
  #
  # @return [Boolean]
  def take_whole_line?
    NodeMutation.adapter.get_source(@node) == file_source[@start...@end].strip.chomp(',')
  end
end
