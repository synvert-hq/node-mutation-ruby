# frozen_string_literal: true

# GroupAction is compose of multiple actions.
class NodeMutation::GroupAction < NodeMutation::Action
  include NodeMutation::Actionable

  DEFAULT_START = 2**30

  # Initialize a GroupAction.
  def initialize(adapter:, &block)
    @actions = []
    @type = :group
    @adapter = adapter
    @block = block
  end

  def new_code
    nil
  end

  def process
    instance_eval(&@block)
    super
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
