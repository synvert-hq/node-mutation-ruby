# NodeMutation

## 1.24.4 (2024-04-16)

* Use Prism `character_offset` instead byte `offset`

## 1.24.3 (2024-04-07)

* Update `prism_ext` to 0.3.0
* Update `syntax_tree_ext` to 0.8.1
* Update `parser_node_ext` to 1.3.0

## 1.24.2 (2024-03-26)

* `child_node_range` supports `casgn` `name`

## 1.24.1 (2024-03-05)

* Adjust `start` and `end` position of `AppendAction` and `PrependAction`

## 1.24.0 (2024-03-03)

* Remove `Adapter#get_indent`

## 1.23.3 (2024-02-20)

* `child_node_range` supports `LocalVariableReadNode#name`

## 1.23.2 (2024-02-17)

* Get prism node `source` without prism_ext

## 1.23.1 (2024-02-16)

* Get `PrismAdapter`
* Get `CallNode#name` range

## 1.23.0 (2024-02-11)

* Support `prism`

## 1.22.4 (2024-01-30)

* Revert "add action methods to GroupAction"

## 1.22.3 (2024-01-30)

* `child_node_range` supports `arg` `name`
* Add `action` methods to `GroupAction`

## 1.22.2 (2023-12-04)

* `str` child node range does not include quotes

## 1.22.1 (2023-12-04)

* `child_node_range` supports int/float/str/sym `value`

## 1.22.0 (2023-11-27)

* Add `adapter` parameter to `NodeMutation`
* Add `adapter` parameter to `NodeMutation::Action`
* Do not allow to configure an `adapter` globally

## 1.21.6 (2023-11-20)

* Flat and sort actions after filtering actions when processing

## 1.21.5 (2023-11-20)

* Rewrite the process and test methods

## 1.21.4 (2023-10-28)

* Update `Adapter` rbs

## 1.21.3 (2023-10-03)

* Call `Action#to_struct` explicitly

## 1.21.2 (2023-10-02)

* Result saves group actions properly

## 1.21.1 (2023-10-01)

* Update `parser_node_ext` to 1.2.1
* Add `actions` to `NodeMutation::Struct::Action`

## 1.21.0 (2023-09-26)

* Rename `combine` dsl to `group`

## 1.20.0 (2023-09-24)

* Add `CombinedAction` to combine multiple actions.
* Add `combine` dsl to combine multiple actions.
* Add `NodeMutation::Helper.iterate_actions`

## 1.19.4 (2023-08-17)

* Use `NodeMutation.adapter.get_indent`

## 1.19.3 (2023-07-01)

* Rewrite `SyntaxTreeAdapter#child_node_range` to support Binary operator

## 1.19.2 (2023-06-30)

* Support `operator` of `Binary` node in `child_node_range`

## 1.19.1 (2023-06-22)

* Add `to_string` function

## 1.19.0 (2023-06-22)

* Drop support for function in `child_node_by_name`
* Add `to_symbol` function
* Add `to_single_quote` function
* Add `to_double_quote` function
* Add `to_lambda_literal` function
* Add `strip_curly_braces` function
* Add `wrap_curly_braces` function
* Add more comments

## 1.18.3 (2023-06-03)

* Fix rbs syntax

## 1.18.2 (2023-05-21)

* Use `rindex` to calculate "do" index

## 1.18.1 (2023-05-20)

* Support block/class/def/defs/module `body` in `child_node_range`
* Return nil if `arguments` is empty in `child_node_range`

## 1.18.0 (2023-05-16)

* Rename `file_content` to `file_source`
* Add `SyntaxTreeAdapter#file_source`

## 1.17.1 (2023-05-16)

* Require `parser` and `syntax_tree` in adapter

## 1.17.0 (2023-05-15)

* Add `SyntaxTreeAdapter`

## 1.16.0 (2023-05-10)

* Support {key}_value for a hash node

## 1.15.3 (2023-04-18)

* Add `type` to `Action`

## 1.15.2 (2023-04-17)

* Support `const` `double_colon` in child_node_range

## 1.15.1 (2023-04-17)

* Fix `wrap` code for newline

