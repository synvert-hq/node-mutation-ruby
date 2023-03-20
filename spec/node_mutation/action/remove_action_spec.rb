# frozen_string_literal: true

require 'spec_helper'

RSpec.describe NodeMutation::RemoveAction do
  context 'leading and_comma' do
    subject {
      source = 'foobar(foo, bar)'
      node = Parser::CurrentRuby.parse(source).arguments[1]
      NodeMutation::RemoveAction.new(node, and_comma: true).process
    }

    it 'gets start' do
      expect(subject.start).to eq 'foobar(foo'.length
    end

    it 'gets end' do
      expect(subject.end).to eq 'foobar(foo, bar'.length
    end

    it 'gets new_code' do
      expect(subject.new_code).to eq ''
    end
  end

  context 'trailing and_comma' do
    subject {
      source = 'foobar(foo, bar)'
      node = Parser::CurrentRuby.parse(source).arguments[0]
      NodeMutation::RemoveAction.new(node, and_comma: true).process
    }

    it 'gets start' do
      expect(subject.start).to eq 'foobar('.length
    end

    it 'gets end' do
      expect(subject.end).to eq 'foobar(foo, '.length
    end

    it 'gets new_code' do
      expect(subject.new_code).to eq ''
    end
  end

  context 'whole line' do
    subject {
      source = <<~EOS
        user = User.new params[:user]
        user.save
        render
      EOS
      node = Parser::CurrentRuby.parse(source).children[1]
      NodeMutation::RemoveAction.new(node).process
    }

    it 'gets start' do
      expect(subject.start).to eq "user = User.new params[:user]\n".length
    end

    it 'gets end' do
      expect(subject.end).to eq "user = User.new params[:user]\nuser.save\n".length
    end

    it 'gets new_code' do
      expect(subject.new_code).to eq ''
    end

    context 'leading and_comma' do
      subject {
        source = <<~EOS
          object = {
            foo: 1,
            bar: 2
          }
        EOS
        node = Parser::CurrentRuby.parse(source).children[1].children[1]
        NodeMutation::RemoveAction.new(node, and_comma: true).process
      }

      it 'gets start' do
        expect(subject.start).to eq "object = {\n  foo: 1".length
      end

      it 'gets end' do
        expect(subject.end).to eq "object = {\n  foo: 1,\n  bar: 2".length
      end

      it 'gets new_code' do
        expect(subject.new_code).to eq ''
      end
    end

    context 'trailing and_comma' do
      subject {
        source = <<~EOS
          object = {
            foo: 1,
            bar: 2
          }
        EOS
        node = Parser::CurrentRuby.parse(source).children[1].children[0]
        NodeMutation::RemoveAction.new(node, and_comma: true).process
      }

      it 'gets start' do
        expect(subject.start).to eq "object = {\n  ".length
      end

      it 'gets end' do
        expect(subject.end).to eq "object = {\n  foo: 1,\n".length
      end

      it 'gets new_code' do
        expect(subject.new_code).to eq ''
      end
    end
  end
end
