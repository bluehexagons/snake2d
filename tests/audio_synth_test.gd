extends SceneTree

const AudioServiceScript := preload("res://services/audio_service.gd")
const TestAssertionsScript := preload("res://tests/test_assertions.gd")

var check := TestAssertionsScript.new()

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var audio_service := AudioServiceScript.new()

	_expect_tone_stream(audio_service, 210.0, 210.0, 0.044, AudioServiceScript.Waveform.SINE)
	_expect_tone_stream(audio_service, 210.0, 210.0, 0.044, AudioServiceScript.Waveform.SQUARE)
	_expect_tone_stream(audio_service, 693.0, 861.0, 0.13, AudioServiceScript.Waveform.TRIANGLE)
	_expect_tone_stream(audio_service, 231.0, 84.0, 0.34, AudioServiceScript.Waveform.SAW)
	_expect_tone_stream(audio_service, 693.0, 924.0, 0.115, AudioServiceScript.Waveform.CHIME)
	_expect_tone_stream(audio_service, 281.0, 151.0, 0.235, AudioServiceScript.Waveform.ROUNDED_BUZZ)
	for cue: Vector2 in [
		Vector2(AudioServiceScript.CLICK_FREQUENCY, AudioServiceScript.CLICK_TONE_SECONDS),
		Vector2(AudioServiceScript.FOCUS_FREQUENCY, AudioServiceScript.FOCUS_TONE_SECONDS),
	]:
		_expect_tone_stream(audio_service, cue.x, cue.x, cue.y, AudioServiceScript.Waveform.TRIANGLE)
	_expect_waveform_coefficients(audio_service)
	_expect_partial_fades_at_nyquist(audio_service)
	_expect_invalid_tone_rejected(audio_service)
	_expect_cached_tones_reused(audio_service)
	_expect_cache_uses_rendered_length(audio_service)
	_expect_cache_evicts_least_recently_used(audio_service)
	_expect_sweep_changes_pcm(audio_service)
	_expect_delayed_movement_progression(audio_service)
	_expect_movement_cues_are_cached_on_demand(audio_service)
	await _expect_gain_changes_apply_at_onset()
	_expect_voice_budget(audio_service)
	await _expect_menu_cues_do_not_stack()
	await _expect_move_cues_do_not_stack()
	await _expect_pickup_ducks_new_movement()
	_expect_voice_pool_reused()
	await _expect_shutdown_releases_playback()
	audio_service.free()

	check.finish(self, "Audio synth test")

func _expect_tone_stream(
	audio_service: AudioService,
	start_frequency: float,
	end_frequency: float,
	duration: float,
	waveform: AudioServiceScript.Waveform
) -> void:
	var stream := audio_service._get_cached_tone_stream(
		start_frequency,
		end_frequency,
		duration,
		waveform
	)
	if stream == null:
		_fail("Expected a rendered tone stream.")
		return

	var sample_count := int(duration * AudioServiceScript.SAMPLE_HZ)
	var expected_byte_count := sample_count * AudioServiceScript.PCM_16_BYTES_PER_SAMPLE
	if stream.data.size() != expected_byte_count:
		_fail("Expected rendered tone byte count to match duration.")
		return

	var peak := 0
	var first_sample: int = abs(int(stream.data.decode_s16(0)))
	var last_sample: int = abs(int(stream.data.decode_s16(stream.data.size() - AudioServiceScript.PCM_16_BYTES_PER_SAMPLE)))
	var max_allowed := int(AudioServiceScript.TONE_RENDER_PEAK * AudioServiceScript.PCM_16_SCALE)
	var edge_bytes := int(AudioServiceScript.SAMPLE_HZ * 0.0002) * AudioServiceScript.PCM_16_BYTES_PER_SAMPLE

	for offset in range(0, stream.data.size(), AudioServiceScript.PCM_16_BYTES_PER_SAMPLE):
		var sample: int = abs(int(stream.data.decode_s16(offset)))
		peak = maxi(peak, sample)
		if sample > max_allowed:
			_fail("Expected rendered tone samples to stay below the synth clip ceiling.")
			return
		if (offset < edge_bytes or offset >= stream.data.size() - edge_bytes) and sample > max_allowed * 0.01:
			_fail("Expected the first and last 0.2 ms to stay below one percent of the PCM peak ceiling.")
			return

	if first_sample > 1 or last_sample > 1:
		_fail("Expected rendered tone to start and end at zero amplitude.")
		return

	if peak < 0.9 * max_allowed:
		_fail("Expected full-length cues to reach a consistent PCM peak across waveforms.")

