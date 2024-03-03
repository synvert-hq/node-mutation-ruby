# frozen_string_literal: true

require 'prism'
require 'prism_ext'

class NodeMutation::PrismAdapter < NodeMutation::Adapter
  def get_source(node)
    if node.is_a?(Array)
      return node.first.instance_variable_get(:@source).source[node.first.location.start_offset...node.last.location.end_offset]
    end

    node.to_source
  end

  # It gets the new source code after evaluating the node.
  # @param node [Prism::Node] The node to evaluate.
  # @param code [String] The code to evaluate.
  # @return [String] The new source code.
  # @example
  #     node = Prism.parse('class Synvert; end').value.statements.body.first
  #     rewritten_source(node, '{{constant}}') # 'Synvert'
  #
  #     # index for node array
  #     node = Prism.parse("foo.bar(a, b)").value.statements.body.first
  #     rewritten_source(node, '{{arguments.arguments.parts.-1}}')) # 'b'
  #
  #     # {key}_assoc for HashNode node
  #     node = Prism.parse("after_commit :do_index, on: :create, if: :indexable?").value.statements.body.first
  #     rewritten_source(node, '{{arguments.parts.-1.on_assoc}}')) # 'on: :create'
  #
  #     # {key}_value for hash node
  #     node = Prism.parse("after_commit :do_index, on: :create, if: :indexable?").value.statements.body.first
  #     rewritten_source(node, '{{arguments.parts.-1.on_value}}')) # ':create'
  #
  #     # to_single_quote for StringNode
  #     node = Prism.parse('"foo"').value.statements.body.first
  #     rewritten_source(node, 'to_single_quote') # "'foo'"
  #
  #     # to_double_quote for StringNode
  #     node = Prism.parse("'foo'").value.statements.body.first
  #     rewritten_source(node, 'to_double_quote') # '"foo"'
  #
  #     # to_symbol for StringNode
  #     node = Prism.parse("'foo'").value.statements.body.first
  #     rewritten_source(node, 'to_symbol') # ':foo'
  #
  #     # to_string for SymbolNode
  #     node = Prism.parse(":foo").value.statements.body.first
  #     rewritten_source(node, 'to_string') # 'foo'
  #
  #     # to_lambda_literal for CallNode with lambda
  #     node = Prism.parse('lambda { foobar }').value.statements.body.first
  #     rewritten_source(node, 'to_lambda_literal') # '-> { foobar }'
  #
  #     # strip_curly_braces for HashNode
  #     node = Prism.parse("{ foo: 'bar' }").value.statements.body.first
  #     rewritten_source(node, 'strip_curly_braces') # "foo: 'bar'"
  #
  #     # wrap_curly_braces for KeywordHashNode
  #     node = Prism.parse("test(foo: 'bar')").value.statements.body.first
  #     rewritten_source(node.arguments.arguments.parts.first, 'wrap_curly_braces') # "{ foo: 'bar' }"
  def rewritten_source(node, code)
    code.gsub(/{{(.+?)}}/m) do
      old_code = Regexp.last_match(1)
      evaluated = child_node_by_name(node, old_code)
      case evaluated
      when Prism::Node
        get_source(evaluated)
      when Array
        if evaluated.size > 0
          source = get_source(evaluated)
          lines = source.split "\n"
          lines_count = lines.length
          if lines_count > 1 && lines_count == evaluated.size
            new_code = []
            lines.each_with_index { |line, index|
              new_code << (index == 0 ? line : line[get_start_loc(evaluated.first).column - NodeMutation.tab_width..-1])
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
    node.instance_variable_get(:@source).source
  end

  # Get the range of the child node.
  # @param node [Parser::AST::Node] The node.
  # @param child_name [String] THe name to find child node.
  # @return {NodeMutation::Struct::Range} The range of the child node.
  # @example
  #     node = Prism.parse('foo.bar(test)').value.statements.body.first
  #     child_node_range(node, 'receiver') # { start: 0, end: 'foo'.length }
  #
  #     # node array
  #     node = Prism.parse('foo.bar(a, b)').value.statements.body.first
  #     child_node_range(node, 'arguments.arguments') # { start: 'foo.bar('.length, end: 'foo.bar(a, b'.length }
  #
  #     # index for node array
  #     node = Prism.parse('foo.bar(a, b)').value.statements.body.first
  #     child_node_range(node, 'arguments.arguments.parts.-1') # { start: 'foo.bar(a, '.length, end: 'foo.bar(a, b'.length }
  #
  #     # operator of Binary node
  #     node = Prism.parse('foo | bar').value.statements.body.first
  #     child_node_range(node, 'operator') # { start: 'foo '.length, end: 'foo |'.length }
  def child_node_range(node, child_name)
    direct_child_name, nested_child_name = child_name.to_s.split('.', 2)

    if node.is_a?(Array)
      if direct_child_name =~ INDEX_REGEXP
        child_node = node[direct_child_name.to_i]
        raise NodeMutation::MethodNotSupported,
              "#{direct_child_name} is not supported for #{get_source(node)}" unless child_node
        return child_node_range(child_node, nested_child_name) if nested_child_name

        return NodeMutation::Struct::Range.new(child_node.location.start_offset, child_node.location.end_offset)
      end

      raise NodeMutation::MethodNotSupported,
            "#{direct_child_name} is not supported for #{get_source(node)}" unless node.respond_to?(direct_child_name)

      child_node = node.send(direct_child_name)
      return child_node_range(child_node, nested_child_name) if nested_child_name

      return NodeMutation::Struct::Range.new(child_node.location.start_offset, child_node.location.end_offset)
    end

    if node.respond_to?("#{child_name}_loc")
      node_loc = node.send("#{child_name}_loc")
      NodeMutation::Struct::Range.new(node_loc.start_offset, node_loc.end_offset) if node_loc
    elsif node.is_a?(Prism::CallNode) && child_name.to_sym == :name
      NodeMutation::Struct::Range.new(node.message_loc.start_offset, node.message_loc.end_offset)
    elsif node.is_a?(Prism::LocalVariableReadNode) && child_name.to_sym == :name
      NodeMutation::Struct::Range.new(node.location.start_offset, node.location.end_offset)
    else
      raise NodeMutation::MethodNotSupported,
            "#{direct_child_name} is not supported for #{get_source(node)}" unless node.respond_to?(direct_child_name)

      child_node = node.send(direct_child_name)

      return child_node_range(child_node, nested_child_name) if nested_child_name

      return nil if child_node.nil?
      return nil if child_node == []

      if child_node.is_a?(Prism::Node)
        return(
          NodeMutation::Struct::Range.new(child_node.location.start_offset, child_node.location.end_offset)
        )
      end

      return(
        NodeMutation::Struct::Range.new(child_node.first.location.start_offset, child_node.last.location.end_offset)
      )
    end
  end

  def get_start(node, child_name = nil)
    node = child_node_by_name(node, child_name) if child_name
    node.location.start_offset
  end

  def get_end(node, child_name = nil)
    node = child_node_by_name(node, child_name) if child_name
    node.location.end_offset
  end

  def get_start_loc(node, child_name = nil)
    node = child_node_by_name(node, child_name) if child_name
    NodeMutation::Struct::Location.new(node.location.start_line, node.location.start_column)
  end

  def get_end_loc(node, child_name = nil)
    node = child_node_by_name(node, child_name) if child_name
    NodeMutation::Struct::Location.new(node.location.end_line, node.location.end_column)
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
    elsif direct_child_name == 'to_symbol' && node.is_a?(Prism::StringNode)
      child_node = ":#{node.to_value}"
    elsif direct_child_name == 'to_string' && node.is_a?(Prism::SymbolNode)
      child_node = node.to_value.to_s
    elsif direct_child_name == 'to_single_quote' && node.is_a?(Prism::StringNode)
      child_node = "'#{node.to_value}'"
    elsif direct_child_name == 'to_double_quote' && node.is_a?(Prism::StringNode)
      child_node = "\"#{node.to_value}\""
    elsif direct_child_name == 'to_lambda_literal' && node.is_a?(Prism::CallNode) && node.name == :lambda
      if node.block.parameters
        child_node = "->(#{node.block.parameters.parameters.to_source}) { #{node.block.body.to_source} }"
      else
        child_node = "-> #{node.block.to_source}"
      end
    elsif direct_child_name == 'strip_curly_braces' && node.is_a?(Prism::HashNode)
      child_node = node.to_source.sub(/^{(.*)}$/) { Regexp.last_match(1).strip }
    elsif direct_child_name == 'wrap_curly_braces' && node.is_a?(Prism::KeywordHashNode)
      child_node = "{ #{node.to_source} }"
    else
      raise NodeMutation::MethodNotSupported, "#{direct_child_name} is not supported for #{get_source(node)}"
    end

    return child_node_by_name(child_node, nested_child_name) if nested_child_name

    child_node
  end
end
