# frozen_string_literal: true

class NodeMutation::Result
  def initialize(options)
    @options = options
  end

  def affected?
    @options[:affected]
  end

  def conflicted?
    @options[:conflicted]
  end

  def new_source
    @options[:new_source]
  end
end