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
    if take_whole_line?
      remove_newline
      squeeze_lines
    end
  end

  # Check if the source code of current node takes the whole line.
  #
  # @return [Boolean]
  def take_whole_line?
    NodeMutation.adapter.get_source(@node) == file_source[@start...@end].strip.chomp(',')
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
    end

    if file_source[@start - leading_count] == "\n"
      @start -= leading_count - 1
    end
  end

  def squeeze_lines
    lines = file_source.split("\n")
    begin_line = NodeMutation.adapter.get_start_loc(@node).line
    end_line = NodeMutation.adapter.get_end_loc(@node).line
    before_line_is_blank = begin_line == 1 || lines[begin_line - 2] == ''
    after_line_is_blank = lines[end_line] == ''

    if lines.length > 1 && before_line_is_blank && after_line_is_blank
      @end += "\n".length
    end
  end
end