func _expect_waveform_coefficients(audio_service: AudioService) -> void:
	var square := audio_service._wave_sample(PI * 0.5, 210.0, AudioServiceScript.Waveform.SQUARE)
	var triangle := audio_service._wave_sample(PI * 0.5, 210.0, AudioServiceScript.Waveform.TRIANGLE)
	var saw := audio_service._wave_sample(PI * 0.5, 210.0, AudioServiceScript.Waveform.SAW)
	check.expect_true(absf(square - 1.0) < 0.05, "square midpoint is close to +1")
	check.expect_true(absf(triangle - 1.0) < 0.05, "triangle apex is close to +1")
	check.expect_true(absf(saw - 0.5) < 0.05, "descending saw is close to +0.5 at quarter phase")

func _expect_partial_fades_at_nyquist(audio_service: AudioService) -> void:
	var waveform := AudioServiceScript.Waveform.SQUARE
	var phase := PI / 6.0
	var fade_start := AudioServiceScript.HARMONIC_FADE_START_HZ / 3.0
	var cutoff := AudioServiceScript.NYQUIST_HZ / 3.0
	var full := audio_service._wave_sample(phase, fade_start, waveform)
	var halfway := audio_service._wave_sample(phase, lerpf(fade_start, cutoff, 0.5), waveform)
	var fundamental := 8.0 / TAU * sin(phase)
	var just_below_cutoff := audio_service._wave_sample(phase, cutoff - 1.0, waveform)
	check.expect_true(is_equal_approx(full, fundamental + 8.0 / TAU / 3.0), "third partial below taper")
	check.expect_true(is_equal_approx(halfway, lerpf(full, fundamental, 0.5)), "third partial halfway through taper")
	check.expect_true(absf(just_below_cutoff - fundamental) < 0.00001, "third partial fades before Nyquist")
	check.expect_true(is_equal_approx(audio_service._wave_sample(phase, cutoff, waveform), fundamental), "third partial at Nyquist is silent")

func _expect_invalid_tone_rejected(audio_service: AudioService) -> void:
	var waveform := AudioServiceScript.Waveform.SINE
	for invalid_frequency: float in [-1.0, 0.0, INF, -INF, NAN]:
		if audio_service._get_cached_tone_stream(invalid_frequency, 210.0, 0.1, waveform) != null:
			_fail("Expected invalid start frequencies to be rejected.")
		if audio_service._get_cached_tone_stream(210.0, invalid_frequency, 0.1, waveform) != null:
			_fail("Expected invalid end frequencies to be rejected.")
	for invalid_duration: float in [0.0, 0.00001, 1.01, INF, NAN]:
		if audio_service._get_cached_tone_stream(210.0, 210.0, invalid_duration, waveform) != null:
			_fail("Expected invalid durations to be rejected before allocation.")

func _expect_cache_uses_rendered_length(audio_service: AudioService) -> void:
	var waveform := AudioServiceScript.Waveform.SINE
	var short := audio_service._get_cached_tone_stream(210.0, 210.0, 0.1, waveform)
	var long := audio_service._get_cached_tone_stream(210.0, 210.0, 0.10004, waveform)
	var same_length := audio_service._get_cached_tone_stream(210.0, 210.0, 0.10001, waveform)
	if short == null or long == null or long.data.size() != short.data.size() + 2:
		_fail("Expected nearby durations with different sample counts to render separately.")
	if short != same_length:
		_fail("Expected matching sample counts to reuse a cached stream.")

	var limit := AudioServiceScript.MAX_TONE_FREQUENCY_HZ
	var capped := audio_service._get_cached_tone_stream(limit, limit, 0.1, waveform)
	var above_cap := audio_service._get_cached_tone_stream(1.0e100, 3.0e100, 0.1, waveform)
	if capped == null or capped != above_cap:
		_fail("Expected frequencies above the render limit to share a cache entry.")

func _expect_cache_evicts_least_recently_used(audio_service: AudioService) -> void:
	audio_service._tone_cache.clear()
	audio_service._tone_cache_order.clear()
	var waveform := AudioServiceScript.Waveform.SINE
	var first := audio_service._get_cached_tone_stream(100.0, 100.0, 0.001, waveform)
	var second := audio_service._get_cached_tone_stream(102.0, 102.0, 0.001, waveform)
	for i in range(2, AudioServiceScript.TONE_CACHE_CAPACITY):
		var frequency := 100.0 + i * 2.0
		audio_service._get_cached_tone_stream(frequency, frequency, 0.001, waveform)
	audio_service._get_cached_tone_stream(100.0, 100.0, 0.001, waveform)
	audio_service._get_cached_tone_stream(1000.0, 1000.0, 0.001, waveform)
	if audio_service._tone_cache.size() != AudioServiceScript.TONE_CACHE_CAPACITY:
		_fail("Expected the tone cache to stay within capacity.")
	if first != audio_service._get_cached_tone_stream(100.0, 100.0, 0.001, waveform):
		_fail("Expected a recently used stream to survive cache eviction.")
	if second == audio_service._get_cached_tone_stream(102.0, 102.0, 0.001, waveform):
		_fail("Expected the least recently used stream to be evicted.")