## 1.15.0 (2023-04-17)

* Add `indent` action
* Use two `InsertAction` and one `IndentAction` instead of `WrapAction`
* Drop `ALLOW_INSERT_AT_SAME_POSITION` strategy

## 1.14.0 (2023-04-04)

* Add `transform_proc` to transform the actions
* Allow to write `Action` `start` and `end` attributes

## 1.13.2 (2023-04-01)

* Support `cvar`, `gvar`, `ivar`, and `lvar` name in `child_node_range`

## 1.13.1 (2023-03-31)

* Remove both whitespace only when next char is nil

## 1.13.0 (2023-03-31)

* Adapter `get_start` and `get_end` can parse child node
* Adapter `get_start_loc` and `get_end_loc` can parse child node

## 1.12.3 (2023-03-30)

* `remove_whitespace` for both before and after whitespace

## 1.12.2 (2023-03-25)

* `remove_whitespace` handles more cases

## 1.12.1 (2023-03-23)

* Define `Action`, `Location` and `Range` in `NodeMutation::Struct`

## 1.12.0 (2023-03-23)

* Support `{key}_pair` for a `hash` node

## 1.11.0 (2023-03-20)

* Calculate position properly for `add_comma`
* Add `and_comma` param to `insert` dsl

## 1.10.1 (2023-03-13)

* Remove `OpenStruct`, use `Struct` instead

## 1.10.0 (2023-03-01)

* Support `variable` of `lvasgn`, `ivasgn`, `cvasgn`, and `gvasgn` node in `child_node_range`
* Update `parser_node_ext` to 1.0.0

## 1.9.3 (2023-02-15)

* Remove engine

## 1.9.2 (2023-02-11)

* Squeeze space if end with space, newline or semicolon

## 1.9.1 (2023-02-10)

* Make sure `tab_width` is an Integer

## 1.9.0 (2023-02-08)

* Configure `tab_width`
* Make use of `NodeMutation.tab_width`

## 1.8.2 (2023-01-17)

* Drop `activesupport`

## 1.8.1 (2022-12-26)

* `child_node_by_name` index starts from `0`

## 1.8.0 (2022-12-26)

* `child_node_range` index starts from `0`

## 1.7.1 (2022-10-26)

* Return empty string for `NilClass` in `ParserAdapter#rewritten_source`

## 1.7.0 (2022-10-25)

* Add a new strategy `ALLOW_INSERT_AT_SAME_POSITION`

## 1.6.2 (2022-10-25)

* Mark same position as conflict action

## 1.6.1 (2022-10-24)

* Better error message when node does not respond to a key

## 1.6.0 (2022-10-19)

* Raise `NodeMutation::MethodNotSupported` if not respond to child node name

## 1.5.1 (2022-10-19)

* Better error message for unknown code

## 1.5.0 (2022-10-17)

* Remove `insert_after`
* Fix regexp to match evaluated value

## 1.4.4 (2022-09-26)

* Parser adapter `child_node_by_name` support function call

## 1.4.3 (2022-09-24)

* Update source only if `new_code` is not `nil`

## 1.4.2 (2022-09-23)

* Add `NodeMutation#to_json`

## 1.4.1 (2022-09-23)

* Add `NodeMutation#noop`

## 1.4.0 (2022-09-20)

* Add `NoopAction`

## 1.3.3 (2022-09-16)

* Format `actions` in test result
* Add `file_path` attribute to `NodeMutation::Result`

## 1.3.2 (2022-09-15)

* Add `NodeMutation::Action.to_hash`
* Add `NodeMutation::Result.to_hash`

## 1.3.0 (2022-09-15)

* Add `NodeMutation#test`

## 1.2.1 (2022-07-22)

* Fix `child_node_range` for const name
* Update `parser_node_ext` to 0.4.0

## 1.2.0 (2022-07-02)

* Return new source instead of writing file
* Revert Add erb engine
* Revert Add `ReplaceErbStmtWithExprAction`

## 1.1.0 (2022-07-02)

* Add erb engine
* Add `ReplaceErbStmtWithExprAction`

## 1.0.0 (2022-07-01)

* Initial release
