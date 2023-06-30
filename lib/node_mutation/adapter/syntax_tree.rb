# frozen_string_literal: true

require 'syntax_tree'
require 'syntax_tree_ext'

class NodeMutation::SyntaxTreeAdapter < NodeMutation::Adapter
  def get_source(node)
    if node.is_a?(Array)
      return node.first.source[node.first.location.start_char...node.last.location.end_char]
    end

    node.source[node.location.start_char...node.location.end_char]
  end

  # It gets the new source code after evaluating the node.
  # @param node [SyntaxTree::Node] The node to evaluate.
  # @param code [String] The code to evaluate.
  # @return [String] The new source code.
  # @example
  #     node = SyntaxTree::Parser.new('class Synvert; end').parse.statements.body.first
  #     rewritten_source(node, '{{constant}}').to eq 'Synvert'
  #
  #     # index for node array
  #     node = SyntaxTree::Parser.new("foo.bar(a, b)").parse.statements.body.first
  #     rewritten_source(node, '{{arguments.arguments.parts.-1}}')).to eq 'b'
  #
  #     # {key}_assoc for HashLiteral node
  #     node = SyntaxTree::Parser.new("after_commit :do_index, on: :create, if: :indexable?").parse.statements.body.first
  #     rewritten_source(node, '{{arguments.parts.-1.on_assoc}}')).to eq 'on: :create'
  #
  #     # {key}_value for hash node
  #     node = SyntaxTree::Parser.new("after_commit :do_index, on: :create, if: :indexable?").parse.statements.body.first
  #     rewritten_source(node, '{{arguments.parts.-1.on_value}}')).to eq ':create'
  #
  #     # to_single_quote for StringLiteral node
  #     node = SyntaxTree::Parser.new('"foo"').parse.statements.body.first
  #     rewritten_source(node, 'to_single_quote') => "'foo'"
  #
  #     # to_double_quote for StringLiteral node
  #     node = SyntaxTree::Parser.new("'foo'").parse.statements.body.first
  #     rewritten_source(node, 'to_double_quote') => '"foo"'
  #
  #     # to_symbol for StringLiteral node
  #     node = SyntaxTree::Parser.new("'foo'").parse.statements.body.first
  #     rewritten_source(node, 'to_symbol') => ':foo'
  #
  #     # to_string for SymbolLiteral node
  #     node = SyntaxTree::Parser.new(":foo").parse.statements.body.first
  #     rewritten_source(node, 'to_string') => 'foo'
  #
  #     # to_lambda_literal for MethodAddBlock node
  #     node = SyntaxTree::Parser.new('lambda { foobar }').parse.statements.body.first
  #     rewritten_source(node, 'to_lambda_literal') => '-> { foobar }'
  #
  #     # strip_curly_braces for HashLiteral node
  #     node = SyntaxTree::Parser.new("{ foo: 'bar' }").parse.statements.body.first
  #     rewritten_source(node, 'strip_curly_braces') => "foo: 'bar'"
  #
  #     # wrap_curly_braces for BareAssocHash node
  #     node = SyntaxTree::Parser.new("test(foo: 'bar')").parse.statements.body.first
  #     rewritten_source(node.arguments.arguments.parts.first, 'wrap_curly_braces') => "{ foo: 'bar' }"
  def rewritten_source(node, code)
    code.gsub(/{{(.+?)}}/m) do
      old_code = Regexp.last_match(1)
      evaluated = child_node_by_name(node, old_code)
      case evaluated
      when SyntaxTree::Node
        get_source(evaluated)
      when Array
        if evaluated.size > 0
          source = get_source(evaluated)
          lines = source.split "\n"
          lines_count = lines.length
          if lines_count > 1 && lines_count == evaluated.size
            new_code = []
            lines.each_with_index { |line, index|
              new_code << (index == 0 ? line : line[evaluated.first.indent - 2..-1])
            }
            new_code.join("\n")
          else
            source
          end
        end
      when String, Symbol, Integer, Float
        evaluated
      when NilClass
        ''
      else
        raise "can not parse \"#{code}\""
      end
    end
  end

  def file_source(node)
    node.source
  end

  # Get the range of the child node.
  # @param node [Parser::AST::Node] The node.
  # @param child_name [String] THe name to find child node.
  # @return {NodeMutation::Struct::Range} The range of the child node.
  # @example
  #     node = SyntaxTree::Parser.new('foo.bar(test)').parse.statements.body.first
  #     child_node_range(node, 'receiver') => { start: 0, end: 'foo'.length }
  #
  #     # node array
  #     node = SyntaxTree::Parser.new('foo.bar(a, b)').parse.statements.body.first
  #     child_node_range(node, 'arguments.arguments') => { start: 'foo.bar('.length, end: 'foo.bar(a, b'.length }
  #
  #     # index for node array
  #     node = SyntaxTree::Parser.new('foo.bar(a, b)').parse.statements.body.first
  #     child_node_range(node, 'arguments.arguments.parts.-1') => { start: 'foo.bar(a, '.length, end: 'foo.bar(a, b'.length }
  #
  #     # operator of Binary node
  #     node = SyntaxTree::Parser.new('foo | bar').parse.statements.body.first
  #     child_node_range(node, 'operator') => { start: 'foo '.length, end: 'foo |'.length }
  def child_node_range(node, child_name)
    child_node = child_node_by_name(node, child_name)
    return nil if child_node.nil?

    if child_node.is_a?(Array)
      return NodeMutation::Struct::Range.new(child_node.first.location.start_char, child_node.last.location.end_char)
    end

    if node.is_a?(SyntaxTree::Binary) && child_name == 'operator'
      start_char = node.left.location.end_char
      start_char += 1 while node.source[start_char] == ' '
      end_char = node.right.location.start_char
      end_char -= 1 while node.source[end_char - 1] == ' '
      return NodeMutation::Struct::Range.new(start_char, end_char)
    end

    return NodeMutation::Struct::Range.new(child_node.location.start_char, child_node.location.end_char)
  end

  def get_start(node, child_name = nil)
    node = child_node_by_name(node, child_name) if child_name
    node.location.start_char
  end

  def get_end(node, child_name = nil)
    node = child_node_by_name(node, child_name) if child_name
    node.location.end_char
  end

  def get_start_loc(node, child_name = nil)
    node = child_node_by_name(node, child_name) if child_name
    NodeMutation::Struct::Location.new(node.location.start_line, node.location.start_column)
  end

  def get_end_loc(node, child_name = nil)
    node = child_node_by_name(node, child_name) if child_name
    NodeMutation::Struct::Location.new(node.location.end_line, node.location.end_column)
  end

  def get_indent(node)
    node.location.start_column
  end

  private

  def child_node_by_name(node, child_name)
    direct_child_name, nested_child_name = child_name.to_s.split('.', 2)

    if node.is_a?(Array)
      if direct_child_name =~ INDEX_REGEXP
        child_node = node[direct_child_name.to_i]
        raise NodeMutation::MethodNotSupported,
              "#{direct_child_name} is not supported for #{get_source(node)}" unless child_node
        return child_node_by_name(child_node, nested_child_name) if nested_child_name

        return child_node
      end

      raise NodeMutation::MethodNotSupported,
            "#{direct_child_name} is not supported for #{get_source(node)}" unless node.respond_to?(direct_child_name)

      child_node = node.send(direct_child_name)
      return child_node_by_name(child_node, nested_child_name) if nested_child_name

      return child_node
    end

    if node.respond_to?(direct_child_name)
      child_node = node.send(direct_child_name)
    elsif direct_child_name == 'to_symbol' && node.is_a?(SyntaxTree::StringLiteral)
      child_node = ":#{node.to_value}"
    elsif direct_child_name == 'to_string' && node.is_a?(SyntaxTree::SymbolLiteral)
      child_node = node.to_value.to_s
    elsif direct_child_name == 'to_single_quote' && node.is_a?(SyntaxTree::StringLiteral)
      child_node = "'#{node.to_value}'"
    elsif direct_child_name == 'to_double_quote' && node.is_a?(SyntaxTree::StringLiteral)
      child_node = "\"#{node.to_value}\""
    elsif direct_child_name == 'to_lambda_literal' && node.is_a?(SyntaxTree::MethodAddBlock) && node.call.message.value == 'lambda'
      if node.block.block_var
        child_node = "->(#{node.block.block_var.params.to_source}) {#{node.block.bodystmt.to_source}}"
      else
        child_node = "-> {#{node.block.bodystmt.to_source}}"
      end
    elsif direct_child_name == 'strip_curly_braces' && node.is_a?(SyntaxTree::HashLiteral)
      child_node = node.to_source.sub(/^{(.*)}$/) { Regexp.last_match(1).strip }
    elsif direct_child_name == 'wrap_curly_braces' && node.is_a?(SyntaxTree::BareAssocHash)
      child_node = "{ #{node.to_source} }"
    else
      raise NodeMutation::MethodNotSupported, "#{direct_child_name} is not supported for #{get_source(node)}"
    end

    return child_node_by_name(child_node, nested_child_name) if nested_child_name

    child_node
  end
end
