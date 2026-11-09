extends SceneTree

var test_files := TestFiles.new()
var score_path := test_files.path("scores.dat")
var settings_path := test_files.path("settings.cfg")

var check := TestAssertions.new()

func _initialize() -> void:
	_high_scores_round_trip_in_ranked_order()
	_mode_score_tables_round_trip_separately()
	_legacy_score_arrays_are_migrated_on_read()
	_version_one_scores_are_migrated_to_classic()
	_malformed_scores_fail_closed()
	_truncated_scores_fail_closed()
	_settings_round_trip_and_reset()
	_external_window_mode_is_saved()
	_malformed_settings_keep_safe_defaults()
	_legacy_settings_migrate_only_complete_records()
	test_files.cleanup()
	check.finish(self, "Persistence test")

func _high_scores_round_trip_in_ranked_order() -> void:
	var store := HighScoreStore.new()
	store.save_path = score_path
	store.max_scores = 3
	store.save_high_scores([5, -1, 10, 7, 0])
	check.expect_equal(store.load_high_scores(), [10, 7, 5], "scores are ranked, filtered, and limited")
	store.free()

func _mode_score_tables_round_trip_separately() -> void:
	var store := HighScoreStore.new()
	store.save_path = score_path
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
	var file := FileAccess.open(score_path, FileAccess.WRITE)
	file.store_var([3, 8, -2])
	file = null
	var store := HighScoreStore.new()
	store.save_path = score_path
	check.expect_equal(store.load_high_scores(), [8, 3], "legacy score arrays remain readable")
	store.free()

func _version_one_scores_are_migrated_to_classic() -> void:
	var file := FileAccess.open(score_path, FileAccess.WRITE)
	file.store_var({"version": 1, "scores": [9, 4]})
	file = null
	var store := HighScoreStore.new()
	store.save_path = score_path
	var loaded := store.load_high_scores_by_mode()
	check.expect_equal(loaded.classic, [9, 4], "v1 scores migrate into Classic")
	check.expect_equal(loaded.pitfall, [], "v1 migration leaves Pitfall empty")
	check.expect_equal(loaded.obstacles, [], "v1 migration leaves Obstacles empty")
	store.free()

func _malformed_scores_fail_closed() -> void:
	var file := FileAccess.open(score_path, FileAccess.WRITE)
	file.store_var("not a score document")
	file = null
	var store := HighScoreStore.new()
	store.save_path = score_path
	check.expect_equal(store.load_high_scores(), [], "malformed score data produces an empty table")
	store.free()

func _truncated_scores_fail_closed() -> void:
	var store := HighScoreStore.new()
	store.save_path = score_path
	var valid := var_to_bytes({"version": 2, "scores_by_mode": {"classic": [10]}})
	# store_var writes a four-byte payload length before the encoded Variant.
	for length in [0, 1, 3, 4, 5, valid.size() + 3]:
		var record := PackedByteArray()
		record.resize(4)
		record.encode_u32(0, valid.size())
		record.append_array(valid)
		record.resize(length)
		var file := FileAccess.open(score_path, FileAccess.WRITE)
		file.store_buffer(record)
		file.close()
		check.expect_equal(store.load_high_scores(), [], "truncated score records fail closed at %d bytes" % length)
		check.expect_equal(FileAccess.get_file_as_bytes(score_path), record, "loading damaged scores does not rewrite player data")
	for declared_length in [0, 3, 0xffffffff]:
		var record := PackedByteArray()
		record.resize(8)
		record.encode_u32(0, declared_length)
		var file := FileAccess.open(score_path, FileAccess.WRITE)
		file.store_buffer(record)
		file.close()
		check.expect_equal(store.load_high_scores(), [], "invalid score payload lengths fail closed")
	store.save_high_scores([15])
	check.expect_equal(store.load_high_scores(), [15], "a new complete score record can replace a damaged save")
	store.free()

