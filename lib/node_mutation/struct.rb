# frozen_string_literal: true

class NodeMutation::Struct
  Action = Struct.new(:type, :start, :end, :new_code, :actions)
  Location = Struct.new(:line, :column)
  Range = Struct.new(:start, :end)
end
