# frozen_string_literal: true

class NodeMutation::SyntaxTreeAdapter < NodeMutation::Adapter
  def get_source(node)
    if node.is_a?(Array)
      return node.first.source[node.first.location.start_char...node.last.location.end_char]
    end

    node.source[node.location.start_char...node.location.end_char]
  end

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

  def child_node_range(node, child_name)
    child_node = child_node_by_name(node, child_name)
    return nil if child_node.nil?

    if child_node.is_a?(Array)
      return NodeMutation::Struct::Range.new(child_node.first.location.start_char, child_node.last.location.end_char)
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
    elsif direct_child_name.include?('(') && direct_child_name.include?(')')
      child_node = node.instance_eval(direct_child_name)
    else
      raise NodeMutation::MethodNotSupported, "#{direct_child_name} is not supported for #{get_source(node)}"
    end

    return child_node_by_name(child_node, nested_child_name) if nested_child_name

    child_node
  end
end