func _settings_round_trip_and_reset() -> void:
	var settings := SettingsService.new()
	settings.settings_path = settings_path
	settings.toggle_mute()
	settings.set_effects_volume_db(-8.0)
	settings.toggle_fullscreen()
	settings.toggle_reduced_motion()
	settings.toggle_grid()

	var loaded := SettingsService.new()
	loaded.settings_path = settings_path
	loaded.load_settings()
	check.expect_true(loaded.is_muted, "mute state round-trips")
	check.expect_equal(loaded.effects_volume_db, -8.0, "effects volume round-trips")
	check.expect_true(loaded.is_fullscreen, "fullscreen state round-trips")
	check.expect_true(loaded.reduced_motion, "reduced-motion state round-trips")
	check.expect_false(loaded.grid_enabled, "gameplay-grid state round-trips")

	loaded.reset_settings()
	var reset := SettingsService.new()
	reset.settings_path = settings_path
	reset.load_settings()
	check.expect_false(reset.is_muted, "reset restores sound")
	check.expect_equal(reset.effects_volume_db, 0.0, "reset restores effects volume")
	check.expect_false(reset.is_fullscreen, "reset restores windowed mode")
	check.expect_false(reset.reduced_motion, "reset restores motion")
	check.expect_true(reset.grid_enabled, "reset restores the gameplay grid")

	settings.free()
	loaded.free()
	reset.free()

func _external_window_mode_is_saved() -> void:
	var settings := SettingsService.new()
	settings.settings_path = test_files.path("window.cfg")
	# The headless display is windowed, just as a browser is after Escape.
	settings.is_fullscreen = true
	settings.save_settings()
	settings._sync_window_mode()
	check.expect_false(settings.is_fullscreen, "external fullscreen exit updates live settings")
	settings.toggle_grid()
	var loaded := SettingsService.new()
	loaded.settings_path = settings.settings_path
	loaded.load_settings()
	check.expect_false(loaded.is_fullscreen, "external exit remains saved after another setting changes")
	settings.free()
	loaded.free()

func _malformed_settings_keep_safe_defaults() -> void:
	var config := ConfigFile.new()
	config.set_value("meta", "version", 1)
	config.set_value("audio", "muted", "false")
	config.set_value("audio", "effects_volume_db", Vector2.ONE)
	config.set_value("display", "grid_enabled", [])
	config.save(settings_path)
	var settings := SettingsService.new()
	settings.settings_path = settings_path
	settings.load_settings()
	check.expect_false(settings.is_muted, "strings are not accepted as saved booleans")
	check.expect_equal(settings.effects_volume_db, 0.0, "invalid volume types keep the default")
	check.expect_true(settings.grid_enabled, "invalid grid values keep the default")
	for value in [NAN, INF, -INF]:
		config.set_value("audio", "effects_volume_db", value)
		config.save(settings_path)
		settings.load_settings()
		check.expect_equal(settings.effects_volume_db, 0.0, "non-finite volume keeps the default")
	config.set_value("meta", "version", "1")
	config.set_value("audio", "muted", true)
	config.save(settings_path)
	settings.load_settings()
	check.expect_false(settings.is_muted, "a malformed version is not coerced into a supported version")
	settings.free()

func _legacy_settings_migrate_only_complete_records() -> void:
	var settings := SettingsService.new()
	settings.settings_path = test_files.path("migrated.cfg")
	settings.legacy_settings_path = test_files.path("legacy.dat")
	var file := FileAccess.open(settings.legacy_settings_path, FileAccess.WRITE)
	file.store_8(1)
	file.close()
	settings.load_settings()
	check.expect_false(settings.is_muted, "truncated legacy settings keep defaults")
	check.expect_false(FileAccess.file_exists(settings.settings_path), "truncated legacy data does not block a later migration")
	file = FileAccess.open(settings.legacy_settings_path, FileAccess.WRITE)
	file.store_8(2)
	file.store_8(0)
	file.close()
	settings.load_settings()
	check.expect_false(FileAccess.file_exists(settings.settings_path), "invalid legacy booleans do not create a new settings file")
	file = FileAccess.open(settings.legacy_settings_path, FileAccess.WRITE)
	file.store_8(1)
	file.store_8(0)
	file.close()
	settings.load_settings()
	check.expect_true(settings.is_muted, "a complete legacy record migrates mute")
	check.expect_false(settings.is_fullscreen, "a complete legacy record migrates window mode")
	check.expect_true(FileAccess.file_exists(settings.settings_path), "migration writes the new format")
	settings.free()
