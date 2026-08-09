class_name AudioService
extends Node

## An explicitly owned service for procedural sound synthesis and playback.
## Main composes this node and supplies it only to components that need audio behavior.

enum Waveform {SINE, SQUARE, TRIANGLE, SAW}
enum VoiceGroup {GENERAL, CRITICAL}

const AppConstants = preload("res://core/app_constants.gd")
const CHANNEL_COUNT := 12
const CRITICAL_CHANNEL_COUNT := 1
const SAMPLE_HZ := 44100.0
const ATTACK_SECONDS := 0.004
const RELEASE_SECONDS := 0.012
const MASTER_GAIN_DB := -12.0
const SOFT_CLIP_DRIVE := 1.15
const PCM_16_SCALE := 32767.0
const PCM_16_BYTES_PER_SAMPLE := 2
const MAX_SAMPLE_AMPLITUDE := 0.98

const SYNTH_BUS_NAME := "SynthSfx"
const LIMITER_CEILING_DB := -1.0
const LIMITER_THRESHOLD_DB := -7.0
const LIMITER_SOFT_CLIP_DB := 2.0
const LIMITER_SOFT_CLIP_RATIO := 8.0

const PITCH_ACCELERATION := 0.04
const PITCH_DAMPING := 0.9
const PITCH_RANGE := 0.95
const PITCH_VARIATION := 0.04
const MOVE_TONE_SECONDS := 0.045
const TONE_CACHE_FREQUENCY_STEP_HZ := 2.0
const TONE_CACHE_CAPACITY := 128

var audio_players: Array[AudioStreamPlayer] = []
var next_general_channel_index := 0
var _tone_cache: Dictionary[String, AudioStreamWAV] = {}
var _tone_cache_order: Array[String] = []

var is_muted := false
var effects_volume_db := 0.0
var current_pitch_momentum := 0.0
var target_pitch_offset := 0.0

func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		_ensure_audio_players()
		_prewarm_fixed_tones()
	_update_players()

func _ensure_audio_players() -> void:
	if not audio_players.is_empty():
		return

	_ensure_synth_bus()
	for i in range(CHANNEL_COUNT):
		var player := AudioStreamPlayer.new()
		player.bus = _get_synth_bus_name()
		player.finished.connect(_on_audio_player_finished.bind(player))
		add_child(player)

		audio_players.append(player)

	_update_players()

func _exit_tree() -> void:
	for player in audio_players:
		player.stop()
		player.stream = null
	audio_players.clear()
	_tone_cache.clear()
	_tone_cache_order.clear()

func _ensure_synth_bus() -> void:
	var bus_index := AudioServer.get_bus_index(SYNTH_BUS_NAME)
	if bus_index == -1:
		AudioServer.add_bus(AudioServer.get_bus_count())
		bus_index = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(bus_index, SYNTH_BUS_NAME)
		AudioServer.set_bus_send(bus_index, "Master")

	AudioServer.set_bus_volume_db(bus_index, 0.0)
	_configure_limiter(bus_index)

func _configure_limiter(bus_index: int) -> void:
	for i in range(AudioServer.get_bus_effect_count(bus_index)):
		var existing_limiter := AudioServer.get_bus_effect(bus_index, i) as AudioEffectLimiter
		if existing_limiter:
			_apply_limiter_settings(existing_limiter)
			return

	var limiter := AudioEffectLimiter.new()
	_apply_limiter_settings(limiter)
	AudioServer.add_bus_effect(bus_index, limiter, 0)

func _apply_limiter_settings(limiter: AudioEffectLimiter) -> void:
	limiter.ceiling_db = LIMITER_CEILING_DB
	limiter.threshold_db = LIMITER_THRESHOLD_DB
	limiter.soft_clip_db = LIMITER_SOFT_CLIP_DB
	limiter.soft_clip_ratio = LIMITER_SOFT_CLIP_RATIO

func _get_synth_bus_name() -> StringName:
	return StringName(SYNTH_BUS_NAME if AudioServer.get_bus_index(SYNTH_BUS_NAME) != -1 else "Master")

func _on_audio_player_finished(player: AudioStreamPlayer) -> void:
	player.stream = null

func _update_players() -> void:
	for player in audio_players:
		player.bus = _get_synth_bus_name()
		player.volume_db = -999.0 if is_muted else MASTER_GAIN_DB + effects_volume_db

func set_muted(muted: bool) -> void:
	is_muted = muted
	_update_players()

func set_effects_volume_db(volume_db: float) -> void:
	effects_volume_db = clampf(volume_db, -30.0, 0.0)
	_update_players()

