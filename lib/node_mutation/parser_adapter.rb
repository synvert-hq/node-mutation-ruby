# frozen_string_literal: true

class NodeMutation::ParserAdapter < NodeMutation::Adapter
  def get_source(node)
    node.loc.expression.source
  end

  def rewritten_source(node, code)
    code.gsub(/{{(.+?)}}/m) do
      old_code = Regexp.last_match(1)
      begin
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
          'nil'
        else
          raise "rewritten_source is not handled for #{evaluated.inspect}"
        end
      rescue StandardError => e
        raise "can not parse \"#{code}\""
      end
    end
  end

  def file_content(node)
    node.loc.expression.source_buffer.source
  end

  def child_node_range(node, child_name)
    if node.is_a?(Array)
      direct_child_name, nested_child_name = child_name.split('.', 2)
      child_node = direct_child_name =~ /\A\d+\z/ ? node[direct_child_name.to_i - 1] : node.send(direct_child_name)
      if nested_child_name
        return child_node_range(child_node, nested_child_name)
      elsif child_node
        return OpenStruct.new(
          start: child_node.loc.expression.begin_pos,
          end: child_node.loc.expression.end_pos
        )
      else
        raise MethodNotSupported, "child_node_range is not handled for #{get_source(node)}, child_name: #{child_name}"
      end
    end

    case [node.type, child_name.to_sym]
    when %i[block pipes], %i[def parentheses], %i[defs parentheses]
      OpenStruct.new(
        start: node.arguments.first.loc.expression.begin_pos - 1,
        end: node.arguments.last.loc.expression.end_pos + 1
      )
    when %i[block arguments], %i[def arguments], %i[defs arguments]
      OpenStruct.new(
        start: node.arguments.first.loc.expression.begin_pos,
        end: node.arguments.last.loc.expression.end_pos
      )
    when %i[class name], %i[const name], %i[def name], %i[defs name]
      OpenStruct.new(start: node.loc.name.begin_pos, end: node.loc.name.end_pos)
    when %i[defs dot]
      OpenStruct.new(start: node.loc.operator.begin_pos, end: node.loc.operator.end_pos) if node.loc.operator
    when %i[defs self]
      OpenStruct.new(start: node.loc.operator.begin_pos - 'self'.length, end: node.loc.operator.begin_pos)
    when %i[send dot], %i[csend dot]
      OpenStruct.new(start: node.loc.dot.begin_pos, end: node.loc.dot.end_pos) if node.loc.dot
    when %i[send message], %i[csend message]
      if node.loc.operator
        OpenStruct.new(start: node.loc.selector.begin_pos, end: node.loc.operator.end_pos)
      else
        OpenStruct.new(start: node.loc.selector.begin_pos, end: node.loc.selector.end_pos)
      end
    when %i[send parentheses], %i[csend parentheses]
      if node.loc.begin && node.loc.end
        OpenStruct.new(start: node.loc.begin.begin_pos, end: node.loc.end.end_pos)
      end
    else
      direct_child_name, nested_child_name = child_name.to_s.split('.', 2)
      if node.respond_to?(direct_child_name)
        child_node = node.send(direct_child_name)

        return child_node_range(child_node, nested_child_name) if nested_child_name

        return nil if child_node.nil?

        if child_node.is_a?(Parser::AST::Node)
          return(
            OpenStruct.new(
              start: child_node.loc.expression.begin_pos,
              end: child_node.loc.expression.end_pos
            )
          )
        end

        # arguments
        return nil if child_node.empty?

        return(
          OpenStruct.new(
            start: child_node.first.loc.expression.begin_pos,
            end: child_node.last.loc.expression.end_pos
          )
        )
      end
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
    OpenStruct.new(line: begin_loc.line, column: begin_loc.column)
  end

  def get_end_loc(node)
    end_loc = node.loc.expression.end
    OpenStruct.new(line: end_loc.line, column: end_loc.column)
  end

  def get_indent(node)
    file_content(node).split("\n")[get_start_loc(node).line - 1][/\A */].size
  end

  private

  def child_node_by_name(node, child_name)
    direct_child_name, nested_child_name = child_name.to_s.split('.', 2)

    if node.is_a?(Array)
      child_direct_child_node = direct_child_name =~ /\A\d+\z/ ? node[direct_child_name.to_i - 1] : node.send(direct_child_name)
      return child_node_by_name(child_direct_child_node, nested_child_name) if nested_child_name
      return child_direct_child_node if child_direct_child_node
    end

    if node.respond_to?(direct_child_name)
      child_node = node.send(direct_child_name)
    elsif direct_child_name.include?('(') && direct_child_name.include?(')')
      child_node = eval("node.#{direct_child_name}")
    else
      child_node = nil
    end

    return child_node_by_name(child_node, nested_child_name) if nested_child_name

    return nil if child_node.nil?

    return child_node if child_node.is_a?(Parser::AST::Node)

    return child_node
  end
end
