# NodeMutation

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
