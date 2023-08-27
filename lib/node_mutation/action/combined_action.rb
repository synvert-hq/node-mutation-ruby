# frozen_string_literal: true

class NodeMutation::CombinedAction < NodeMutation::Action
  DEFAULT_START = 2**30

  attr_reader :actions

  def initialize
    @actions = []
    @type = :combined
  end

  def new_code
    ''
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
