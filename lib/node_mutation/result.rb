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

  def actions
    @options[:actions]
  end

  def new_source
    @options[:new_source]
  end

  def to_hash
    @options.each_pair.with_object({}) do |(key, value), hash|
      hash[key] = value.is_a?(Array) ? value.map { |action| action.to_h } : value
    end
  end
end