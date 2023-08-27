# frozen_string_literal: true

class NodeMutation::Helper
  # It iterates over all actions, and calls the given block with each action.
  def self.iterate_actions(actions, &block)
    actions.each do |action|
      if action.is_a?(NodeMutation::CombinedAction)
        iterate_actions(action.actions, &block)
      else
        block.call(action)
      end
    end
  end
end