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
const TONE_RENDER_HEADROOM_DB := -12.0
const TONE_RENDER_GAIN := 0.25118864
const SOFT_CLIP_DRIVE := 1.15
const PCM_16_SCALE := 32767.0
const PCM_16_BYTES_PER_SAMPLE := 2
const MAX_SAMPLE_AMPLITUDE := 0.98

const SYNTH_BUS_NAME := "SynthSfx"
const LIMITER_CEILING_DB := -1.0
const LIMITER_THRESHOLD_DB := -7.0
const LIMITER_SOFT_CLIP_DB := 2.0
const LIMITER_SOFT_CLIP_RATIO := 8.0

## Movement pitch follows normalized game-speed progress instead of elapsed moves.
## The power curve keeps most of the pitch rise in the latter half of a round.
const MOVE_START_FREQUENCY := AppConstants.BASE_FREQUENCY * 0.5
const MOVE_END_FREQUENCY := AppConstants.BASE_FREQUENCY * 0.7
const MOVE_PITCH_CURVE_EXPONENT := 1.6
const MOVE_START_VOLUME_DB := -22.0
const MOVE_END_VOLUME_DB := -25.0
const MOVE_START_DURATION_SECONDS := 0.044
const MOVE_END_DURATION_SECONDS := 0.032
const MOVE_PROGRESS_STEPS := 24

const EAT_START_FREQUENCY := AppConstants.BASE_FREQUENCY * 1.65
const EAT_END_FREQUENCY := AppConstants.BASE_FREQUENCY * 2.05
const EAT_TONE_SECONDS := 0.13
const EAT_VOLUME_DB := -16.0
const DIE_START_FREQUENCY := AppConstants.BASE_FREQUENCY * 0.55
const DIE_END_FREQUENCY := AppConstants.BASE_FREQUENCY * 0.2
const DIE_TONE_SECONDS := 0.34
const DIE_VOLUME_DB := -7.0
const CLICK_FREQUENCY := AppConstants.BASE_FREQUENCY * 2.5
const CLICK_VOLUME_DB := -14.0
const FOCUS_FREQUENCY := AppConstants.BASE_FREQUENCY * 2.0
const FOCUS_VOLUME_DB := -20.0
const TONE_CACHE_FREQUENCY_STEP_HZ := 2.0
const TONE_CACHE_CAPACITY := 128

var audio_players: Array[AudioStreamPlayer] = []
var next_general_channel_index := 0
var _channel_cue_volume_db := PackedFloat32Array()
var _tone_cache: Dictionary[String, AudioStreamWAV] = {}
var _tone_cache_order: Array[String] = []

var is_muted := false
var effects_volume_db := 0.0

func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		_ensure_audio_players()
		_prewarm_cues()
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
		_channel_cue_volume_db.append(0.0)

	_update_players()

func _exit_tree() -> void:
	for player in audio_players:
		player.stop()
		player.stream = null
	audio_players.clear()
	_channel_cue_volume_db.clear()
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
	for channel in range(audio_players.size()):
		var player := audio_players[channel]
		player.bus = _get_synth_bus_name()
		player.volume_db = _volume_db_for_channel(channel)

func _volume_db_for_channel(channel: int) -> float:
	if is_muted:
		return -999.0
	var cue_volume_db := 0.0
	if channel >= 0 and channel < _channel_cue_volume_db.size():
		cue_volume_db = _channel_cue_volume_db[channel]
	# Every cached stream uses the same render headroom. Compensating here keeps cue
	# gain intuitive while still feeding the waveshaper a clean, low-level signal.
	return MASTER_GAIN_DB + effects_volume_db + cue_volume_db - TONE_RENDER_HEADROOM_DB

func set_muted(muted: bool) -> void:
	is_muted = muted
	_update_players()

func set_effects_volume_db(volume_db: float) -> void:
	effects_volume_db = clampf(volume_db, -30.0, 0.0)
	_update_players()

func play_move(speed_progress: float) -> void:
	var progress := _quantized_move_progress(speed_progress)
	_play_tone(
		movement_frequency_for_progress(progress),
		movement_duration_for_progress(progress),
		movement_volume_db_for_progress(progress),
		Waveform.SINE
	)