func _expect_cached_tones_reused(audio_service: AudioService) -> void:
	var first := audio_service._get_cached_tone_stream(
		210.1,
		210.1,
		AudioServiceScript.MOVE_START_DURATION_SECONDS,
		AudioServiceScript.Waveform.SINE
	)
	var same_pitch_bucket := audio_service._get_cached_tone_stream(
		210.5,
		210.5,
		AudioServiceScript.MOVE_START_DURATION_SECONDS,
		AudioServiceScript.Waveform.SINE
	)
	var different_waveform := audio_service._get_cached_tone_stream(
		210.1,
		210.1,
		AudioServiceScript.MOVE_START_DURATION_SECONDS,
		AudioServiceScript.Waveform.TRIANGLE
	)
	if first == null or same_pitch_bucket == null or different_waveform == null:
		_fail("Expected valid cached tones to render.")
		return
	if first != same_pitch_bucket:
		_fail("Expected nearby frequencies to reuse a quantized PCM stream.")
		return
	if first == different_waveform:
		_fail("Expected waveform type to remain part of the tone cache key.")

func _expect_sweep_changes_pcm(audio_service: AudioService) -> void:
	var fixed := audio_service._get_cached_tone_stream(
		210.0,
		210.0,
		0.1,
		AudioServiceScript.Waveform.SINE
	)
	var sweep := audio_service._get_cached_tone_stream(
		210.0,
		420.0,
		0.1,
		AudioServiceScript.Waveform.SINE
	)
	if fixed == null or sweep == null:
		_fail("Expected fixed and swept tones to render.")
		return
	if fixed == sweep or fixed.data == sweep.data:
		_fail("Expected a frequency sweep to have distinct cached PCM data.")
		return

	# These positions are within the sustain, where the integrated sweep is unscaled
	# apart from the shared PCM gain.
	var final_sample := sweep.data.size() / float(AudioServiceScript.PCM_16_BYTES_PER_SAMPLE) - 1.0
	for index: int in [400, 1000, 2500]:
		var time := index / AudioServiceScript.SAMPLE_HZ
		var average_frequency := lerpf(210.0, 420.0, 0.5 * index / final_sample)
		var expected := int(
			sin(TAU * time * average_frequency)
			* AudioServiceScript.TONE_RENDER_PEAK * AudioServiceScript.PCM_16_SCALE
		)
		var actual := sweep.data.decode_s16(index * AudioServiceScript.PCM_16_BYTES_PER_SAMPLE)
		check.expect_true(absi(actual - expected) <= 1, "sine sweep keeps phase at sample %d" % index)

func _expect_delayed_movement_progression(audio_service: AudioService) -> void:
	var start_frequency := audio_service.movement_frequency_for_progress(0.0)
	var midpoint_frequency := audio_service.movement_frequency_for_progress(0.5)
	var end_frequency := audio_service.movement_frequency_for_progress(1.0)
	var logarithmic_midpoint := sqrt(
		AudioServiceScript.MOVE_START_FREQUENCY * AudioServiceScript.MOVE_END_FREQUENCY
	)

	if not is_equal_approx(start_frequency, AudioServiceScript.MOVE_START_FREQUENCY):
		_fail("Expected movement to begin at its configured low pitch.")
	if not is_equal_approx(end_frequency, AudioServiceScript.MOVE_END_FREQUENCY):
		_fail("Expected movement to reach its configured high pitch only at full speed.")
	if midpoint_frequency >= logarithmic_midpoint:
		_fail("Expected the movement pitch curve to defer most of its rise until late game.")

	var previous_frequency := start_frequency
	for step in range(1, AudioServiceScript.MOVE_PROGRESS_STEPS + 1):
		var progress := float(step) / float(AudioServiceScript.MOVE_PROGRESS_STEPS)
		var frequency := audio_service.movement_frequency_for_progress(progress)
		if frequency < previous_frequency:
			_fail("Expected movement pitch to rise monotonically with game speed.")
			break
		previous_frequency = frequency

	var start_volume := audio_service.movement_volume_db_for_progress(0.0)
	var end_volume := audio_service.movement_volume_db_for_progress(1.0)
	if not is_equal_approx(start_volume, AudioServiceScript.MOVE_START_VOLUME_DB):
		_fail("Expected movement to begin at its configured volume.")
	if not is_equal_approx(end_volume, AudioServiceScript.MOVE_END_VOLUME_DB):
		_fail("Expected movement to end at its configured volume.")
	if end_volume >= start_volume:
		_fail("Expected faster, denser movement cues to become quieter.")
	if (
		audio_service.movement_duration_for_progress(1.0)
		>= audio_service.movement_duration_for_progress(0.0)
	):
		_fail("Expected faster movement cues to become shorter.")

