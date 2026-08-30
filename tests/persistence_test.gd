extends SceneTree

const SCORE_PATH := "user://snake2d_high_scores_test.dat"
const SETTINGS_PATH := "user://snake2d_settings_test.cfg"

var check := TestAssertions.new()

func _initialize() -> void:
	_remove_test_files()
	_high_scores_round_trip_in_ranked_order()
	_mode_score_tables_round_trip_separately()
	_legacy_score_arrays_are_migrated_on_read()
	_version_one_scores_are_migrated_to_classic()
	_malformed_scores_fail_closed()
	_settings_round_trip_and_reset()
	_remove_test_files()
	check.finish(self, "Persistence test")

func _high_scores_round_trip_in_ranked_order() -> void:
	var store := HighScoreStore.new()
	store.save_path = SCORE_PATH
	store.max_scores = 3
	store.save_high_scores([5, -1, 10, 7, 0])
	check.expect_equal(store.load_high_scores(), [10, 7, 5], "scores are ranked, filtered, and limited")
	store.free()

func _mode_score_tables_round_trip_separately() -> void:
	var store := HighScoreStore.new()
	store.save_path = SCORE_PATH
	store.max_scores = 3
	store.save_high_scores_by_mode({
		"classic": [20, 10],
		"pitfall": [35, 15],
		"obstacles": [50, 5],
	})
	var loaded := store.load_high_scores_by_mode()
	check.expect_equal(loaded.classic, [20, 10], "Classic scores round-trip in their own table")
	check.expect_equal(loaded.pitfall, [35, 15], "Pitfall scores round-trip in their own table")
	check.expect_equal(loaded.obstacles, [50, 5], "Obstacle scores round-trip in their own table")
	store.free()

func _legacy_score_arrays_are_migrated_on_read() -> void:
	var file := FileAccess.open(SCORE_PATH, FileAccess.WRITE)
	file.store_var([3, 8, -2])
	file = null
	var store := HighScoreStore.new()
	store.save_path = SCORE_PATH
	check.expect_equal(store.load_high_scores(), [8, 3], "legacy score arrays remain readable")
	store.free()

func _version_one_scores_are_migrated_to_classic() -> void:
	var file := FileAccess.open(SCORE_PATH, FileAccess.WRITE)
	file.store_var({"version": 1, "scores": [9, 4]})
	file = null
	var store := HighScoreStore.new()
	store.save_path = SCORE_PATH
	var loaded := store.load_high_scores_by_mode()
	check.expect_equal(loaded.classic, [9, 4], "v1 scores migrate into Classic")
	check.expect_equal(loaded.pitfall, [], "v1 migration leaves Pitfall empty")
	check.expect_equal(loaded.obstacles, [], "v1 migration leaves Obstacles empty")
	store.free()

func _malformed_scores_fail_closed() -> void:
	var file := FileAccess.open(SCORE_PATH, FileAccess.WRITE)
	file.store_var("not a score document")
	file = null
	var store := HighScoreStore.new()
	store.save_path = SCORE_PATH
	check.expect_equal(store.load_high_scores(), [], "malformed score data produces an empty table")
	store.free()

func _settings_round_trip_and_reset() -> void:
	var settings := SettingsService.new()
	settings.settings_path = SETTINGS_PATH
	settings.toggle_mute()
	settings.set_effects_volume_db(-8.0)
	settings.toggle_fullscreen()
	settings.toggle_reduced_motion()
	settings.toggle_grid()

	var loaded := SettingsService.new()
	loaded.settings_path = SETTINGS_PATH
	loaded.load_settings()
	check.expect_true(loaded.is_muted, "mute state round-trips")
	check.expect_equal(loaded.effects_volume_db, -8.0, "effects volume round-trips")
	check.expect_true(loaded.is_fullscreen, "fullscreen state round-trips")
	check.expect_true(loaded.reduced_motion, "reduced-motion state round-trips")
	check.expect_false(loaded.grid_enabled, "gameplay-grid state round-trips")

	loaded.reset_settings()
	var reset := SettingsService.new()
	reset.settings_path = SETTINGS_PATH
	reset.load_settings()
	check.expect_false(reset.is_muted, "reset restores sound")
	check.expect_equal(reset.effects_volume_db, 0.0, "reset restores effects volume")
	check.expect_false(reset.is_fullscreen, "reset restores windowed mode")
	check.expect_false(reset.reduced_motion, "reset restores motion")
	check.expect_true(reset.grid_enabled, "reset restores the gameplay grid")

	settings.free()
	loaded.free()
	reset.free()

func _remove_test_files() -> void:
	for path in [SCORE_PATH, SETTINGS_PATH]:
		var absolute_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(absolute_path)
