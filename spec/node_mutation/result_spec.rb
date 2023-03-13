# frozen_string_literal: true

require 'spec_helper'
require 'json'

RSpec.describe NodeMutation::Result do
  describe '#to_json' do
    it 'returns a json' do
      result = NodeMutation::Result.new(
        affected: false,
        conflicted: false
      )
      result.file_path = 'code.rb'
      expect(result.to_json).to eq({
        file_path: 'code.rb',
        affected: false,
        conflicted: false
      }.to_json)
    end

    it 'returns a json with actions' do
      result = NodeMutation::Result.new(
        affected: true,
        conflicted: false,
        actions: [
          NodeMutation::ActionResult.new("class ".length, "class Foobar".length, "Synvert"),
          NodeMutation::ActionResult.new("class Foobar".length, "class Foobar".length, " < Base")
        ]
      )
      result.file_path = 'code.rb'
      expect(result.to_json).to eq({
        file_path: 'code.rb',
        affected: true,
        conflicted: false,
        actions: [
          { start: 6, end: 12, new_code: 'Synvert' },
          { start: 12, end: 12, new_code: " < Base" }
        ]
      }.to_json)
    end
  end
end