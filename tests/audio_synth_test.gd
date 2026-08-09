extends SceneTree

const AudioServiceScript := preload("res://services/audio_service.gd")

func _initialize() -> void:
	var audio_service := AudioServiceScript.new()

	_expect_tone_stream(audio_service, 210.0, 210.0, 0.044, AudioServiceScript.Waveform.SINE)
	_expect_tone_stream(audio_service, 693.0, 861.0, 0.13, AudioServiceScript.Waveform.TRIANGLE)
	_expect_tone_stream(audio_service, 231.0, 84.0, 0.34, AudioServiceScript.Waveform.SAW)
	_expect_invalid_tone_rejected(audio_service)
	_expect_cached_tones_reused(audio_service)
	_expect_sweep_changes_pcm(audio_service)
	_expect_delayed_movement_progression(audio_service)
	_expect_prewarmed_cues_are_bounded(audio_service)
	_expect_channel_gain_composition(audio_service)
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
	var stream: AudioStreamWAV = audio_service._render_tone_stream(
		start_frequency,
		end_frequency,
		duration,
		waveform
	) as AudioStreamWAV
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
	var invalid_stream: AudioStreamWAV = audio_service._render_tone_stream(
		-1.0,
		210.0,
		0.1,
		AudioServiceScript.Waveform.SINE
	) as AudioStreamWAV
	if invalid_stream != null:
		_fail("Expected invalid tone parameters to be rejected.")

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

func _expect_prewarmed_cues_are_bounded(audio_service: AudioService) -> void:
	audio_service._tone_cache.clear()
	audio_service._tone_cache_order.clear()
	audio_service._prewarm_cues()
	var prewarmed_count := audio_service._tone_cache.size()
	if prewarmed_count > AudioServiceScript.TONE_CACHE_CAPACITY:
		_fail("Expected prewarmed cues to fit within the bounded tone cache.")
		return

	for step in range(AudioServiceScript.MOVE_PROGRESS_STEPS + 1):
		var progress := float(step) / float(AudioServiceScript.MOVE_PROGRESS_STEPS)
		var frequency := audio_service.movement_frequency_for_progress(progress)
		audio_service._get_cached_tone_stream(
			frequency,
			frequency,
			audio_service.movement_duration_for_progress(progress),
			AudioServiceScript.Waveform.SINE
		)
	if audio_service._tone_cache.size() != prewarmed_count:
		_fail("Expected movement playback to reuse the prewarmed pitch buckets.")

func _expect_channel_gain_composition(audio_service: AudioService) -> void:
	audio_service._channel_cue_volume_db.append(-22.0)
	audio_service.set_effects_volume_db(-3.0)
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

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
