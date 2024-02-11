# frozen_string_literal: true

require 'parser/current'
require 'syntax_tree'
require 'prism'

module ParserHelper
  def parser_parse(code)
    Parser::CurrentRuby.parse(code)
  end

  def syntax_tree_parse(code)
    SyntaxTree.parse(code).statements.body.first
  end

  def prism_parse(code)
    Prism.parse(code).value.statements.body.first
  end
end
