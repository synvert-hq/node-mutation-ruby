# frozen_string_literal: true

# GroupAction is compose of multiple actions.
class NodeMutation::GroupAction < NodeMutation::Action
  DEFAULT_START = 2**30

  # Initialize a GroupAction.
  def initialize
    @actions = []
    @type = :group
  end

  def new_code
    nil
  end

  private

  # Calculate the begin and end positions.
  def calculate_position
    @start = DEFAULT_START
    @end = 0
    NodeMutation::Helper.iterate_actions(@actions) do |action|
      @start = [action.start, @start].min
      @end = [action.end, @end].max
    end
  end
end
