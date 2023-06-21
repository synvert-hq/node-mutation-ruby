# frozen_string_literal: true

require 'parser'
require 'parser_node_ext'

class NodeMutation::ParserAdapter < NodeMutation::Adapter
  def get_source(node)
    if node.is_a?(Array)
      return "" if node.empty?

      source = file_source(node.first)
      source[node.first.loc.expression.begin_pos...node.last.loc.expression.end_pos]
    else
      node.loc.expression.source
    end
  end

  # It gets the new source code after evaluating the node.
  # @param node [Parser::AST::Node] The node to evaluate.
  # @param code [String] The code to evaluate.
  # @return [String] The new source code.
  # @example
  #     node = Parser::CurrentRuby.parse('FactoryBot.define :user do; end')
  #     rewritten_source(node, '{{call.receiver}}').to eq 'FactoryBot'
  # index for node array
  #     node = Parser::CurrentRuby.parse("test(foo, bar)")
  #     rewritten_source(node, '{{arguments.0}}')).to eq 'foo'
  # {key}_pair for hash node
  #     node = Parser::CurrentRuby.parse("'after_commit :do_index, on: :create, if: :indexable?'")
  #     rewritten_source(node, '{{arguments.-1.on_pair}}')).to eq 'on: :create'
  # {key}_value for hash node
  #     node = Parser::CurrentRuby.parse("'after_commit :do_index, on: :create, if: :indexable?'")
  #     rewritten_source(node, '{{arguments.-1.on_value}}')).to eq ':create'
  # to_single_quote for str node
  #     node = Parser::CurrentRuby.parse('"foo"')
  #     rewritten_source(node, 'to_single_quote') => "'foo'"
  # to_double_quote for str node
  #     node = Parser::CurrentRuby.parse("'foo'")
  #     rewritten_source(node, 'to_double_quote') => '"foo"'
  # to_symbol for str node
  #     node = Parser::CurrentRuby.parse("'foo'")
  #     rewritten_source(node, 'to_symbol') => ':foo'
  # to_lambda_literal for block node
  #     node = Parser::CurrentRuby.parse('lambda { foobar }')
  #     rewritten_source(node, 'to_lambda_literal') => '-> { foobar }'
  # strip_curly_braces for hash node
  #     node = Parser::CurrentRuby.parse("{ foo: 'bar' }")
  #     rewritten_source(node, 'strip_curly_braces') => "foo: 'bar'"
  # wrap_curly_braces for hash node
  #     node = Parser::CurrentRuby.parse("test(foo: 'bar')")
  #     rewritten_source(node.arguments.first, 'wrap_curly_braces') => "{ foo: 'bar' }"
  def rewritten_source(node, code)
    code.gsub(/{{(.+?)}}/m) do
      old_code = Regexp.last_match(1)
      evaluated = child_node_by_name(node, old_code)
      case evaluated
      when Parser::AST::Node
        if evaluated.type == :args
          evaluated.loc.expression.source[1...-1]
        else
          evaluated.loc.expression.source
        end
      when Array
        if evaluated.size > 0
          file_source = file_source(evaluated.first)
          source = file_source[evaluated.first.loc.expression.begin_pos...evaluated.last.loc.expression.end_pos]
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
    node.loc.expression.source_buffer.source
  end

  def child_node_range(node, child_name)
    direct_child_name, nested_child_name = child_name.to_s.split('.', 2)

    if node.is_a?(Array)
      if direct_child_name =~ INDEX_REGEXP
        child_node = node[direct_child_name.to_i]
        raise NodeMutation::MethodNotSupported,
              "#{direct_child_name} is not supported for #{get_source(node)}" unless child_node
        return child_node_range(child_node, nested_child_name) if nested_child_name

        return NodeMutation::Struct::Range.new(child_node.loc.expression.begin_pos, child_node.loc.expression.end_pos)
      end

      raise NodeMutation::MethodNotSupported,
            "#{direct_child_name} is not supported for #{get_source(node)}" unless node.respond_to?(direct_child_name)

      child_node = node.send(direct_child_name)
      return child_node_range(child_node, nested_child_name) if nested_child_name

      return NodeMutation::Struct::Range.new(child_node.loc.expression.begin_pos, child_node.loc.expression.end_pos)
    end

    case [node.type, child_name.to_sym]
    when %i[block pipes], %i[def parentheses], %i[defs parentheses]
      if node.arguments.empty?
        nil
      else
        NodeMutation::Struct::Range.new(
          node.arguments.first.loc.expression.begin_pos - 1,
          node.arguments.last.loc.expression.end_pos + 1
        )
      end
    when %i[class name], %i[const name], %i[cvar name], %i[def name], %i[defs name],
         %i[gvar name], %i[ivar name], %i[lvar name]
      NodeMutation::Struct::Range.new(node.loc.name.begin_pos, node.loc.name.end_pos)
    when %i[const double_colon]
      NodeMutation::Struct::Range.new(node.loc.double_colon.begin_pos, node.loc.double_colon.end_pos)
    when %i[defs dot]
      NodeMutation::Struct::Range.new(node.loc.operator.begin_pos, node.loc.operator.end_pos) if node.loc.operator
    when %i[defs self]
      NodeMutation::Struct::Range.new(node.loc.operator.begin_pos - 'self'.length, node.loc.operator.begin_pos)
    when %i[lvasgn variable], %i[ivasgn variable], %i[cvasgn variable], %i[gvasgn variable]
      NodeMutation::Struct::Range.new(node.loc.name.begin_pos, node.loc.name.end_pos)
    when %i[send dot], %i[csend dot]
      NodeMutation::Struct::Range.new(node.loc.dot.begin_pos, node.loc.dot.end_pos) if node.loc.dot
    when %i[send message], %i[csend message]
      if node.loc.operator
        NodeMutation::Struct::Range.new(node.loc.selector.begin_pos, node.loc.operator.end_pos)
      else
        NodeMutation::Struct::Range.new(node.loc.selector.begin_pos, node.loc.selector.end_pos)
      end
    when %i[send parentheses], %i[csend parentheses]
      if node.loc.begin && node.loc.end
        NodeMutation::Struct::Range.new(node.loc.begin.begin_pos, node.loc.end.end_pos)
      end
    else
      raise NodeMutation::MethodNotSupported,
            "#{direct_child_name} is not supported for #{get_source(node)}" unless node.respond_to?(direct_child_name)

      child_node = node.send(direct_child_name)

      return child_node_range(child_node, nested_child_name) if nested_child_name

      return nil if child_node.nil?

      if child_node.is_a?(Parser::AST::Node)
        return(
          NodeMutation::Struct::Range.new(child_node.loc.expression.begin_pos, child_node.loc.expression.end_pos)
        )
      end

      # arguments
      return nil if child_node.empty?

      return(
        NodeMutation::Struct::Range.new(
          child_node.first.loc.expression.begin_pos,
          child_node.last.loc.expression.end_pos
        )
      )
    end
  end

  def get_start(node, child_name = nil)
    node = child_node_by_name(node, child_name) if child_name
    node.loc.expression.begin_pos
  end

  def get_end(node, child_name = nil)
    node = child_node_by_name(node, child_name) if child_name
    node.loc.expression.end_pos
  end

  def get_start_loc(node, child_name = nil)
    node = child_node_by_name(node, child_name) if child_name
    begin_loc = node.loc.expression.begin
    NodeMutation::Struct::Location.new(begin_loc.line, begin_loc.column)
  end

  def get_end_loc(node, child_name = nil)
    node = child_node_by_name(node, child_name) if child_name
    end_loc = node.loc.expression.end
    NodeMutation::Struct::Location.new(end_loc.line, end_loc.column)
  end

  def get_indent(node)
    file_source(node).split("\n")[get_start_loc(node).line - 1][/\A */].size
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
    elsif direct_child_name == 'to_symbol' && node.type == :str
      child_node = ":#{node.to_value}"
    elsif direct_child_name == 'to_single_quote' && node.type == :str
      child_node = "'#{node.to_value}'"
    elsif direct_child_name == 'to_double_quote' && node.type == :str
      child_node = "\"#{node.to_value}\""
    elsif direct_child_name == 'to_lambda_literal' && node.type == :block && node.caller.type == :send && node.caller.receiver.nil? && node.caller.message == :lambda
      new_source = node.to_source
      if node.arguments.size > 1
        new_source = new_source[0...node.arguments.first.loc.expression.begin_pos - 2] + new_source[node.arguments.last.loc.expression.end_pos + 1..-1]
        new_source = new_source.sub('lambda', "->(#{node.arguments.map(&:to_source).join(', ')})")
      else
        new_source = new_source.sub('lambda', '->')
      end
      child_node = new_source
    elsif direct_child_name == 'strip_curly_braces' && node.type == :hash
      child_node = node.to_source.sub(/^{(.*)}$/) { Regexp.last_match(1).strip }
    elsif direct_child_name == 'wrap_curly_braces' && node.type == :hash
      child_node = "{ #{node.to_source} }"
    else
      raise NodeMutation::MethodNotSupported, "#{direct_child_name} is not supported for #{get_source(node)}"
    end

    return child_node_by_name(child_node, nested_child_name) if nested_child_name

    child_node
  end
end
