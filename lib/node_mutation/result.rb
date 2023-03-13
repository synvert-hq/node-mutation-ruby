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
      if key == :actions
        hash[:actions] = value.map { |action| { start: action.start, end: action.end, new_code: action.new_code } }
      else
        hash[key] = value
      end
    end
    hash
  end
end