func movement_frequency_for_progress(speed_progress: float) -> float:
	var progress := _quantized_move_progress(speed_progress)
	var curved_progress := pow(progress, MOVE_PITCH_CURVE_EXPONENT)
	var frequency_ratio := MOVE_END_FREQUENCY / MOVE_START_FREQUENCY
	return MOVE_START_FREQUENCY * pow(frequency_ratio, curved_progress)

func movement_volume_db_for_progress(speed_progress: float) -> float:
	var progress := _quantized_move_progress(speed_progress)
	return lerpf(MOVE_START_VOLUME_DB, MOVE_END_VOLUME_DB, progress)

func movement_duration_for_progress(speed_progress: float) -> float:
	var progress := _quantized_move_progress(speed_progress)
	return lerpf(MOVE_START_DURATION_SECONDS, MOVE_END_DURATION_SECONDS, progress)

func _quantized_move_progress(speed_progress: float) -> float:
	var step_size := 1.0 / float(MOVE_PROGRESS_STEPS)
	return clampf(snappedf(clampf(speed_progress, 0.0, 1.0), step_size), 0.0, 1.0)

func play_eat() -> void:
	_play_tone(
		EAT_START_FREQUENCY,
		EAT_TONE_SECONDS,
		EAT_VOLUME_DB,
		Waveform.TRIANGLE,
		VoiceGroup.GENERAL,
		EAT_END_FREQUENCY
	)

func play_die() -> void:
	_play_tone(
		DIE_START_FREQUENCY,
		DIE_TONE_SECONDS,
		DIE_VOLUME_DB,
		Waveform.SAW,
		VoiceGroup.CRITICAL,
		DIE_END_FREQUENCY
	)

func play_click() -> void:
	_play_tone(CLICK_FREQUENCY, 0.05, CLICK_VOLUME_DB, Waveform.TRIANGLE)

func play_focus() -> void:
	_play_tone(FOCUS_FREQUENCY, 0.05, FOCUS_VOLUME_DB, Waveform.TRIANGLE)

func play_tone(frequency: float, duration: float, volume_db: float, waveform: Waveform) -> void:
	if is_muted or DisplayServer.get_name() == "headless":
		return
	_play_tone(frequency, duration, volume_db, waveform)

func _play_tone(
	frequency: float,
	duration: float,
	volume_db: float,
	waveform: Waveform,
	voice_group := VoiceGroup.GENERAL,
	end_frequency := -1.0
) -> void:
	if is_muted or DisplayServer.get_name() == "headless":
		return

	_ensure_audio_players()

	if audio_players.is_empty():
		return

	var channel := _acquire_channel_index(voice_group)
	if channel == -1:
		return

	var resolved_end_frequency := frequency if end_frequency <= 0.0 else end_frequency
	var stream := _get_cached_tone_stream(frequency, resolved_end_frequency, duration, waveform)
	if stream == null:
		return

	var player := audio_players[channel]
	_channel_cue_volume_db[channel] = volume_db
	player.stream = stream
	player.volume_db = _volume_db_for_channel(channel)
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

func _prewarm_cues() -> void:
	for step in range(MOVE_PROGRESS_STEPS + 1):
		var progress := float(step) / float(MOVE_PROGRESS_STEPS)
		_get_cached_tone_stream(
			movement_frequency_for_progress(progress),
			movement_frequency_for_progress(progress),
			movement_duration_for_progress(progress),
			Waveform.SINE
		)
	_get_cached_tone_stream(
		EAT_START_FREQUENCY,
		EAT_END_FREQUENCY,
		EAT_TONE_SECONDS,
		Waveform.TRIANGLE
	)
	_get_cached_tone_stream(
		DIE_START_FREQUENCY,
		DIE_END_FREQUENCY,
		DIE_TONE_SECONDS,
		Waveform.SAW
	)
	_get_cached_tone_stream(
		CLICK_FREQUENCY,
		CLICK_FREQUENCY,
		0.05,
		Waveform.TRIANGLE
	)
	_get_cached_tone_stream(
		FOCUS_FREQUENCY,
		FOCUS_FREQUENCY,
		0.05,
		Waveform.TRIANGLE
	)

