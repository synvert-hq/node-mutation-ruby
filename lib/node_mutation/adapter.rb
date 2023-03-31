# frozen_string_literal: true

class NodeMutation::Adapter
  # Get source code of the ast node
  # @param node [Node] ast node
  # @return [String] source code
  def get_source(node)
    raise NotImplementedError, "get_source is not implemented"
  end

  # Replace the child node selector with child node source code
  # @param node [Node] ast node
  # @param code [String] code with child node selector, e.g. `Boolean({{expression.operand.operand}})`
  # @return [String] code with source code of child node selector,
  # @example # source code of ast node is `!!foobar`, code is `Boolean({{expression.operand.operand}})`,
  # it will return `Boolean(foobar)`
  def rewritten_source(node, code)
    raise NotImplementedError, "rewritten_source is not implemented"
  end

  # The file content of the ast node file
  # @param node [Node] ast node
  # @return file content
  def file_content(node)
    raise NotImplementedError, "file_content is not implemented"
  end

  # Get the start/end range of the child node
  # @param node [Node] ast node
  # @param child_name [String] child name selector
  # @return [{ start: Number, end: Number }] child node range
  def child_node_range(node, child_name)
    raise NotImplementedError, "child_node_range is not implemented"
  end

  # Get start position of ast node
  # @param node [Node] ast node
  # @param child_name [String] child name selector
  # @return [Number] start position of node or child node
  def get_start(node, child_name = nil)
    raise NotImplementedError, "get_start is not implemented"
  end

  # Get end position of ast node
  # @param node [Node] ast node
  # @param child_name [String] child name selector
  # @return [Number] end position of node or child node
  def get_end(node, child_name = nil)
    raise NotImplementedError, "get_end is not implemented"
  end

  # Get start location of ast node
  # @param node [Node] ast node
  # @return [{ line: Number, column: Number }] start location
  def get_start_loc(node)
    raise NotImplementedError, "get_start_loc is not implemented"
  end

  # Get end location of ast node
  # @param node [Node] ast node
  # @return [{ line: Number, column: Number }] end location
  def get_end_loc(node)
    raise NotImplementedError, "get_end_loc is not implemented"
  end

  # Get indent of ast node
  # @param node [Node] ast node
  # @return [Number] indent
  def get_indent(node)
    raise NotImplementedError, "get_indent is not implemented"
  end
end
