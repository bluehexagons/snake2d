extends SceneTree

const GameManagerScript := preload("res://autoload/game_manager.gd")

var _failed := false

class FakeConfig extends RefCounted:
	const MAX_HIGH_SCORES := 3

class FakeSaveData extends RefCounted:
	var stored_scores: Array[int] = [30, 20, 10]

	func load_high_scores() -> Array[int]:
		return stored_scores.duplicate()

	func sanitize_high_scores(scores: Array[int]) -> Array[int]:
		var sanitized := scores.duplicate()
		sanitized.sort_custom(func(a: int, b: int) -> bool: return a > b)
		if sanitized.size() > FakeConfig.MAX_HIGH_SCORES:
			sanitized.resize(FakeConfig.MAX_HIGH_SCORES)
		return sanitized

	func save_high_scores(scores: Array[int]) -> void:
		stored_scores = scores.duplicate()

func _initialize() -> void:
	var save_data := FakeSaveData.new()
	var game_manager := GameManagerScript.new()
	game_manager.set_config(FakeConfig.new())
	game_manager.set_save_data_util(save_data)

	_expect_scores(game_manager.get_high_scores(), [30, 20, 10], "load saved scores")

	game_manager.end_game(25)
	_expect_scores(game_manager.get_high_scores(), [30, 25, 20], "rank and limit scores")
	_expect_scores(save_data.stored_scores, [30, 25, 20], "persist ranked scores")

	game_manager.clear_high_scores()
	_expect_scores(game_manager.get_high_scores(), [], "clear in-memory scores")
	_expect_scores(save_data.stored_scores, [], "clear persisted scores")

	game_manager.end_game(5)
	_expect_scores(game_manager.get_high_scores(), [5], "keep cleared scores cleared")
	_expect_scores(save_data.stored_scores, [5], "persist only the new score after reset")

	game_manager.free()
	if _failed:
		quit(1)
	else:
		print("Game manager test passed.")
		quit()

func _expect_scores(actual: Array[int], expected: Array[int], action: String) -> void:
	if actual != expected:
		_failed = true
		push_error("Expected %s to produce %s, got %s." % [action, expected, actual])
