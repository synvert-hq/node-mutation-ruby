# frozen_string_literal: true

INDEX_REGEXP = /\A-?\d+\z/

class NodeMutation::ParserAdapter < NodeMutation::Adapter
  def get_source(node)
    if node.is_a?(Array)
      return "" if node.empty?

      source = file_content(node.first)
      source[node.first.loc.expression.begin_pos...node.last.loc.expression.end_pos]
    else
      node.loc.expression.source
    end
  end

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
          file_source = file_content(evaluated.first)
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

  def file_content(node)
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
      NodeMutation::Struct::Range.new(
        node.arguments.first.loc.expression.begin_pos - 1,
        node.arguments.last.loc.expression.end_pos + 1
      )
    when %i[block arguments], %i[def arguments], %i[defs arguments]
      NodeMutation::Struct::Range.new(node.arguments.first.loc.expression.begin_pos, node.arguments.last.loc.expression.end_pos)
    when %i[class name], %i[const name], %i[def name], %i[defs name]
      NodeMutation::Struct::Range.new(node.loc.name.begin_pos, node.loc.name.end_pos)
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
      if node.type == :hash && child_name.to_s.end_with?('_pair')
        pair_node = node.pairs.find { |pair| pair.key.to_value.to_s == child_name.to_s[0..-6] }
        raise NodeMutation::MethodNotSupported,
              "#{direct_child_name} is not supported for #{get_source(node)}" unless pair_node
        return child_node_range(pair, nested_child_name) if nested_child_name

        return NodeMutation::Struct::Range.new(pair_node.loc.expression.begin_pos, pair_node.loc.expression.end_pos)
      end

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
        NodeMutation::Struct::Range.new(child_node.first.loc.expression.begin_pos, child_node.last.loc.expression.end_pos)
      )
    end
  end

  def get_start(node)
    node.loc.expression.begin_pos
  end

  def get_end(node)
    node.loc.expression.end_pos
  end

  def get_start_loc(node)
    begin_loc = node.loc.expression.begin
    NodeMutation::Struct::Location.new(begin_loc.line, begin_loc.column)
  end

  def get_end_loc(node)
    end_loc = node.loc.expression.end
    NodeMutation::Struct::Location.new(end_loc.line, end_loc.column)
  end

  def get_indent(node)
    file_content(node).split("\n")[get_start_loc(node).line - 1][/\A */].size
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

    if node.is_a?(Parser::AST::Node) && node.type == :hash && direct_child_name.end_with?('_pair')
      pair_node = node.pairs.find { |pair| pair.key.to_value.to_s == direct_child_name[0..-6] }
      raise NodeMutation::MethodNotSupported,
            "#{direct_child_name} is not supported for #{get_source(node)}" unless pair_node
      return child_node_by_name(pair_node, nested_child_name) if nested_child_name

      return pair_node
    end

    if node.respond_to?(direct_child_name)
      child_node = node.send(direct_child_name)
    elsif direct_child_name.include?('(') && direct_child_name.include?(')')
      child_node = node.instance_eval(direct_child_name)
    else
      raise NodeMutation::MethodNotSupported, "#{direct_child_name} is not supported for #{get_source(node)}"
    end

    return child_node_by_name(child_node, nested_child_name) if nested_child_name

    child_node
  end
end
