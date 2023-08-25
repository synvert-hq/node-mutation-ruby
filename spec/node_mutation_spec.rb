# frozen_string_literal: true

RSpec.describe NodeMutation do
  describe '#configure' do
    it 'sets tab_width' do
      expect(described_class.tab_width).to eq 2
      described_class.configure(tab_width: 4)
      expect(described_class.tab_width).to eq 4
    end
  end

  describe '#process' do
    let(:source) { <<~EOS }
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
      mutation.actions.push(NodeMutation::Struct::Action.new(:insert, 0, 0, "# frozen_string_literal: true\n"))
      mutation.actions.push(
        NodeMutation::Struct::Action.new(
          :replace,
          "class ".length,
          "class Foobar".length,
          "Synvert"
        )
      )
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
      mutation.actions.push(
        NodeMutation::Struct::Action.new(
          :replace,
          "class ".length,
          "class Foobar".length,
          "Synvert"
        )
      )
      mutation.actions.push(
        NodeMutation::Struct::Action.new(
          :insert,
          "class Foobar".length,
          "class Foobar".length,
          " < Base"
        )
      )
      mutation.actions.push(NodeMutation::Struct::Action.new(:replace, 0, "class Foobar".length, "class Foobar < Base"))
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
      mutation.actions.push(
        NodeMutation::Struct::Action.new(
          :replace,
          "class ".length,
          "class Foobar".length,
          "Synvert"
        )
      )
      mutation.actions.push(
        NodeMutation::Struct::Action.new(
          :insert,
          "class Foobar".length,
          "class Foobar".length,
          " < Base"
        )
      )
      mutation.actions.push(NodeMutation::Struct::Action.new(:replace, 0, "class Foobar".length, "class Foobar < Base"))
      expect { mutation.process }
        .to raise_error(NodeMutation::ConflictActionError)
    end

    it 'gets no conflict when insert at the same position' do
      described_class.configure(strategy: NodeMutation::Strategy::KEEP_RUNNING)
      action1 = NodeMutation::Struct::Action.new(:insert, "class Foobar".length, "class Foobar".length, " < Base")
      action2 = NodeMutation::Struct::Action.new(:insert, "class Foobar".length, "class Foobar".length, " < Base")
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

    context '#transform_proc' do
      let(:source) { <<~EOS }
        if current_user
          current_user.login
        if current_user
          current_user.name
      EOS
      let(:encoded_source) { <<~EOS }
        if current_user
          current_user.login
        end
        if current_user
          current_user.name
        end
      EOS

      it 'transforms the new source' do
        mutation.transform_proc =
          proc do |actions|
            start = 0
            indices = []
            loop do
              index = encoded_source[start..-1].index("end\n")
              break unless index

              indices << (start + index)
              start += index + "end\n".length
            end
            indices.each do |index|
              actions.each do |action|
                action.start -= "end\n".length if action.start > index
                action.end -= "end\n".length if action.end > index
              end
            end
          end
        mutation.actions.push(
          NodeMutation::Struct::Action.new(
            :replace,
            "if current_user\n  ".length,
            "if current_user\n  current_user.login".length,
            "current_user.username"
          )
        )
        mutation.actions.push(
          NodeMutation::Struct::Action.new(
            :replace,
            "if current_user\n  current_user.login\nend\nif_current_user\n  ".length,
            "if current_user\n  current_user.login\nend\nif_current_user\n  current_user.name".length,
            "current_user.username"
          )
        )
        result = mutation.process
        expect(result).to be_affected
        expect(result).not_to be_conflicted
        expect(result.new_source).to eq <<~EOS
          if current_user
            current_user.username
          if current_user
            current_user.username
        EOS
      end
    end
  end

  describe '#test' do
    let(:source) { <<~EOS }
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
      action1 = NodeMutation::Struct::Action.new(:insert, 0, 0, "# frozen_string_literal: true\n")
      action2 = NodeMutation::Struct::Action.new(:replace, "class ".length, "class Foobar".length, "Synvert")
      mutation.actions.push(action1)
      mutation.actions.push(action2)
      result = mutation.test
      expect(result).to be_affected
      expect(result).not_to be_conflicted
      expect(result.actions).to eq [action1, action2]
    end

    it 'gets conflict with KEEP_RUNNING strategy' do
      described_class.configure(strategy: NodeMutation::Strategy::KEEP_RUNNING)
      action1 = NodeMutation::Struct::Action.new(:replace, "class ".length, "class Foobar".length, "Synvert")
      action2 = NodeMutation::Struct::Action.new(:insert, "class Foobar".length, "class Foobar".length, " < Base")
      action3 = NodeMutation::Struct::Action.new(:replace, 0, "class Foobar".length, "class Foobar < Base")
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
      mutation.actions.push(
        NodeMutation::Struct::Action.new(
          :replace,
          "class ".length,
          "class Foobar".length,
          "Synvert"
        )
      )
      mutation.actions.push(
        NodeMutation::Struct::Action.new(
          :insert,
          "class Foobar".length,
          "class Foobar".length,
          " < Base"
        )
      )
      mutation.actions.push(NodeMutation::Struct::Action.new(:replace, 0, "class Foobar".length, "class Foobar < Base"))
      expect {
        mutation.process
      }.to raise_error(NodeMutation::ConflictActionError)
    end

    context '#transform_proc' do
      let(:source) { <<~EOS }
        if current_user
          current_user.login
        if current_user
          current_user.name
      EOS
      let(:encoded_source) { <<~EOS }
        if current_user
          current_user.login
        end
        if current_user
          current_user.name
        end
      EOS

      it 'transforms the actions' do
        mutation.transform_proc =
          proc do |actions|
            start = 0
            indices = []
            loop do
              index = encoded_source[start..-1].index("end\n")
              break unless index

              indices << (start + index)
              start += index + "end\n".length
            end
            indices.each do |index|
              actions.each do |action|
                action.start -= "end\n".length if action.start > index
                action.end -= "end\n".length if action.end > index
              end
            end
          end
        action1 = NodeMutation::Struct::Action.new(
          :replace,
          "if current_user\n  ".length,
          "if current_user\n  current_user.login".length,
          "current_user.username"
        )
        action2 = NodeMutation::Struct::Action.new(
          :replace,
          "if current_user\n  current_user.login\nend\nif_current_user\n  ".length,
          "if current_user\n  current_user.login\nend\nif_current_user\n  current_user.name".length,
          "current_user.username"
        )
        new_action2 = NodeMutation::Struct::Action.new(
          :replace,
          "if current_user\n  current_user.login\nif_current_user\n  ".length,
          "if current_user\n  current_user.login\nif_current_user\n  current_user.name".length,
          "current_user.username"
        )
        mutation.actions.push(action1)
        mutation.actions.push(action2)
        result = mutation.test
        expect(result).to be_affected
        expect(result).not_to be_conflicted
        expect(result.actions).to eq [action1, new_action2]
      end
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
        to: 'receiver',
        and_comma: false
      ).and_return(action)
      expect(action).to receive(:process)
      mutation.insert node, '.first', to: 'receiver'
    end

    it 'parses insert at beginning' do
      expect(NodeMutation::InsertAction).to receive(:new).with(
        node,
        'URI.',
        at: 'beginning',
        to: nil,
        and_comma: false
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

    context '#wrap' do
      it 'parses without newline' do
        node = parse('robot.process')
        mutation.wrap node, prefix: '3.times { ', suffix: ' }'
        combined_action = mutation.actions.first
        expect(combined_action.type).to eq :combined
        expect(combined_action.actions.size).to eq 2
        expect(combined_action.actions[0].start).to eq 0
        expect(combined_action.actions[0].end).to eq 0
        expect(combined_action.actions[0].new_code).to eq '3.times { '
        expect(combined_action.actions[1].start).to eq 'robot.process'.length
        expect(combined_action.actions[1].end).to eq 'robot.process'.length
        expect(combined_action.actions[1].new_code).to eq ' }'
      end

      it 'parses with newline' do
        node = parse("class Bar\nend")
        mutation.wrap node, prefix: 'module Foo', suffix: 'end', newline: true
        combined_action = mutation.actions.first
        expect(combined_action.type).to eq :combined
        expect(combined_action.actions.size).to eq 3
        expect(combined_action.actions[0].start).to eq 0
        expect(combined_action.actions[0].end).to eq 0
        expect(combined_action.actions[0].new_code).to eq "module Foo\n"
        expect(combined_action.actions[1].start).to eq "class Bar\nend".length
        expect(combined_action.actions[1].end).to eq "class Bar\nend".length
        expect(combined_action.actions[1].new_code).to eq "\nend"
        expect(combined_action.actions[2].start).to eq 0
        expect(combined_action.actions[2].end).to eq "class Bar\nend".length
        expect(combined_action.actions[2].new_code).to eq "  class Bar\n  end"
      end
    end

    it 'parses combine' do
      node = parse("class Bar\nend")
      mutation.combine do |actions|
        actions << NodeMutation::InsertAction.new(node, "module Foo\n", at: 'beginning').process
        actions << NodeMutation::InsertAction.new(node, "\nend", at: 'end').process
      end
      combined_action = mutation.actions.first
      expect(combined_action.type).to eq :combined
      expect(combined_action.actions.size).to eq 2
      expect(combined_action.actions[0].start).to eq 0
      expect(combined_action.actions[0].end).to eq 0
      expect(combined_action.actions[0].new_code).to eq "module Foo\n"
      expect(combined_action.actions[1].start).to eq "class Bar\nend".length
      expect(combined_action.actions[1].end).to eq "class Bar\nend".length
      expect(combined_action.actions[1].new_code).to eq "\nend"
    end

    it 'parses noop' do
      expect(NodeMutation::NoopAction).to receive(:new).with(node).and_return(action)
      expect(action).to receive(:process)
      mutation.noop node
    end
  end
end
