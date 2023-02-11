# frozen_string_literal: true

# Action defines rewriter action, insert, replace or delete code.
class NodeMutation::Action
  # @!attribute [r] start
  #   @return [Integer] start position
  # @!attribute [r] end
  #   @return [Integer] end position
  attr_reader :start, :end

  # Initialize an action.
  #
  # @param node [Node]
  # @param code [String] new code to insert, replace or delete.
  def initialize(node, code)
    @node = node
    @code = code
  end

  # Calculate begin and end positions, and return self.
  #
  # @return [NodeMutation::Action] self
  def process
    calculate_position
    self
  end

  # The rewritten source code with proper indent.
  #
  # @return [String] rewritten code.
  def new_code
    if rewritten_source.split("\n").length > 1
      "\n\n" + rewritten_source.split("\n").map { |line| indent(@node) + line }.join("\n")
    else
      "\n" + indent(@node) + rewritten_source
    end
  end

  protected

  # Calculate the begin the end positions.
  #
  # @abstract
  def calculate_position
    raise NotImplementedError, 'must be implemented by subclasses'
  end

  # The rewritten source code.
  #
  # @return [String] rewritten source code.
  def rewritten_source
    @rewritten_source ||= NodeMutation.adapter.rewritten_source(@node, @code)
  end

  # Squeeze spaces from source code.
  def squeeze_spaces
    if file_source[@start - 1] == ' ' && [' ', "\n", ';'].include?(file_source[@end])
      @start -= 1
    end
  end

  # Squeeze empty lines from source code.
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

  # Remove unused comma.
  # e.g. `foobar(foo, bar)`, if we remove `foo`, the comma should also be removed,
  # the code should be changed to `foobar(bar)`.
  def remove_comma
    if ',' == file_source[@start - 1]
      @start -= 1
    elsif ', ' == file_source[@start - 2, 2]
      @start -= 2
    elsif ', ' == file_source[@end, 2]
      @end += 2
    elsif ',' == file_source[@end]
      @end += 1
    end
  end

  # Return file source.
  #
  # @return [String]
  def file_source
    @file_source ||= NodeMutation.adapter.file_content(@node)
  end
end
