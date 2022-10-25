# frozen_string_literal: true

RSpec.describe NodeMutation do
  describe '#process' do
    let(:source) {<<~EOS}
      class Foobar
        def foo; end
        def bar; end
      end
    EOS
    let(:mutation) { described_class.new(source) }

    it 'gets no action' do
      result = mutation.process
      expect(result).not_to be_affected
      expect(result).not_to be_conflicted
    end

    it 'gets no conflict' do
      mutation.actions.push(OpenStruct.new(
        start: 0,
        end: 0,
        new_code: "# frozen_string_literal: true\n"
      ))
      mutation.actions.push(OpenStruct.new(
        start: "class ".length,
        end: "class Foobar".length,
        new_code: "Synvert"
      ))
      result = mutation.process
      expect(result).to be_affected
      expect(result).not_to be_conflicted
      expect(result.new_source).to eq <<~EOS
        # frozen_string_literal: true
        class Synvert
          def foo; end
          def bar; end
        end
      EOS
    end

    it 'gets conflict with KEEP_RUNNING strategy' do
      described_class.configure(strategy: NodeMutation::Strategy::KEEP_RUNNING)
      mutation.actions.push(OpenStruct.new(
        start: "class ".length,
        end: "class Foobar".length,
        new_code: "Synvert"
      ))
      mutation.actions.push(OpenStruct.new(
        start: "class Foobar".length,
        end: "class Foobar".length,
        new_code: " < Base"
      ))
      mutation.actions.push(OpenStruct.new(
        start: 0,
        end: "class Foobar".length,
        new_code: "class Foobar < Base"
      ))
      result = mutation.process
      expect(result).to be_affected
      expect(result).to be_conflicted
      expect(result.new_source).to eq <<~EOS
        class Synvert < Base
          def foo; end
          def bar; end
        end
      EOS
    end

    it 'gets conflict with THROW_ERROR strategy' do
      described_class.configure(strategy: NodeMutation::Strategy::THROW_ERROR)
      mutation.actions.push(OpenStruct.new(
        start: "class ".length,
        end: "class Foobar".length,
        new_code: "Synvert"
      ))
      mutation.actions.push(OpenStruct.new(
        start: "class Foobar".length,
        end: "class Foobar".length,
        new_code: " < Base"
      ))
      mutation.actions.push(OpenStruct.new(
        start: 0,
        end: "class Foobar".length,
        new_code: "class Foobar < Base"
      ))
      expect {
        mutation.process
      }.to raise_error(NodeMutation::ConflictActionError)
    end

    it 'gets conflict when insert at the same position' do
      described_class.configure(strategy: NodeMutation::Strategy::KEEP_RUNNING)
      action1 = OpenStruct.new(
        start: "class Foobar".length,
        end: "class Foobar".length,
        new_code: " < Base"
      )
      action2 = OpenStruct.new(
        start: "class Foobar".length,
        end: "class Foobar".length,
        new_code: " < Base"
      )
      mutation.actions.push(action1)
      mutation.actions.push(action2)
      result = mutation.process
      expect(result).to be_affected
      expect(result).to be_conflicted
      expect(result.new_source).to eq <<~EOS
        class Foobar < Base
          def foo; end
          def bar; end
        end
      EOS
    end

    it 'gets no conflict with ALLOW_INSERT_AT_SAME_POSITION strategy' do
      described_class.configure(strategy: NodeMutation::Strategy::KEEP_RUNNING | NodeMutation::Strategy::ALLOW_INSERT_AT_SAME_POSITION)
      action1 = OpenStruct.new(
        start: "class Foobar".length,
        end: "class Foobar".length,
        new_code: " < Base"
      )
      action2 = OpenStruct.new(
        start: "class Foobar".length,
        end: "class Foobar".length,
        new_code: " < Base"
      )
      mutation.actions.push(action1)
      mutation.actions.push(action2)
      result = mutation.process
      expect(result).to be_affected
      expect(result).not_to be_conflicted
      expect(result.new_source).to eq <<~EOS
        class Foobar < Base < Base
          def foo; end
          def bar; end
        end
      EOS
    end
  end

  describe '#test' do
    let(:source) {<<~EOS}
      class Foobar
        def foo; end
        def bar; end
      end
    EOS
    let(:mutation) { described_class.new(source) }

    it 'gets no action' do
      result = mutation.test
      expect(result).not_to be_affected
      expect(result).not_to be_conflicted
    end

    it 'gets no conflict' do
      action1 = OpenStruct.new(
        start: 0,
        end: 0,
        new_code: "# frozen_string_literal: true\n"
      )
      action2 = OpenStruct.new(
        start: "class ".length,
        end: "class Foobar".length,
        new_code: "Synvert"
      )
      mutation.actions.push(action1)
      mutation.actions.push(action2)
      result = mutation.test
      expect(result).to be_affected
      expect(result).not_to be_conflicted
      expect(result.actions).to eq [action1, action2]
    end

    it 'gets conflict with KEEP_RUNNING strategy' do
      described_class.configure(strategy: NodeMutation::Strategy::KEEP_RUNNING)
      action1 = OpenStruct.new(
        start: "class ".length,
        end: "class Foobar".length,
        new_code: "Synvert"
      )
      action2 = OpenStruct.new(
        start: "class Foobar".length,
        end: "class Foobar".length,
        new_code: " < Base"
      )
      action3 = OpenStruct.new(
        start: 0,
        end: "class Foobar".length,
        new_code: "class Foobar < Base"
      )
      mutation.actions.push(action1)
      mutation.actions.push(action2)
      mutation.actions.push(action3)
      result = mutation.test
      expect(result).to be_affected
      expect(result).to be_conflicted
      expect(result.actions).to eq [action1, action2]
    end

    it 'gets conflict with THROW_ERROR strategy' do
      described_class.configure(strategy: NodeMutation::Strategy::THROW_ERROR)
      mutation.actions.push(OpenStruct.new(
        start: "class ".length,
        end: "class Foobar".length,
        new_code: "Synvert"
      ))
      mutation.actions.push(OpenStruct.new(
        start: "class Foobar".length,
        end: "class Foobar".length,
        new_code: " < Base"
      ))
      mutation.actions.push(OpenStruct.new(
        start: 0,
        end: "class Foobar".length,
        new_code: "class Foobar < Base"
      ))
      expect {
        mutation.process
      }.to raise_error(NodeMutation::ConflictActionError)
    end
  end

  describe 'apis' do
    let(:mutation) { described_class.new('code.rb') }
    let(:node) { '' }
    let(:action) { double }

    it 'parses append' do
      expect(NodeMutation::AppendAction).to receive(:new).with(
        node,
        'include FactoryGirl::Syntax::Methods'
      ).and_return(action)
      expect(action).to receive(:process)
      mutation.append node, 'include FactoryGirl::Syntax::Methods'
    end

    it 'parses prepend' do
      expect(NodeMutation::PrependAction).to receive(:new).with(
        node,
        '{{arguments.first}}.include FactoryGirl::Syntax::Methods'
      ).and_return(action)
      expect(action).to receive(:process)
      mutation.prepend node, '{{arguments.first}}.include FactoryGirl::Syntax::Methods'
    end

    it 'parses insert at end' do
      expect(NodeMutation::InsertAction).to receive(:new).with(
        node,
        '.first',
        at: 'end',
        to: 'receiver'
      ).and_return(action)
      expect(action).to receive(:process)
      mutation.insert node, '.first', to: 'receiver'
    end

    it 'parses insert at beginning' do
      expect(NodeMutation::InsertAction).to receive(:new).with(
        node,
        'URI.',
        at: 'beginning',
        to: nil
      ).and_return(action)
      expect(action).to receive(:process)
      mutation.insert node, 'URI.', at: 'beginning'
    end

    it 'parses replace_with' do
      expect(NodeMutation::ReplaceWithAction).to receive(:new).with(node, 'create {{arguments}}').and_return(action)
      expect(action).to receive(:process)
      mutation.replace_with node, 'create {{arguments}}'
    end

    it 'parses replace with' do
      expect(NodeMutation::ReplaceAction).to receive(:new).with(node, :message, with: 'test').and_return(action)
      expect(action).to receive(:process)
      mutation.replace node, :message, with: 'test'
    end

    it 'parses remove' do
      expect(NodeMutation::RemoveAction).to receive(:new).with(node, { and_comma: true }).and_return(action)
      expect(action).to receive(:process)
      mutation.remove node, and_comma: true
    end

    it 'parses delete' do
      expect(NodeMutation::DeleteAction).to receive(:new).with(
        node,
        :dot,
        :message,
        { and_comma: true }
      ).and_return(action)
      expect(action).to receive(:process)
      mutation.delete node, :dot, :message, and_comma: true
    end

    it 'parses wrap with' do
      expect(NodeMutation::WrapAction).to receive(:new).with(node, with: 'module Foo').and_return(action)
      expect(action).to receive(:process)
      mutation.wrap node, with: 'module Foo'
    end

    it 'parses noop' do
      expect(NodeMutation::NoopAction).to receive(:new).with(node).and_return(action)
      expect(action).to receive(:process)
      mutation.noop node
    end
  end
end