func play_move() -> void:
	if is_muted:
		return

	target_pitch_offset += PITCH_ACCELERATION
	target_pitch_offset = clampf(target_pitch_offset, -PITCH_RANGE, PITCH_RANGE)
	current_pitch_momentum = lerpf(current_pitch_momentum, target_pitch_offset, 0.2)
	target_pitch_offset *= PITCH_DAMPING

	var momentum_pitch: float = 1.0 + current_pitch_momentum
	var variation: float = randf_range(-PITCH_VARIATION, PITCH_VARIATION)
	var final_pitch: float = maxf(0.1, momentum_pitch + variation)

	_play_tone(AppConstants.BASE_FREQUENCY * 0.5 * final_pitch, MOVE_TONE_SECONDS, -20.0, Waveform.SINE)

func play_eat() -> void:
	_play_tone(AppConstants.BASE_FREQUENCY * 1.9, 0.13, -16.0, Waveform.TRIANGLE)

func play_die() -> void:
	_play_tone(
		AppConstants.BASE_FREQUENCY * 0.5,
		0.3,
		-4.5,
		Waveform.SAW,
		VoiceGroup.CRITICAL
	)

func play_click() -> void:
	_play_tone(AppConstants.BASE_FREQUENCY * 2.5, 0.05, -12.0, Waveform.TRIANGLE)

func play_focus() -> void:
	_play_tone(AppConstants.BASE_FREQUENCY * 2.0, 0.05, -20.0, Waveform.TRIANGLE)

func reset_pitch() -> void:
	current_pitch_momentum = 0.0
	target_pitch_offset = 0.0

func play_tone(frequency: float, duration: float, volume_db: float, waveform: Waveform) -> void:
	if is_muted or DisplayServer.get_name() == "headless":
		return
	_play_tone(frequency, duration, volume_db, waveform)

func _play_tone(
	frequency: float,
	duration: float,
	volume_db: float,
	waveform: Waveform,
	voice_group := VoiceGroup.GENERAL
) -> void:
	if is_muted or DisplayServer.get_name() == "headless":
		return

	_ensure_audio_players()

	if audio_players.is_empty():
		return

	var channel := _acquire_channel_index(voice_group)
	if channel == -1:
		return

	var stream := _get_cached_tone_stream(frequency, duration, db_to_linear(volume_db), waveform)
	if stream == null:
		return

	var player := audio_players[channel]
	player.stream = stream
	player.volume_db = -999.0 if is_muted else MASTER_GAIN_DB + effects_volume_db
	player.bus = _get_synth_bus_name()
	player.play()

func _acquire_channel_index(voice_group: VoiceGroup) -> int:
	# Interrupting a PCM voice at an arbitrary sample creates a discontinuity that
	# sounds like a click. Overflow is dropped instead, and death owns a reserved voice.
	var general_channel_count := audio_players.size() - CRITICAL_CHANNEL_COUNT
	if voice_group == VoiceGroup.CRITICAL:
		for channel in range(general_channel_count, audio_players.size()):
			if not audio_players[channel].playing:
				return channel
		return -1

	if general_channel_count <= 0:
		return -1
	for offset in range(general_channel_count):
		var channel := (next_general_channel_index + offset) % general_channel_count
		if not audio_players[channel].playing:
			next_general_channel_index = (channel + 1) % general_channel_count
			return channel
	return -1

func _prewarm_fixed_tones() -> void:
	_get_cached_tone_stream(
		AppConstants.BASE_FREQUENCY * 1.9,
		0.13,
		db_to_linear(-16.0),
		Waveform.TRIANGLE
	)
	_get_cached_tone_stream(
		AppConstants.BASE_FREQUENCY * 0.5,
		0.3,
		db_to_linear(-4.5),
		Waveform.SAW
	)
	_get_cached_tone_stream(
		AppConstants.BASE_FREQUENCY * 2.5,
		0.05,
		db_to_linear(-12.0),
		Waveform.TRIANGLE
	)
	_get_cached_tone_stream(
		AppConstants.BASE_FREQUENCY * 2.0,
		0.05,
		db_to_linear(-20.0),
		Waveform.TRIANGLE
	)

func _get_cached_tone_stream(
	frequency: float,
	duration: float,
	volume_linear: float,
	waveform: Waveform
) -> AudioStreamWAV:
	# Quantization makes changing movement pitches reusable without an unbounded cache.
	var quantized_frequency := snappedf(frequency, TONE_CACHE_FREQUENCY_STEP_HZ)
	var cache_key := _tone_cache_key(quantized_frequency, duration, volume_linear, waveform)
	if _tone_cache.has(cache_key):
		_touch_cache_key(cache_key)
		return _tone_cache[cache_key]

	var stream := _render_tone_stream(
		quantized_frequency,
		duration,
		volume_linear,
		waveform
	)
	if stream == null:
		return null

	while _tone_cache_order.size() >= TONE_CACHE_CAPACITY:
		var oldest_key: String = _tone_cache_order.pop_front()
		_tone_cache.erase(oldest_key)
	_tone_cache[cache_key] = stream
	_tone_cache_order.append(cache_key)
	return stream

