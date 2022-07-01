# frozen_string_literal: true

# InsertAction to add code to the node.
class NodeMutation::InsertAction < NodeMutation::Action
  # Initialize an InsertAction.
  #
  # @param ndoe [Node]
  # @param code [String] to be inserted
  # @param at [String] position to insert, beginning or end
  # @param to [<nil|String>] name of child node
  def initialize(node, code, at: 'end', to: nil)
    super(node, code)
    @at = at
    @to = to
  end

  # The rewritten source code.
  #
  # @return [String] rewritten code.
  def new_code
    rewritten_source
  end

  private

  # Calculate the begin and end positions.
  def calculate_position
    @start =
      if @at == 'end'
        if @to
          NodeMutation.adapter.child_node_range(@node, @to).end
        else
          NodeMutation.adapter.get_end(@node)
        end
      else
        if @to
          NodeMutation.adapter.child_node_range(@node, @to).start
        else
          NodeMutation.adapter.get_start(@node)
        end
      end
    @end = @start
  end
end