func _expect_movement_cues_are_cached_on_demand(audio_service: AudioService) -> void:
	audio_service._tone_cache.clear()
	audio_service._tone_cache_order.clear()
	audio_service._prewarm_fixed_cues()
	var prewarmed_count := audio_service._tone_cache.size()
	if prewarmed_count != 4:
		_fail("Expected startup to prewarm only the four fixed cues.")
		return

	for step in range(AudioServiceScript.MOVE_PROGRESS_STEPS + 1):
		var progress := float(step) / float(AudioServiceScript.MOVE_PROGRESS_STEPS)
		var frequency := audio_service.movement_frequency_for_progress(progress)
		var duration := audio_service.movement_duration_for_progress(progress)
		var waveform := AudioServiceScript.Waveform.SINE
		var stream := audio_service._get_cached_tone_stream(
			frequency,
			frequency,
			duration,
			waveform
		)
		if stream == null or stream != audio_service._get_cached_tone_stream(frequency, frequency, duration, waveform):
			_fail("Expected each movement cue to reuse its cached stream.")
			return
	if audio_service._tone_cache.size() > AudioServiceScript.TONE_CACHE_CAPACITY:
		_fail("Expected all speed buckets to fit within the bounded tone cache.")

func _expect_gain_changes_apply_at_onset() -> void:
	var audio_service := AudioServiceScript.new()
	root.add_child(audio_service)
	audio_service._ensure_audio_players()
	audio_service.play_eat()
	var pickup := audio_service.audio_players[0]
	audio_service.set_effects_volume_db(-12.0)
	audio_service.set_effects_volume_db(NAN)
	audio_service.play_click()
	var click := audio_service.audio_players[1]
	check.expect_equal(click.volume_db, AudioServiceScript.CLICK_VOLUME_DB - 12.0,
		"the next cue uses the new effects volume")
	audio_service.set_muted(true)
	audio_service.play_focus()
	check.expect_false(audio_service.audio_players[2].playing, "mute blocks new cues")
	check.expect_true(pickup.playing, "mute lets an active cue reach its release envelope")
	check.expect_equal(pickup.volume_db, AudioServiceScript.EAT_VOLUME_DB,
		"volume and mute leave the active pickup at its starting gain")
	audio_service.set_muted(false)
	audio_service.play_focus()
	check.expect_equal(audio_service.audio_players[2].volume_db, AudioServiceScript.FOCUS_VOLUME_DB - 12.0,
		"unmute resumes new playback at the selected volume")
	await audio_service.drain_for_quit()
	audio_service.free()

func _expect_voice_budget(audio_service: AudioService) -> void:
	audio_service.set_muted(false)
	audio_service.set_effects_volume_db(0.0)
	const LOUD_REQUEST_DB := 20.0
	var peak_sum := 0.0
	for channel in range(AudioServiceScript.CHANNEL_COUNT):
		peak_sum += AudioServiceScript.TONE_RENDER_PEAK * db_to_linear(
			audio_service._volume_db_for_channel(channel, LOUD_REQUEST_DB)
		)
	check.expect_true(peak_sum < db_to_linear(-2.0), "all voices combined leave 2 dB of sample headroom")
	check.expect_equal(
		audio_service._volume_db_for_channel(AudioServiceScript.CHANNEL_COUNT - 1, LOUD_REQUEST_DB),
		AudioServiceScript.DIE_VOLUME_DB,
		"the reserved voice keeps the death cue's gain"
	)

func _expect_menu_cues_do_not_stack() -> void:
	var audio_service := AudioServiceScript.new()
	root.add_child(audio_service)
	audio_service._ensure_audio_players()
	for repeat in range(3):
		audio_service.play_focus()
		audio_service.play_click()
	var focus := audio_service.audio_players[0]
	var click := audio_service.audio_players[1]
	check.expect_true(focus.playing and click.playing, "focus and click still play together")
	check.expect_false(audio_service.audio_players[2].playing, "identical menu cues do not stack")
	focus.stop()
	audio_service.play_focus()
	check.expect_true(audio_service.audio_players[2].playing, "focus can play after its previous cue ends")
	await audio_service.drain_for_quit()
	audio_service.free()

