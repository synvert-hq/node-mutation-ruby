# frozen_string_literal: true

require 'spec_helper'

RSpec.describe NodeMutation::Result do
  describe '#to_hash' do
    it 'returns a hash' do
      result = NodeMutation::Result.new(
        affected: false,
        conflicted: false
      )
      result.file_path = 'code.rb'
      expect(result.to_hash).to eq(
        file_path: 'code.rb',
        affected: false,
        conflicted: false
      )
    end

    it 'returns a hash with actions' do
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
      expect(result.to_hash).to eq(
        file_path: 'code.rb',
        affected: true,
        conflicted: false,
        actions: [
          { end: 12, new_code: 'Synvert', start: 6 },
          { end: 12, new_code: " < Base", start: 12 }
        ]
      )
    end
  end
end