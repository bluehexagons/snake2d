extends SceneTree

const MAIN := preload("res://scenes/main/main.tscn")
var check := TestAssertions.new()
var main: Main
var evidence := OS.get_environment("BASALTWATER_TEST_EVIDENCE")
var started_usec := Time.get_ticks_usec()
var sequence := 0
var last_stage := ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var profile := OS.get_environment("BASALTWATER_TEST_PROFILE")
	var ready_file := OS.get_environment("BASALTWATER_TEST_READY_FILE")
	var ready_token := OS.get_environment("BASALTWATER_TEST_READY_TOKEN")
	if profile.is_empty() != evidence.is_empty() or ready_file.is_empty() != ready_token.is_empty() or (
		profile.is_empty() and not ready_file.is_empty()
	) or (
		not profile.is_empty() and (not DirAccess.dir_exists_absolute(profile) or not DirAccess.dir_exists_absolute(evidence))
	):
		push_error("Playtest profile, evidence and optional readiness settings are incomplete.")
		quit(1)
		return
	var temporary: TestFiles = null
	if profile.is_empty():
		temporary = TestFiles.new()
		profile = temporary.directory
	main = MAIN.instantiate() as Main
	(main.get_node("Services/HighScoreStore") as HighScoreStore).save_path = profile.path_join("scores.dat")
	var settings := main.get_node("Services/SettingsService") as SettingsService
	settings.settings_path = profile.path_join("settings.cfg")
	settings.legacy_settings_path = profile.path_join("legacy.dat")
	root.add_child(main)
	var random := RandomNumberGenerator.new()
	random.seed = 424242
	main.gameplay.set_random_number_generator(random)
	main.ui_state_manager.set_reduced_motion(true)
	await process_frame
	check.expect_equal(main.game_session.state, GameSession.State.MAIN_MENU, "the disposable game opens at the menu")
	await _record("ready")
	if not ready_file.is_empty() and check.failure_count == 0:
		check.expect_true(_publish_json(ready_file, {"Token": ready_token}), "publish the readiness token atomically")
	if check.failure_count > 0:
		_finish(temporary)
		return
	if not ready_file.is_empty():
		# Leave the process live long enough for the guardian to acknowledge it.
		await create_timer(2.0).timeout

	_key(KEY_ENTER)
	check.expect_equal(main.game_session.state, GameSession.State.PLAYING, "Play starts Classic")
	check.expect_true(main.gameplay.is_waiting_for_input(), "the new round waits for a direction")
	await _record("started")
	if check.failure_count > 0:
		_finish(temporary)
		return
	var game := main.gameplay
	_key(KEY_RIGHT)
	game.advance_one_tick_and_snap()
	_key(KEY_P)
	check.expect_equal(main.game_session.state, GameSession.State.PAUSED, "P pauses a moving round")
	var before := game.model.tick_count
	await _record("paused")
	await physics_frame
	check.expect_equal(game.model.tick_count, before, "the paused round freezes")
	_key(KEY_ESCAPE)
	check.expect_equal(main.game_session.state, GameSession.State.PLAYING, "Escape resumes a paused round")
	await _record("resumed", false)
	for step in main.game_rules.columns:
		if main.game_session.state != GameSession.State.PLAYING:
			break
		game.advance_one_tick_and_snap()
	check.expect_equal(main.game_session.state, GameSession.State.GAME_OVER, "a straight run reaches the wall")
	check.expect_equal(game.get_round_result(), SnakeGame.StepResult.HIT_WALL, "the results identify a wall collision")
	await _record("game-over")
	_key(KEY_ENTER)
	check.expect_true(main.game_session.state == GameSession.State.PLAYING and game.is_waiting_for_input(),
		"Play Again starts a fresh round")
	await _record("retried")
	main.game_session.return_to_menu()
	await main.audio_service.drain_for_quit()
	if check.failure_count == 0:
		await _record("finished", false)
	_finish(temporary)

func _finish(temporary: TestFiles) -> void:
	if not evidence.is_empty():
		var summary := {
			"schema_version": 1,
			"passed": check.failure_count == 0,
			"failed_assertions": check.failure_count,
			"last_stage": last_stage,
			"milestone_count": sequence,
			"elapsed_us": Time.get_ticks_usec() - started_usec,
		}
		check.expect_true(_publish_json(evidence.path_join("scenario-result.json"), summary),
			"publish the terminal scenario summary atomically")
	main.free()
	if temporary != null:
		temporary.cleanup()
	check.finish(self, "Native playtest test")

func _publish_json(path: String, value: Dictionary) -> bool:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(value))
	var written := file.get_error() == OK
	file.close()
	return written and DirAccess.rename_absolute(path + ".tmp", path) == OK

func _record(stage: String, capture := true) -> void:
	if evidence.is_empty():
		return
	var artifact := ""
	if capture and DisplayServer.get_name() != "headless":
		artifact = "%02d-%s.png" % [sequence, stage]
		RenderingServer.force_draw.call_deferred()
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		var result := image.save_png(evidence.path_join(artifact)) if image != null else ERR_CANT_CREATE
		check.expect_equal(result, OK, "save the rendered %s milestone" % stage)
		if result != OK:
			artifact = ""
	var path := evidence.path_join("milestones.jsonl")
	var file := FileAccess.open(path, FileAccess.WRITE if sequence == 0 else FileAccess.READ_WRITE)
	if file == null:
		check.expect_true(false, "open milestone evidence")
		return
	file.seek_end()
	file.store_line(JSON.stringify({"schema_version": 1, "sequence": sequence, "stage": stage,
		"elapsed_us": Time.get_ticks_usec() - started_usec, "unix_seconds": Time.get_unix_time_from_system(),
		"capture": artifact}))
	var error := file.get_error()
	check.expect_equal(error, OK, "write milestone evidence")
	file.close()
	if error == OK:
		sequence += 1
		last_stage = stage

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate() as InputEventKey
	event.pressed = false
	root.push_input(event, true)
