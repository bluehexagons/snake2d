extends SceneTree

const AudioManagerScript := preload("res://autoload/audio_manager.gd")

func _initialize() -> void:
	var audio_manager := AudioManagerScript.new()

	_expect_tone_stream(audio_manager, 210.0, 0.045, -20.0, AudioManagerScript.Waveform.SINE)
	_expect_tone_stream(audio_manager, 798.0, 0.13, -16.0, AudioManagerScript.Waveform.TRIANGLE)
	_expect_tone_stream(audio_manager, 210.0, 0.3, -4.5, AudioManagerScript.Waveform.SAW)
	_expect_invalid_tone_rejected(audio_manager)
	audio_manager.free()

	print("Audio synth test passed.")
	quit()

func _expect_tone_stream(
	audio_manager: Node,
	frequency: float,
	duration: float,
	volume_db: float,
	waveform: AudioManagerScript.Waveform
) -> void:
	var stream: AudioStreamWAV = audio_manager._render_tone_stream(
		frequency,
		duration,
		db_to_linear(volume_db),
		waveform
	) as AudioStreamWAV
	if stream == null:
		_fail("Expected a rendered tone stream.")
		return

	var sample_count := int(duration * AudioManagerScript.SAMPLE_HZ)
	var expected_byte_count := sample_count * AudioManagerScript.PCM_16_BYTES_PER_SAMPLE
	if stream.data.size() != expected_byte_count:
		_fail("Expected rendered tone byte count to match duration.")
		return

	var peak := 0
	var first_sample: int = abs(int(stream.data.decode_s16(0)))
	var last_sample: int = abs(int(stream.data.decode_s16(stream.data.size() - AudioManagerScript.PCM_16_BYTES_PER_SAMPLE)))
	var max_allowed := int(AudioManagerScript.MAX_SAMPLE_AMPLITUDE * AudioManagerScript.PCM_16_SCALE)

	for offset in range(0, stream.data.size(), AudioManagerScript.PCM_16_BYTES_PER_SAMPLE):
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

func _expect_invalid_tone_rejected(audio_manager: Node) -> void:
	var invalid_stream: AudioStreamWAV = audio_manager._render_tone_stream(
		-1.0,
		0.1,
		db_to_linear(-12.0),
		AudioManagerScript.Waveform.SINE
	) as AudioStreamWAV
	if invalid_stream != null:
		_fail("Expected invalid tone parameters to be rejected.")

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