func _get_cached_tone_stream(
	start_frequency: float,
	end_frequency: float,
	duration: float,
	waveform: Waveform
) -> AudioStreamWAV:
	# Quantized sweep endpoints keep similar cues reusable without an unbounded cache.
	var quantized_start := snappedf(start_frequency, TONE_CACHE_FREQUENCY_STEP_HZ)
	var quantized_end := snappedf(end_frequency, TONE_CACHE_FREQUENCY_STEP_HZ)
	var cache_key := _tone_cache_key(quantized_start, quantized_end, duration, waveform)
	if _tone_cache.has(cache_key):
		_touch_cache_key(cache_key)
		return _tone_cache[cache_key]

	var stream := _render_tone_stream(
		quantized_start,
		quantized_end,
		duration,
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
	start_frequency: float,
	end_frequency: float,
	duration: float,
	waveform: Waveform
) -> String:
	return "%d:%d:%d:%d" % [
		roundi(start_frequency / TONE_CACHE_FREQUENCY_STEP_HZ),
		roundi(end_frequency / TONE_CACHE_FREQUENCY_STEP_HZ),
		roundi(duration * 10000.0),
		waveform,
	]

func _touch_cache_key(cache_key: String) -> void:
	var existing_index := _tone_cache_order.find(cache_key)
	if existing_index != -1:
		_tone_cache_order.remove_at(existing_index)
	_tone_cache_order.append(cache_key)

func _render_tone_stream(
	start_frequency: float,
	end_frequency: float,
	duration: float,
	waveform: Waveform
) -> AudioStreamWAV:
	var sample_count := int(duration * SAMPLE_HZ)
	if sample_count <= 1 or start_frequency <= 0.0 or end_frequency <= 0.0 or duration <= 0.0:
		return null

	var safe_start_frequency := minf(start_frequency, SAMPLE_HZ * 0.45)
	var safe_end_frequency := minf(end_frequency, SAMPLE_HZ * 0.45)
	var sample_data := PackedByteArray()
	sample_data.resize(sample_count * PCM_16_BYTES_PER_SAMPLE)

	for i in range(sample_count):
		var sample := _tone_sample(
			i,
			sample_count,
			safe_start_frequency,
			safe_end_frequency,
			waveform
		)
		var pcm_sample := int(clampf(sample, -MAX_SAMPLE_AMPLITUDE, MAX_SAMPLE_AMPLITUDE) * PCM_16_SCALE)
		sample_data.encode_s16(i * PCM_16_BYTES_PER_SAMPLE, pcm_sample)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = int(SAMPLE_HZ)
	stream.stereo = false
	stream.data = sample_data
	return stream

func _tone_sample(
	sample_index: int,
	sample_count: int,
	start_frequency: float,
	end_frequency: float,
	waveform: Waveform
) -> float:
	var t := float(sample_index) / SAMPLE_HZ
	var progress := float(sample_index) / float(sample_count - 1)
	var current_frequency := lerpf(start_frequency, end_frequency, progress)
	# Integrating the linear frequency ramp keeps phase continuous throughout a sweep.
	var sweep_duration := float(sample_count - 1) / SAMPLE_HZ
	var phase_cycles := start_frequency * t
	phase_cycles += 0.5 * (end_frequency - start_frequency) * t * t / sweep_duration
	var phase := phase_cycles * TAU
	var envelope := _envelope_gain(sample_index, sample_count)
	var raw_sample := _wave_sample(phase, current_frequency, waveform) * envelope * TONE_RENDER_GAIN
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

func _wave_sample(phase: float, frequency: float, waveform: Waveform) -> float:
	match waveform:
		Waveform.SINE:
			return sin(phase)
		Waveform.SQUARE:
			var square_sample := 0.0
			for h in AppConstants.AUDIO_HARMONICS:
				var harmonic := h * 2 + 1
				if frequency * harmonic >= SAMPLE_HZ * 0.5:
					break
				square_sample += sin(phase * harmonic) / harmonic
			return square_sample * 4.0 / TAU
		Waveform.TRIANGLE:
			var triangle_sample := 0.0
			for h in AppConstants.AUDIO_HARMONICS:
				var harmonic := h * 2 + 1
				if frequency * harmonic >= SAMPLE_HZ * 0.5:
					break
				var amplitude := pow(-1, h) / (harmonic * harmonic)
				triangle_sample += amplitude * sin(phase * harmonic)
			return triangle_sample * 8.0 / (TAU * TAU)
		Waveform.SAW:
			var saw_sample := 0.0
			for h in AppConstants.AUDIO_HARMONICS:
				var harmonic := h + 1
				if frequency * harmonic >= SAMPLE_HZ * 0.5:
					break
				saw_sample += sin(phase * harmonic) / harmonic
			return saw_sample * 2.0 / TAU
		_:
			return 0.0
