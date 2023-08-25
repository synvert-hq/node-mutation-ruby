# frozen_string_literal: true

class NodeMutation::CombinedAction < NodeMutation::Action
  attr_reader :actions

  def initialize
    @actions = []
    @type = :combined
  end

  private

  # Calculate the begin and end positions.
  def calculate_position
    @start = @actions.map(&:start).min
    @end = @actions.map(&:end).max
  end
end