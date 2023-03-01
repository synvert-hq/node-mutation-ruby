# NodeMutation

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