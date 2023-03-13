# frozen_string_literal: true

class NodeMutation::Result
  attr_accessor :file_path

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

  def to_json(*args)
    to_hash.to_json(*args)
  end

  def to_hash
    hash = { file_path: file_path }
    @options.each do |key, value|
      hash[key] = value.is_a?(Array) ? value.map { |action| action.to_h } : value
    end
    hash
  end
end