func _tone_cache_key(
	frequency: float,
	duration: float,
	volume_linear: float,
	waveform: Waveform
) -> String:
	return "%d:%d:%d:%d" % [
		roundi(frequency / TONE_CACHE_FREQUENCY_STEP_HZ),
		roundi(duration * 10000.0),
		roundi(volume_linear * 10000.0),
		waveform,
	]

func _touch_cache_key(cache_key: String) -> void:
	var existing_index := _tone_cache_order.find(cache_key)
	if existing_index != -1:
		_tone_cache_order.remove_at(existing_index)
	_tone_cache_order.append(cache_key)

func _render_tone_stream(frequency: float, duration: float, volume_linear: float, waveform: Waveform) -> AudioStreamWAV:
	var sample_count := int(duration * SAMPLE_HZ)
	if sample_count <= 1 or frequency <= 0.0 or duration <= 0.0:
		return null

	var safe_frequency := minf(frequency, SAMPLE_HZ * 0.45)
	var sample_data := PackedByteArray()
	sample_data.resize(sample_count * PCM_16_BYTES_PER_SAMPLE)

	for i in range(sample_count):
		var sample := _tone_sample(i, sample_count, safe_frequency, volume_linear, waveform)
		var pcm_sample := int(clampf(sample, -MAX_SAMPLE_AMPLITUDE, MAX_SAMPLE_AMPLITUDE) * PCM_16_SCALE)
		sample_data.encode_s16(i * PCM_16_BYTES_PER_SAMPLE, pcm_sample)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = int(SAMPLE_HZ)
	stream.stereo = false
	stream.data = sample_data
	return stream

func _tone_sample(sample_index: int, sample_count: int, frequency: float, volume_linear: float, waveform: Waveform) -> float:
	var t := float(sample_index) / SAMPLE_HZ
	var envelope := _envelope_gain(sample_index, sample_count)
	var raw_sample := _wave_sample(t, frequency, waveform) * envelope * volume_linear
	return _soft_clip(raw_sample)

func _soft_clip(sample: float) -> float:
	return tanh(sample * SOFT_CLIP_DRIVE) / tanh(SOFT_CLIP_DRIVE)

func _envelope_gain(sample_index: int, sample_count: int) -> float:
	if sample_count <= 1:
		return 0.0

	var attack_samples := maxi(1, int(ATTACK_SECONDS * SAMPLE_HZ))
	var release_samples := maxi(1, int(RELEASE_SECONDS * SAMPLE_HZ))

	var attack_gain := 1.0
	if sample_index < attack_samples:
		attack_gain = float(sample_index) / float(attack_samples)

	var samples_to_end := sample_count - 1 - sample_index
	var release_gain := 1.0
	if samples_to_end <= release_samples:
		release_gain = float(samples_to_end) / float(release_samples)

	return clampf(minf(attack_gain, release_gain), 0.0, 1.0)

func _wave_sample(t: float, frequency: float, waveform: Waveform) -> float:
	match waveform:
		Waveform.SINE:
			return sin(t * TAU * frequency)
		Waveform.SQUARE:
			var square_sample := 0.0
			for h in AppConstants.AUDIO_HARMONICS:
				var harmonic := h * 2 + 1
				if frequency * harmonic >= SAMPLE_HZ * 0.5:
					break
				square_sample += sin(t * TAU * frequency * harmonic) / harmonic
			return square_sample * 4.0 / TAU
		Waveform.TRIANGLE:
			var triangle_sample := 0.0
			for h in AppConstants.AUDIO_HARMONICS:
				var harmonic := h * 2 + 1
				if frequency * harmonic >= SAMPLE_HZ * 0.5:
					break
				var amplitude := pow(-1, h) / (harmonic * harmonic)
				triangle_sample += amplitude * sin(t * TAU * frequency * harmonic)
			return triangle_sample * 8.0 / (TAU * TAU)
		Waveform.SAW:
			var saw_sample := 0.0
			for h in AppConstants.AUDIO_HARMONICS:
				var harmonic := h + 1
				if frequency * harmonic >= SAMPLE_HZ * 0.5:
					break
				saw_sample += sin(t * TAU * frequency * harmonic) / harmonic
			return saw_sample * 2.0 / TAU
		_:
			return 0.0
