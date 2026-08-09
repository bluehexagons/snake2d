extends SceneTree

const AudioServiceScript := preload("res://services/audio_service.gd")

func _initialize() -> void:
	var audio_service := AudioServiceScript.new()

	_expect_tone_stream(audio_service, 210.0, 0.045, -20.0, AudioServiceScript.Waveform.SINE)
	_expect_tone_stream(audio_service, 798.0, 0.13, -16.0, AudioServiceScript.Waveform.TRIANGLE)
	_expect_tone_stream(audio_service, 210.0, 0.3, -4.5, AudioServiceScript.Waveform.SAW)
	_expect_invalid_tone_rejected(audio_service)
	_expect_cached_tones_reused(audio_service)
	audio_service.free()

	print("Audio synth test passed.")
	quit()

func _expect_tone_stream(
	audio_service: AudioService,
	frequency: float,
	duration: float,
	volume_db: float,
	waveform: AudioServiceScript.Waveform
) -> void:
	var stream: AudioStreamWAV = audio_service._render_tone_stream(
		frequency,
		duration,
		db_to_linear(volume_db),
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
		0.1,
		db_to_linear(-12.0),
		AudioServiceScript.Waveform.SINE
	) as AudioStreamWAV
	if invalid_stream != null:
		_fail("Expected invalid tone parameters to be rejected.")

func _expect_cached_tones_reused(audio_service: AudioService) -> void:
	var first := audio_service._get_cached_tone_stream(
		210.1,
		AudioServiceScript.MOVE_TONE_SECONDS,
		db_to_linear(-20.0),
		AudioServiceScript.Waveform.SINE
	)
	var same_pitch_bucket := audio_service._get_cached_tone_stream(
		210.5,
		AudioServiceScript.MOVE_TONE_SECONDS,
		db_to_linear(-20.0),
		AudioServiceScript.Waveform.SINE
	)
	var different_waveform := audio_service._get_cached_tone_stream(
		210.1,
		AudioServiceScript.MOVE_TONE_SECONDS,
		db_to_linear(-20.0),
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

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
