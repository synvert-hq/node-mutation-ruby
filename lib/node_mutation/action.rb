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
      "\n\n" + rewritten_source.split("\n").map { |line| indent(@node) + line }
                               .join("\n")
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

  # remove unused whitespace.
  def remove_whitespace
    while file_source[@end] == ' '
      @end += 1
    end
  end

  # Remove unused comma.
  # e.g. `foobar(foo, bar)`, if we remove `foo`, the comma should also be removed,
  # the code should be changed to `foobar(bar)`.
  def remove_comma
    leading_count = 1
    loop do
      if file_source[@start - leading_count] == ','
        @start -= leading_count
        return
      elsif ["\n", "\r", "\t", ' '].include?(file_source[@start - leading_count])
        leading_count += 1
      else
        break
      end
    end

    trailing_count = 0
    loop do
      if file_source[@end + trailing_count] == ','
        @end += trailing_count + 1
        return
      elsif file_source[@end + trailing_count] == ' '
        trailing_count += 1
      else
        break
      end
    end
  end

  # Return file source.
  #
  # @return [String]
  def file_source
    @file_source ||= NodeMutation.adapter.file_content(@node)
  end
end
