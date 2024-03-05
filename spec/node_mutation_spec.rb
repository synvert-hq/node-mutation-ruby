# frozen_string_literal: true

RSpec.describe NodeMutation do
  describe '#configure' do
    it 'sets tab_width' do
      expect(described_class.tab_width).to eq 2
      described_class.configure(tab_width: 4)
      expect(described_class.tab_width).to eq 4
      described_class.configure(tab_width: 2)
      expect(described_class.tab_width).to eq 2
    end
  end

  it 'initializes with invalid adapter' do
    expect {
      NodeMutation.new('code.rb', adapter: 'invalid')
    }.to raise_error(NodeMutation::InvalidAdapterError)
  end

  describe '#process' do
    let(:source) { <<~EOS }
      class Foobar
        def foo; end
        def bar; end
      end
    EOS
    let(:mutation) { described_class.new(source, adapter: :parser) }
    let(:node) { parser_parse(source) }

    it 'gets no action' do
      result = mutation.process
      expect(result).not_to be_affected
      expect(result).not_to be_conflicted
    end

    it 'gets no conflict' do
      mutation.insert(node, "# frozen_string_literal: true\n", at: 'beginning')
      mutation.replace(node, :name, with: 'Synvert')
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
      mutation.replace(node, :name, with: 'Synvert < Base')
      mutation.replace(node, :name, with: 'Synvert')
      mutation.insert(node, ' < Base', to: 'name')
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
      mutation.replace(node, :name, with: 'Synvert < Base')
      mutation.replace(node, :name, with: 'Synvert')
      mutation.insert(node, ' < Base', to: 'name')
      expect { mutation.process }
        .to raise_error(NodeMutation::ConflictActionError)
    end

    it 'gets no conflict when insert at the same position' do
      described_class.configure(strategy: NodeMutation::Strategy::KEEP_RUNNING)
      mutation.insert(node, ' < Base', to: 'name')
      mutation.insert(node, ' < Base', to: 'name')
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

    it 'processes with group actions' do
      described_class.configure(strategy: NodeMutation::Strategy::KEEP_RUNNING)
      source = "User.find_by_account_id(Account.find_by_email(account_email).id)"
      node = parser_parse(source)
      mutation = described_class.new(source, adapter: :parser)
      mutation.group do
        mutation.replace node, :message, with: 'find_by'
        mutation.replace node, :arguments, with: 'account_id: {{arguments}}'
      end
      mutation.group do
        mutation.replace node.arguments.first.receiver, :message, with: 'find_by'
        mutation.replace node.arguments.first.receiver, :arguments, with: 'email: {{arguments}}'
      end
      result = mutation.process
      expect(result).to be_affected
      expect(result).to be_conflicted
      expect(result.new_source).to eq 'User.find_by_account_id(Account.find_by(email: account_email).id)'
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
    let(:adapter) { NodeMutation::ParserAdapter.new }
    let(:mutation) { described_class.new(source, adapter: :parser) }
    let(:node) { parser_parse(source) }

    it 'gets no action' do
      result = mutation.test
      expect(result).not_to be_affected
      expect(result).not_to be_conflicted
    end

    it 'gets no conflict' do
      mutation.insert(node, "# frozen_string_literal: true\n", at: 'beginning')
      mutation.replace(node, :name, with: 'Synvert')
      result = mutation.test
      expect(result).to be_affected
      expect(result).not_to be_conflicted
      expect(result.actions).to eq [
        NodeMutation::Struct::Action.new(:insert, 0, 0, "# frozen_string_literal: true\n"),
        NodeMutation::Struct::Action.new(:replace, 'class '.length, 'class Foobar'.length, 'Synvert')
      ]
    end

    it 'gets conflict with KEEP_RUNNING strategy' do
      described_class.configure(strategy: NodeMutation::Strategy::KEEP_RUNNING)
      mutation.replace(node, :name, with: 'Synvert < Base')
      mutation.replace(node, :name, with: 'Synvert')
      mutation.insert(node, ' < Base', to: 'name')
      result = mutation.test
      expect(result).to be_affected
      expect(result).to be_conflicted
      expect(result.actions).to eq [
        NodeMutation::Struct::Action.new(:replace, 'class '.length, 'class Foobar'.length, 'Synvert'),
        NodeMutation::Struct::Action.new(:insert, 'class Foobar'.length, 'class Foobar'.length, ' < Base')
      ]
    end

    it 'gets conflict with THROW_ERROR strategy' do
      described_class.configure(strategy: NodeMutation::Strategy::THROW_ERROR)
      mutation.replace(node, :name, with: 'Synvert < Base')
      mutation.replace(node, :name, with: 'Synvert')
      mutation.insert(node, ' < Base', to: 'name')
      expect {
        mutation.process
      }.to raise_error(NodeMutation::ConflictActionError)
    end

    context 'group action' do
      it 'tests with group actions' do
        described_class.configure(strategy: NodeMutation::Strategy::KEEP_RUNNING)
        source = "User.find_by_account_id(Account.find_by_email(account_email).id)"
        node = parser_parse(source)
        mutation = described_class.new(source, adapter: :parser)
        mutation.group do
          mutation.replace node, :message, with: 'find_by'
          mutation.replace node, :arguments, with: 'account_id: {{arguments}}'
        end
        mutation.group do
          mutation.replace node.arguments.first.receiver, :message, with: 'find_by'
          mutation.replace node.arguments.first.receiver, :arguments, with: 'email: {{arguments}}'
        end
        result = mutation.test
        expect(result).to be_affected
        expect(result).to be_conflicted
        expect(result.actions).to eq [
          NodeMutation::Struct::Action.new(
            :group,
            'User.find_by_account_id(Account.'.length,
            'User.find_by_account_id(Account.find_by_email(account_email'.length,
            nil,
            [
              NodeMutation::Struct::Action.new(
                :replace,
                'User.find_by_account_id(Account.'.length,
                'User.find_by_account_id(Account.find_by_email'.length,
                'find_by'
              ),
              NodeMutation::Struct::Action.new(
                :replace,
                'User.find_by_account_id(Account.find_by_email('.length,
                'User.find_by_account_id(Account.find_by_email(account_email'.length,
                'email: account_email'
              )
            ]
          )
        ]
      end

      it 'tests with empty group action' do
        source = 'test'
        mutation = described_class.new(source, adapter: :parser)
        mutation.group do
        end
        result = mutation.test
        expect(result).not_to be_affected
        expect(result).not_to be_conflicted
        expect(result.actions.size).to eq 0
      end

      it 'tests with group action with only one action' do
        source = 'test'
        node = parser_parse(source)
        mutation = described_class.new(source, adapter: :parser)
        mutation.group do
          mutation.group do
            mutation.remove(node)
          end
        end
        result = mutation.test
        expect(result).to be_affected
        expect(result).not_to be_conflicted
        expect(result.actions.size).to eq 1
        expect(result.actions.first.type).to eq :delete
      end
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
      let(:node) { parser_parse(encoded_source) }

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
        mutation.replace(node, 'body.0.if_statement', with: 'current_user.username')
        mutation.replace(node, 'body.1.if_statement', with: 'current_user.username')
        result = mutation.test
        expect(result).to be_affected
        expect(result).not_to be_conflicted
        expect(result.actions).to eq [
          NodeMutation::Struct::Action.new(
            :replace,
            "if current_user\n  ".length,
            "if current_user\n  current_user.login".length,
            'current_user.username'
          ),
          NodeMutation::Struct::Action.new(
            :replace,
            "if current_user\n  current_user.login\nif current_user\n  ".length,
            "if current_user\n  current_user.login\nif current_user\n  current_user.name".length,
            'current_user.username'
          )
        ]
      end
    end
  end

  describe 'apis' do
    let(:adapter) { NodeMutation::ParserAdapter.new }
    let(:mutation) { described_class.new('code.rb', adapter: :parser) }
    let(:node) { '' }
    let(:action) { double }

    it 'parses append' do
      node = parser_parse("def teardown\n  do_something\nend")
      mutation.append node, 'super'
      action = mutation.actions.first
      expect(action.type).to eq :insert
      expect(action.start).to eq "def teardown\n  do_something\n".length
      expect(action.end).to eq "def teardown\n  do_something\n".length
      expect(action.new_code).to eq "  super\n"
    end

    it 'parses prepend' do
      node = parser_parse("def setup\n  do_something\nend")
      mutation.prepend node, 'super'
      action = mutation.actions.first
      expect(action.type).to eq :insert
      expect(action.start).to eq "def setup\n".length
      expect(action.end).to eq "def setup\n".length
      expect(action.new_code).to eq "  super\n"
    end

    it 'parses insert at end' do
      node = parser_parse('foo.bar')
      mutation.insert node, '&', to: 'receiver'
      action = mutation.actions.first
      expect(action.type).to eq :insert
      expect(action.start).to eq 'foo'.length
      expect(action.end).to eq 'foo'.length
      expect(action.new_code).to eq '&'
    end

    it 'parses insert at beginning' do
      node = parser_parse("open('https://google.com')")
      mutation.insert node, 'URI.', at: 'beginning'
      action = mutation.actions.first
      expect(action.type).to eq :insert
      expect(action.start).to eq 0
      expect(action.end).to eq 0
      expect(action.new_code).to eq 'URI.'
    end

    it 'parses replace_with' do
      node = parser_parse('FactoryBot.create(:user)')
      mutation.replace_with node, 'create({{arguments}})'
      action = mutation.actions.first
      expect(action.type).to eq :replace
      expect(action.start).to eq 0
      expect(action.end).to eq 'FactoryBot.create(:user)'.length
      expect(action.new_code).to eq 'create(:user)'
    end

    it 'parses replace with' do
      node = parser_parse("class User < ActiveRecord::Base\nend")
      mutation.replace node, :parent_class, with: 'ApplicationRecord'
      action = mutation.actions.first
      expect(action.type).to eq :replace
      expect(action.start).to eq 'class User < '.length
      expect(action.end).to eq 'class User < ActiveRecord::Base'.length
      expect(action.new_code).to eq 'ApplicationRecord'
    end

    it 'parses remove' do
      node = parser_parse("puts 'hello world'")
      mutation.remove node
      action = mutation.actions.first
      expect(action.type).to eq :delete
      expect(action.start).to eq 0
      expect(action.end).to eq "puts 'hello world'".length
      expect(action.new_code).to eq ''
    end

    it 'parses delete' do
      node = parser_parse("BigDecimal.new('1.0')")
      mutation.delete node, :dot, :message
      action = mutation.actions.first
      expect(action.type).to eq :delete
      expect(action.start).to eq 'BigDecimal'.length
      expect(action.end).to eq 'BigDecimal.new'.length
      expect(action.new_code).to eq ''
    end

    context '#wrap' do
      it 'parses without newline' do
        node = parser_parse('robot.process')
        mutation.wrap node, prefix: '3.times { ', suffix: ' }'
        group_action = mutation.actions.first
        expect(group_action.type).to eq :group
        expect(group_action.actions.size).to eq 2
        expect(group_action.actions[0].start).to eq 0
        expect(group_action.actions[0].end).to eq 0
        expect(group_action.actions[0].new_code).to eq '3.times { '
        expect(group_action.actions[1].start).to eq 'robot.process'.length
        expect(group_action.actions[1].end).to eq 'robot.process'.length
        expect(group_action.actions[1].new_code).to eq ' }'
      end

      it 'parses with newline' do
        node = parser_parse("class Bar\nend")
        mutation.wrap node, prefix: 'module Foo', suffix: 'end', newline: true
        group_action = mutation.actions.first
        expect(group_action.type).to eq :group
        expect(group_action.actions.size).to eq 3
        expect(group_action.actions[0].start).to eq 0
        expect(group_action.actions[0].end).to eq 0
        expect(group_action.actions[0].new_code).to eq "module Foo\n"
        expect(group_action.actions[1].start).to eq "class Bar\nend".length
        expect(group_action.actions[1].end).to eq "class Bar\nend".length
        expect(group_action.actions[1].new_code).to eq "\nend"
        expect(group_action.actions[2].start).to eq 0
        expect(group_action.actions[2].end).to eq "class Bar\nend".length
        expect(group_action.actions[2].new_code).to eq "  class Bar\n  end"
      end
    end

    it 'parses group' do
      node = parser_parse("class Bar\nend")
      mutation.group do
        mutation.insert node, "module Foo\n", at: 'beginning'
        mutation.insert node, "\nend", at: 'end'
      end
      group_action = mutation.actions.first
      expect(group_action.type).to eq :group
      expect(group_action.actions.size).to eq 2
      expect(group_action.actions[0].start).to eq 0
      expect(group_action.actions[0].end).to eq 0
      expect(group_action.actions[0].new_code).to eq "module Foo\n"
      expect(group_action.actions[1].start).to eq "class Bar\nend".length
      expect(group_action.actions[1].end).to eq "class Bar\nend".length
      expect(group_action.actions[1].new_code).to eq "\nend"
    end

    it 'parses indent' do
      node = parser_parse("class Foo\nend")
      mutation.indent node
      action = mutation.actions.first
      expect(action.type).to eq :replace
      expect(action.start).to eq 0
      expect(action.end).to eq "class Foo\nend".length
      expect(action.new_code).to eq "  class Foo\n  end"
    end

    it 'parses noop' do
      expect(NodeMutation::NoopAction).to receive(:new).with(
        node,
        adapter: instance_of(NodeMutation::ParserAdapter)
      ).and_return(action)
      expect(action).to receive(:process)
      mutation.noop node
    end
  end
end
