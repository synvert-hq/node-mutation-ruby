# frozen_string_literal: true

require 'parser/current'
require 'syntax_tree'

module ParserHelper
  def parser_parse(code)
    Parser::CurrentRuby.parse(code)
  end

  def syntax_tree_parse(code)
    SyntaxTree::Parser.new(code).parse.statements.body.first
  end
end
