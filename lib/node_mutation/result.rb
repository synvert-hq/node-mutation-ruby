# frozen_string_literal: true

class NodeMutation::Result
  attr_accessor :file_path, :new_source, :actions
  attr_reader :actions

  def initialize(affected:, conflicted:)
    @affected = affected
    @conflicted = conflicted
    @actions = []
  end

  def affected?
    @affected
  end

  def conflicted?
    @conflicted
  end

  def to_json(*args)
    data = { affected: affected?, conflicted: conflicted? }
    data[:new_source] = new_source if new_source
    data[:actions] = actions unless actions.empty?
    data.to_json(*args)
  end
end
