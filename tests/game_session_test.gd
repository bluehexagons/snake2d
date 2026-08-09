extends SceneTree

const GameSessionScript := preload("res://core/game_session.gd")

var check := TestAssertions.new()

class FakeGameplay extends Gameplay:
	var start_count := 0
	var cleanup_count := 0

	func start_game() -> void:
		start_count += 1

	func cleanup() -> void:
		cleanup_count += 1

class FakeHighScoreStore extends HighScoreStore:
	var stored_scores: Array[int] = [30, 20, 10]

	func _init() -> void:
		max_scores = 3

	func load_high_scores() -> Array[int]:
		return stored_scores.duplicate()

	func sanitize_high_scores(scores: Array[int]) -> Array[int]:
		var sanitized := scores.duplicate()
		sanitized.sort_custom(func(a: int, b: int) -> bool: return a > b)
		if sanitized.size() > max_scores:
			sanitized.resize(max_scores)
		return sanitized

	func save_high_scores(scores: Array[int]) -> void:
		stored_scores = scores.duplicate()

func _initialize() -> void:
	var high_score_store := FakeHighScoreStore.new()
	var gameplay := FakeGameplay.new()
	var game_session: GameSession = GameSessionScript.new()
	game_session.configure(gameplay, high_score_store)

	check.expect_equal(game_session.state, GameSession.State.MAIN_MENU, "a session starts at the main menu")
	check.expect_equal(game_session.get_high_scores(), [30, 20, 10], "configuration loads saved scores")

	game_session.start_new_round()
	game_session.start_new_round()
	check.expect_equal(game_session.state, GameSession.State.PLAYING, "starting enters the playing state")
	check.expect_equal(gameplay.start_count, 1, "starting an active round is idempotent")

	game_session.pause_round()
	game_session.pause_round()
	check.expect_equal(game_session.state, GameSession.State.PAUSED, "pausing enters the paused state")
	game_session.resume_round()
	game_session.resume_round()
	check.expect_equal(game_session.state, GameSession.State.PLAYING, "resuming returns to playing")

	gameplay.score_updated.emit(25)
	check.expect_equal(game_session.get_current_score(), 25, "gameplay score updates the session")
	gameplay.game_over.emit(25)
	gameplay.game_over.emit(15)
	check.expect_equal(game_session.state, GameSession.State.GAME_OVER, "game over ends the active round")
	check.expect_equal(game_session.get_high_scores(), [30, 25, 20], "a final score is ranked and limited")
	check.expect_equal(high_score_store.stored_scores, [30, 25, 20], "the ranked scores are persisted")

	game_session.return_to_menu()
	game_session.return_to_menu()
	check.expect_equal(game_session.state, GameSession.State.MAIN_MENU, "returning ends at the main menu")
	check.expect_equal(gameplay.cleanup_count, 1, "returning to the menu is idempotent")

	game_session.clear_high_scores()
	check.expect_equal(game_session.get_high_scores(), [], "clearing removes in-memory scores")
	check.expect_equal(high_score_store.stored_scores, [], "clearing removes persisted scores")

	game_session.start_new_round()
	gameplay.game_over.emit(5)
	check.expect_equal(game_session.get_high_scores(), [5], "a later round starts a fresh score table")

	game_session.free()
	gameplay.free()
	high_score_store.free()
	check.finish(self, "Game session test")
