# frozen_string_literal: true

class NodeMutation::Strategy
  KEEP_RUNNING = 0b1
  THROW_ERROR = 0b10
  ALLOW_INSERT_AT_SAME_POSITION = 0b100
end
