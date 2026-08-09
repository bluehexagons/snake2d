class_name TestAssertions
extends RefCounted

var failure_count := 0

func expect_true(condition: bool, rule: String) -> void:
	if condition:
		return
	failure_count += 1
	push_error("Expected rule to hold: %s" % rule)

func expect_false(condition: bool, rule: String) -> void:
	expect_true(not condition, rule)

func expect_equal(actual: Variant, expected: Variant, rule: String) -> void:
	if actual == expected:
		return
	failure_count += 1
	push_error("Expected %s to produce %s, got %s." % [rule, expected, actual])

func finish(tree: SceneTree, suite_name: String) -> void:
	if failure_count > 0:
		tree.quit(1)
	else:
		print("%s passed." % suite_name)
		tree.quit()
