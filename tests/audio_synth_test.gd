extends SceneTree

const AudioServiceScript := preload("res://services/audio_service.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var audio_service := AudioServiceScript.new()

	_expect_tone_stream(audio_service, 210.0, 210.0, 0.044, AudioServiceScript.Waveform.SINE)
	_expect_tone_stream(audio_service, 693.0, 861.0, 0.13, AudioServiceScript.Waveform.TRIANGLE)
	_expect_tone_stream(audio_service, 231.0, 84.0, 0.34, AudioServiceScript.Waveform.SAW)
	_expect_invalid_tone_rejected(audio_service)
	_expect_cached_tones_reused(audio_service)
	_expect_cache_uses_rendered_length(audio_service)
	_expect_cache_evicts_least_recently_used(audio_service)
	_expect_sweep_changes_pcm(audio_service)
	_expect_delayed_movement_progression(audio_service)
	_expect_movement_cues_are_cached_on_demand(audio_service)
	_expect_channel_gain_composition(audio_service)
	await _expect_voice_pool_reused()
	audio_service.free()

	print("Audio synth test passed.")
	quit()

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
	var max_allowed := int(AudioServiceScript.MAX_SAMPLE_AMPLITUDE * AudioServiceScript.PCM_16_SCALE)

	for offset in range(0, stream.data.size(), AudioServiceScript.PCM_16_BYTES_PER_SAMPLE):
		var sample: int = abs(int(stream.data.decode_s16(offset)))
		peak = maxi(peak, sample)
		if sample > max_allowed:
			_fail("Expected rendered tone samples to stay below the synth clip ceiling.")
			return

	if first_sample > 1 or last_sample > 1:
		_fail("Expected rendered tone to start and end at zero amplitude.")
		return

	if peak <= 32:
		_fail("Expected rendered tone to contain audible sample data.")

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

func _expect_channel_gain_composition(audio_service: AudioService) -> void:
	audio_service._channel_cue_volume_db.append(-22.0)
	audio_service.set_effects_volume_db(-3.0)
	audio_service.set_effects_volume_db(NAN)
	var expected_volume := (
		AudioServiceScript.MASTER_GAIN_DB
		- 3.0
		- 22.0
		- AudioServiceScript.TONE_RENDER_HEADROOM_DB
	)
	if not is_equal_approx(audio_service._volume_db_for_channel(0), expected_volume):
		_fail("Expected cue and settings gain to be composed at playback time.")
	audio_service.set_muted(true)
	if audio_service._volume_db_for_channel(0) > -900.0:
		_fail("Expected mute to silence a channel without changing its cue gain.")

func _expect_voice_pool_reused() -> void:
	var audio_service := AudioServiceScript.new()
	root.add_child(audio_service)
	audio_service._ensure_audio_players()
	var first_player := audio_service.audio_players.front() as AudioStreamPlayer
	first_player.stream = audio_service._get_cached_tone_stream(
		210.0, 210.0, 0.1, AudioServiceScript.Waveform.SINE
	)
	first_player.play()

	root.remove_child(audio_service)
	if first_player.playing or first_player.stream != null:
		_fail("Expected detaching the service to stop playback and release the stream.")

	root.add_child(audio_service)
	audio_service._ensure_audio_players()
	if (
		audio_service.get_child_count() != AudioServiceScript.CHANNEL_COUNT
		or audio_service.audio_players.front() != first_player
	):
		_fail("Expected reattaching the service to reuse its existing voice pool.")
	audio_service.free()
	# Let the mixer retire the stopped playback before shutting down the engine.
	await create_timer(0.1).timeout

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