func _expect_move_cues_do_not_stack() -> void:
	var audio_service := AudioServiceScript.new()
	root.add_child(audio_service)
	audio_service._ensure_audio_players()

	for step in range(4):
		audio_service.play_move(float(step) / AudioServiceScript.MOVE_PROGRESS_STEPS)
	var first_voice := audio_service.audio_players.front() as AudioStreamPlayer
	var active := audio_service.audio_players.filter(
		func(player: AudioStreamPlayer) -> bool: return player.playing
	)
	check.expect_equal(active, [first_voice], "catch-up moves share a single cue")

	audio_service.play_die()
	check.expect_true(audio_service.audio_players.back().playing, "death can still play over a movement cue")
	# Make voice retirement independent of the headless mixer's wall-clock timing.
	first_voice.stop()
	audio_service.play_move(1.0)
	var next_move := audio_service.audio_players[1]
	check.expect_true(next_move.playing, "movement can play again after its voice stops")
	check.expect_equal(
		next_move.volume_db,
		AudioServiceScript.MOVE_END_VOLUME_DB + AudioServiceScript.MOVE_DUCK_DB,
		"active collision lowers new movement taps"
	)
	audio_service.free()
	await create_timer(0.3).timeout

func _expect_pickup_ducks_new_movement() -> void:
	var audio_service := AudioServiceScript.new()
	root.add_child(audio_service)
	audio_service._ensure_audio_players()
	var normal_gain := audio_service.movement_volume_db_for_progress(0.0)
	audio_service.play_move(0.0)
	var first_move := audio_service.audio_players[0]
	audio_service.play_eat()
	var pickup := audio_service.audio_players[1]
	check.expect_equal(first_move.volume_db, normal_gain, "pickup preserves a tap in progress")
	check.expect_equal(pickup.volume_db, AudioServiceScript.EAT_VOLUME_DB, "pickup retains its cue gain")
	first_move.stop()
	audio_service.play_move(0.0)
	var ducked_move := audio_service.audio_players[2]
	check.expect_equal(ducked_move.volume_db, normal_gain + AudioServiceScript.MOVE_DUCK_DB,
		"movement starts quieter while food is playing")
	pickup.stop()
	ducked_move.stop()
	audio_service.play_move(0.0)
	check.expect_equal(audio_service.audio_players[3].volume_db, normal_gain,
		"movement returns to normal once the pickup stops")
	await audio_service.drain_for_quit()
	audio_service.free()

func _expect_voice_pool_reused() -> void:
	var audio_service := AudioServiceScript.new()
	root.add_child(audio_service)
	audio_service._ensure_audio_players()
	var first_player := audio_service.audio_players.front() as AudioStreamPlayer
	first_player.stream = audio_service._get_cached_tone_stream(
		210.0, 210.0, 0.1, AudioServiceScript.Waveform.SINE
	)
	root.remove_child(audio_service)
	if first_player.stream != null:
		_fail("Expected detaching the service to release the assigned stream.")

	root.add_child(audio_service)
	audio_service._ensure_audio_players()
	if (
		audio_service.get_child_count() != AudioServiceScript.CHANNEL_COUNT
		or audio_service.audio_players.front() != first_player
	):
		_fail("Expected reattaching the service to reuse its existing voice pool.")
	audio_service.free()

func _expect_shutdown_releases_playback() -> void:
	var audio_service := AudioServiceScript.new()
	root.add_child(audio_service)
	audio_service._ensure_audio_players()
	audio_service.play_die()
	var voice := audio_service.audio_players.back() as AudioStreamPlayer
	check.expect_true(voice.playing, "the death cue plays before shutdown")
	var started_usec := Time.get_ticks_usec()
	await audio_service.drain_for_quit()
	var elapsed_seconds := (Time.get_ticks_usec() - started_usec) / 1_000_000.0
	check.expect_true(elapsed_seconds >= AudioServiceScript.SHUTDOWN_DRAIN_SECONDS,
		"stopped voices get the full wall-clock drain interval")
	check.expect_equal(voice.stream, null, "shutdown releases the active stream")
	audio_service.play_die()
	check.expect_false(voice.playing, "new cues cannot start during shutdown")
	audio_service.free()

func _fail(message: String) -> void:
	check.expect_true(false, message)
