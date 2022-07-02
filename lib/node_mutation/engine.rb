# frozen_string_literal: true

module NodeMutation::Engine
  # Engine defines how to encode / decode other files (like erb).
  autoload :Erb, 'node_mutation/engine/erb'
end
