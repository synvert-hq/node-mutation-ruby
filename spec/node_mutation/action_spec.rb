# frozen_string_literal: true

RSpec.describe NodeMutation::Action do
  let(:action) { NodeMutation::Action.new(nil, nil) }

  describe '#remove_whitespace' do
    it 'removes whitespace after comma' do
      action.instance_variable_set(:@file_source, 'test(foo, bar)')
      action.instance_variable_set(:@start, 'test('.length)
      action.instance_variable_set(:@end, 'test(foo,'.length)
      action.send(:remove_whitespace)
      expect(action.start).to eq 'test('.length
      expect(action.end).to eq 'test(foo, '.length
    end

    it 'removes whitespace after first element of array []' do
      action.instance_variable_set(:@file_source, '%i[foo bar]')
      action.instance_variable_set(:@start, '%i['.length)
      action.instance_variable_set(:@end, '%i[foo'.length)
      action.send(:remove_whitespace)
      expect(action.start).to eq '%i['.length
      expect(action.end).to eq '%i[foo '.length
    end

    it 'removes whitespace after first element of array ||' do
      action.instance_variable_set(:@file_source, '%i|foo bar|')
      action.instance_variable_set(:@start, '%i|'.length)
      action.instance_variable_set(:@end, '%i|foo'.length)
      action.send(:remove_whitespace)
      expect(action.start).to eq '%i|'.length
      expect(action.end).to eq '%i|foo '.length
    end

    it 'removes whitespace after first element of array {}' do
      action.instance_variable_set(:@file_source, '%i{foo bar}')
      action.instance_variable_set(:@start, '%i{'.length)
      action.instance_variable_set(:@end, '%i{foo'.length)
      action.send(:remove_whitespace)
      expect(action.start).to eq '%i{'.length
      expect(action.end).to eq '%i{foo '.length
    end

    it 'removes whitespace after first element of array ()' do
      action.instance_variable_set(:@file_source, '%i(foo bar}')
      action.instance_variable_set(:@start, '%i('.length)
      action.instance_variable_set(:@end, '%i(foo'.length)
      action.send(:remove_whitespace)
      expect(action.start).to eq '%i('.length
      expect(action.end).to eq '%i(foo '.length
    end

    it 'removes whitespace before pipes' do
      action.instance_variable_set(:@file_source, 'test do |foo, bar|; end')
      action.instance_variable_set(:@start, 'test do '.length)
      action.instance_variable_set(:@end, 'test do |foo, bar|'.length)
      action.send(:remove_whitespace)
      expect(action.start).to eq 'test do'.length
      expect(action.end).to eq 'test do |foo, bar|'.length
    end

    it 'removes whitespace before arguments' do
      action.instance_variable_set(:@file_source, 'test foo, bar')
      action.instance_variable_set(:@start, 'test '.length)
      action.instance_variable_set(:@end, 'test foo, bar'.length)
      action.send(:remove_whitespace)
      expect(action.start).to eq 'test'.length
      expect(action.end).to eq 'test foo, bar'.length
    end

    it 'removes whitespace before last element of array []' do
      action.instance_variable_set(:@file_source, '%i[foo bar]')
      action.instance_variable_set(:@start, '%i[foo '.length)
      action.instance_variable_set(:@end, '%i[foo bar'.length)
      action.send(:remove_whitespace)
      expect(action.start).to eq '%i[foo'.length
      expect(action.end).to eq '%i[foo bar'.length
    end

    it 'removes whitespace before last element of array ||' do
      action.instance_variable_set(:@file_source, '%i|foo bar|')
      action.instance_variable_set(:@start, '%i|foo '.length)
      action.instance_variable_set(:@end, '%i|foo bar'.length)
      action.send(:remove_whitespace)
      expect(action.start).to eq '%i|foo'.length
      expect(action.end).to eq '%i|foo bar'.length
    end

    it 'removes whitespace before last element of array {}' do
      action.instance_variable_set(:@file_source, '%i{foo bar}')
      action.instance_variable_set(:@start, '%i{foo '.length)
      action.instance_variable_set(:@end, '%i{foo bar'.length)
      action.send(:remove_whitespace)
      expect(action.start).to eq '%i{foo'.length
      expect(action.end).to eq '%i{foo bar'.length
    end

    it 'removes whitespace before last element of array ()' do
      action.instance_variable_set(:@file_source, '%i(foo bar}')
      action.instance_variable_set(:@start, '%i(foo '.length)
      action.instance_variable_set(:@end, '%i(foo bar'.length)
      action.send(:remove_whitespace)
      expect(action.start).to eq '%i(foo'.length
      expect(action.end).to eq '%i(foo bar'.length
    end
  end

  describe '#remove_comma' do
    it 'removes comma after' do
      action.instance_variable_set(:@file_source, 'test(foo, bar)')
      action.instance_variable_set(:@start, 'test('.length)
      action.instance_variable_set(:@end, 'test(foo'.length)
      action.send(:remove_comma)
      expect(action.start).to eq 'test('.length
      expect(action.end).to eq 'test(foo,'.length
    end

    it 'removes comma before' do
      action.instance_variable_set(:@file_source, 'test(foo, bar)')
      action.instance_variable_set(:@start, 'test(foo, '.length)
      action.instance_variable_set(:@end, 'test(foo, bar'.length)
      action.send(:remove_comma)
      expect(action.start).to eq 'test(foo'.length
      expect(action.end).to eq 'test(foo, bar'.length
    end

    it 'removes comma before a newline' do
      action.instance_variable_set(:@file_source, <<~EOS)
        test(
          foo: foo,
          bar: bar
        )
      EOS
      action.instance_variable_set(:@start, <<~EOS.strip.length)
        test(
          foo: foo,

      EOS
      action.instance_variable_set(:@end, <<~EOS.strip.length)
        test(
          foo: foo,
          bar: bar
      EOS
      action.send(:remove_comma)
      expect(action.start).to eq <<~EOS.strip.length
        test(
          foo: foo
      EOS
      expect(action.end).to eq <<~EOS.strip.length
        test(
          foo: foo,
          bar: bar
      EOS
    end
  end
end
