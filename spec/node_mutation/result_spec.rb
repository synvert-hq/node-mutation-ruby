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
          OpenStruct.new(
            start: "class ".length,
            end: "class Foobar".length,
            new_code: "Synvert"
          ).marshal_dump,
          OpenStruct.new(
            start: "class Foobar".length,
            end: "class Foobar".length,
            new_code: " < Base"
          ).marshal_dump
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