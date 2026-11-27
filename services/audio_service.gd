class_name AudioService
extends Node

## An explicitly owned service for procedural sound synthesis and playback.
## Main composes this node and supplies it only to components that need audio behavior.

enum Waveform {SINE, SQUARE, TRIANGLE, SAW, CHIME, ROUNDED_BUZZ}
enum VoiceGroup {GENERAL, CRITICAL, MENU}

const AppConstants = preload("res://core/app_constants.gd")
const CHANNEL_COUNT := 12
const CRITICAL_CHANNEL_COUNT := 1
const SAMPLE_HZ := 44100.0
const ATTACK_SAMPLES := int(0.004 * SAMPLE_HZ)
const RELEASE_SAMPLES := int(0.012 * SAMPLE_HZ)
const PCM_16_SCALE := 32767.0
const PCM_16_BYTES_PER_SAMPLE := 2
const TONE_RENDER_PEAK := 0.35
const NYQUIST_HZ := SAMPLE_HZ * 0.5
const HARMONIC_FADE_START_HZ := SAMPLE_HZ * 0.45

# At maximum settings the sum of 11 general peaks and one death peak is
# below -2 dBFS, including on Web where sample playback bypasses bus effects.
const MAX_GENERAL_CUE_VOLUME_DB := -15.0

## Movement pitch follows normalized game-speed progress instead of elapsed moves.
## The power curve keeps most of the pitch rise in the latter half of a round.
const MOVE_START_FREQUENCY := AppConstants.BASE_FREQUENCY * 0.5
const MOVE_END_FREQUENCY := AppConstants.BASE_FREQUENCY * 0.7
const MOVE_PITCH_CURVE_EXPONENT := 1.6
const MOVE_START_VOLUME_DB := -21.0
const MOVE_END_VOLUME_DB := -25.0
const MOVE_START_DURATION_SECONDS := 0.044
const MOVE_END_DURATION_SECONDS := 0.030
const MOVE_PROGRESS_STEPS := 24
const MOVE_DUCK_DB := -5.0

const EAT_START_FREQUENCY := AppConstants.BASE_FREQUENCY * 1.65
const EAT_END_FREQUENCY := AppConstants.BASE_FREQUENCY * 2.2
const EAT_TONE_SECONDS := 0.115
const EAT_VOLUME_DB := -15.0
const DIE_START_FREQUENCY := AppConstants.BASE_FREQUENCY * 0.67
const DIE_END_FREQUENCY := AppConstants.BASE_FREQUENCY * 0.36
const DIE_TONE_SECONDS := 0.235
const DIE_VOLUME_DB := -14.0
const CLICK_FREQUENCY := AppConstants.BASE_FREQUENCY * 2.25
const CLICK_TONE_SECONDS := 0.038
const CLICK_VOLUME_DB := -20.0
const FOCUS_FREQUENCY := AppConstants.BASE_FREQUENCY * 1.9
const FOCUS_TONE_SECONDS := 0.032
const FOCUS_VOLUME_DB := -27.0
const TONE_CACHE_FREQUENCY_STEP_HZ := 2.0
const TONE_CACHE_CAPACITY := 128
const MAX_TONE_DURATION_SECONDS := 1.0
const MAX_TONE_FREQUENCY_HZ := HARMONIC_FADE_START_HZ
const SHUTDOWN_DRAIN_USEC := 200_000

var audio_players: Array[AudioStreamPlayer] = []
var next_general_channel_index := 0
var _movement_player: AudioStreamPlayer
var _pickup_player: AudioStreamPlayer
var _tone_cache: Dictionary[Vector4i, AudioStreamWAV] = {}
var _tone_cache_order: Array[Vector4i] = []
var _shutting_down := false

var is_muted := false
var effects_volume_db := 0.0

func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		_ensure_audio_players()
		_prewarm_fixed_cues()

func _ensure_audio_players() -> void:
	if not audio_players.is_empty():
		return

	# Use the default Master route because dynamically added buses can go silent on Web.
	for i in range(CHANNEL_COUNT):
		var player := AudioStreamPlayer.new()
		player.finished.connect(_on_audio_player_finished.bind(player))
		add_child(player)

		audio_players.append(player)

func _exit_tree() -> void:
	_release_players()

func drain_for_quit() -> void:
	_shutting_down = true
	_release_players()
	if audio_players.is_empty():
		return

	# The mixer fades stopped voices in real time. A scene timer can consume
	# time from the frame in which it started, before the mixer had that time.
	var deadline := Time.get_ticks_usec() + SHUTDOWN_DRAIN_USEC
	var remaining := deadline - Time.get_ticks_usec()
	while remaining > 0:
		await get_tree().create_timer(remaining / 1_000_000.0, true, false, true).timeout
		remaining = deadline - Time.get_ticks_usec()

func _release_players() -> void:
	for player in audio_players:
		player.stop()
		player.stream = null
	# The players are still children if the service is detached for reuse.
	next_general_channel_index = 0
	_movement_player = null
	_pickup_player = null

func _on_audio_player_finished(player: AudioStreamPlayer) -> void:
	player.stream = null
	if player == _movement_player:
		_movement_player = null
	if player == _pickup_player:
		_pickup_player = null

func _volume_db_for_channel(channel: int, cue_volume_db: float) -> float:
	var is_critical := channel >= CHANNEL_COUNT - CRITICAL_CHANNEL_COUNT
	var max_cue_volume_db := DIE_VOLUME_DB if is_critical else MAX_GENERAL_CUE_VOLUME_DB
	return effects_volume_db + minf(cue_volume_db, max_cue_volume_db)

## Settings apply at each cue's silent onset. Web sample gain changes can
## otherwise cut a playing waveform mid-cycle. Muting blocks new cues.
func set_muted(muted: bool) -> void:
	is_muted = muted

func set_effects_volume_db(volume_db: float) -> void:
	if not is_finite(volume_db):
		return
	effects_volume_db = clampf(volume_db, -30.0, 0.0)

func play_move(speed_progress: float) -> void:
	# Catch-up ticks can arrive before the last movement cue has finished.
	if _movement_player != null and _movement_player.playing:
		return
	var volume_db := movement_volume_db_for_progress(speed_progress)
	# Set the gain for the whole tap at its silent onset. This works with Web
	# sample playback and avoids altering an already audible waveform.
	if not audio_players.is_empty() and (
		audio_players.back().playing or (_pickup_player != null and _pickup_player.playing)
	):
		volume_db += MOVE_DUCK_DB
	_movement_player = _play_tone(
		movement_frequency_for_progress(speed_progress),
		movement_duration_for_progress(speed_progress),
		volume_db,
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
	if not is_finite(speed_progress):
		return 0.0
	var step_size := 1.0 / float(MOVE_PROGRESS_STEPS)
	return clampf(snappedf(clampf(speed_progress, 0.0, 1.0), step_size), 0.0, 1.0)

func play_eat() -> void:
	var player := _play_tone(
		EAT_START_FREQUENCY,
		EAT_TONE_SECONDS,
		EAT_VOLUME_DB,
		Waveform.CHIME,
		VoiceGroup.GENERAL,
		EAT_END_FREQUENCY
	)
	if player != null:
		_pickup_player = player

func play_die() -> void:
	_play_tone(
		DIE_START_FREQUENCY,
		DIE_TONE_SECONDS,
		DIE_VOLUME_DB,
		Waveform.ROUNDED_BUZZ,
		VoiceGroup.CRITICAL,
		DIE_END_FREQUENCY
	)

func play_click() -> void:
	_play_tone(CLICK_FREQUENCY, CLICK_TONE_SECONDS, CLICK_VOLUME_DB, Waveform.TRIANGLE, VoiceGroup.MENU)

func play_focus() -> void:
	_play_tone(FOCUS_FREQUENCY, FOCUS_TONE_SECONDS, FOCUS_VOLUME_DB, Waveform.TRIANGLE, VoiceGroup.MENU)

func play_tone(frequency: float, duration: float, volume_db: float, waveform: Waveform) -> void:
	_play_tone(frequency, duration, volume_db, waveform)

func _play_tone(
	frequency: float,
	duration: float,
	volume_db: float,
	waveform: Waveform,
	voice_group := VoiceGroup.GENERAL,
	end_frequency := -1.0
) -> AudioStreamPlayer:
	if (
		_shutting_down or is_muted or audio_players.is_empty()
		or not is_inside_tree() or not is_finite(volume_db)
	):
		return null

	var resolved_end_frequency := frequency if end_frequency <= 0.0 else end_frequency
	var stream := _get_cached_tone_stream(frequency, resolved_end_frequency, duration, waveform)
	if stream == null:
		return null
	if voice_group == VoiceGroup.MENU and audio_players.any(
		func(player: AudioStreamPlayer) -> bool: return player.playing and player.stream == stream
	):
		return null

	var channel := _acquire_channel_index(voice_group)
	if channel == -1:
		return null

	var player := audio_players[channel]
	if player == _movement_player:
		_movement_player = null
	if player == _pickup_player:
		_pickup_player = null
	player.stream = stream
	player.volume_db = _volume_db_for_channel(channel, volume_db)
	player.play()
	return player

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

func _prewarm_fixed_cues() -> void:
	# Render the longer, timing-sensitive effects before gameplay. Movement
	# buckets are short and are synthesized only when their speed is reached.
	_get_cached_tone_stream(
		EAT_START_FREQUENCY,
		EAT_END_FREQUENCY,
		EAT_TONE_SECONDS,
		Waveform.CHIME
	)
	_get_cached_tone_stream(
		DIE_START_FREQUENCY,
		DIE_END_FREQUENCY,
		DIE_TONE_SECONDS,
		Waveform.ROUNDED_BUZZ
	)
	_get_cached_tone_stream(
		CLICK_FREQUENCY,
		CLICK_FREQUENCY,
		CLICK_TONE_SECONDS,
		Waveform.TRIANGLE
	)
	_get_cached_tone_stream(
		FOCUS_FREQUENCY,
		FOCUS_FREQUENCY,
		FOCUS_TONE_SECONDS,
		Waveform.TRIANGLE
	)

func _get_cached_tone_stream(
	start_frequency: float,
	end_frequency: float,
	duration: float,
	waveform: Waveform
) -> AudioStreamWAV:
	if (
		not is_finite(start_frequency) or start_frequency <= 0.0
		or not is_finite(end_frequency) or end_frequency <= 0.0
		or not is_finite(duration) or duration <= 0.0 or duration > MAX_TONE_DURATION_SECONDS
		or waveform < Waveform.SINE or waveform > Waveform.ROUNDED_BUZZ
	):
		return null

	var sample_count := int(duration * SAMPLE_HZ)
	if sample_count <= 2:
		return null

	# Key the cache by the inputs actually rendered, including the exact PCM length.
	var quantized_start := _quantize_frequency(start_frequency)
	var quantized_end := _quantize_frequency(end_frequency)
	var cache_key := Vector4i(quantized_start, quantized_end, sample_count, waveform)
	if _tone_cache.has(cache_key):
		_touch_cache_key(cache_key)
		return _tone_cache[cache_key]

	var stream := _render_tone_stream(
		quantized_start,
		quantized_end,
		sample_count,
		waveform
	)

	while _tone_cache_order.size() >= TONE_CACHE_CAPACITY:
		var oldest_key: Vector4i = _tone_cache_order.pop_front()
		_tone_cache.erase(oldest_key)
	_tone_cache[cache_key] = stream
	_tone_cache_order.append(cache_key)
	return stream

func _quantize_frequency(frequency: float) -> int:
	var clamped := clampf(frequency, TONE_CACHE_FREQUENCY_STEP_HZ, MAX_TONE_FREQUENCY_HZ)
	return mini(roundi(snappedf(clamped, TONE_CACHE_FREQUENCY_STEP_HZ)), int(MAX_TONE_FREQUENCY_HZ))

func _touch_cache_key(cache_key: Vector4i) -> void:
	_tone_cache_order.erase(cache_key)
	_tone_cache_order.append(cache_key)

func _render_tone_stream(
	start_frequency: float,
	end_frequency: float,
	sample_count: int,
	waveform: Waveform
) -> AudioStreamWAV:
	# Integrate the linear frequency change in sample units to keep sweep phase continuous.
	var last_sample := sample_count - 1
	var frequency_step := (end_frequency - start_frequency) / float(last_sample)
	var radians_per_hz := TAU / SAMPLE_HZ
	var initial_phase_step := start_frequency * radians_per_hz
	var half_phase_acceleration := 0.5 * frequency_step * radians_per_hz
	var decay := 0.0
	match waveform:
		Waveform.CHIME:
			decay = 0.45
		Waveform.ROUNDED_BUZZ:
			decay = 0.68
	var decay_per_sample := decay / last_sample
	var samples := PackedFloat64Array()
	samples.resize(sample_count)
	var peak := 1.0
	for i in range(sample_count):
		var phase := i * (initial_phase_step + i * half_phase_acceleration)
		var frequency := start_frequency + i * frequency_step
		var gain := minf(float(i) / ATTACK_SAMPLES, float(last_sample - i) / RELEASE_SAMPLES)
		var envelope := smoothstep(0.0, 1.0, gain) * (1.0 - i * decay_per_sample)
		var sample := _wave_sample(phase, frequency, waveform) * envelope
		samples[i] = sample
		peak = maxf(peak, absf(sample))

	# Apply one gain to the whole cue so peaks from additive harmonics retain their shape.
	var pcm_gain := TONE_RENDER_PEAK * PCM_16_SCALE / peak
	var sample_data := PackedByteArray()
	sample_data.resize(sample_count * PCM_16_BYTES_PER_SAMPLE)
	for i in range(sample_count):
		sample_data.encode_s16(i * PCM_16_BYTES_PER_SAMPLE, int(samples[i] * pcm_gain))

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = int(SAMPLE_HZ)
	stream.stereo = false
	stream.data = sample_data
	return stream

func _wave_sample(phase: float, frequency: float, waveform: Waveform) -> float:
	match waveform:
		Waveform.SINE:
			return sin(phase)
		Waveform.SQUARE:
			var square_sample := 0.0
			for h in AppConstants.AUDIO_HARMONICS:
				var harmonic := h * 2 + 1
				var harmonic_gain := _harmonic_gain(frequency * harmonic)
				if harmonic_gain <= 0.0:
					break
				square_sample += harmonic_gain * sin(phase * harmonic) / harmonic
			return square_sample * 8.0 / TAU
		Waveform.TRIANGLE:
			var triangle_sample := 0.0
			var sign := 1.0
			for h in AppConstants.AUDIO_HARMONICS:
				var harmonic := h * 2 + 1
				var harmonic_gain := _harmonic_gain(frequency * harmonic)
				if harmonic_gain <= 0.0:
					break
				var amplitude := sign * harmonic_gain / (harmonic * harmonic)
				triangle_sample += amplitude * sin(phase * harmonic)
				sign = -sign
			return triangle_sample * 32.0 / (TAU * TAU)
		Waveform.SAW:
			var saw_sample := 0.0
			for h in AppConstants.AUDIO_HARMONICS:
				var harmonic := h + 1
				var harmonic_gain := _harmonic_gain(frequency * harmonic)
				if harmonic_gain <= 0.0:
					break
				saw_sample += harmonic_gain * sin(phase * harmonic) / harmonic
			return saw_sample * 4.0 / TAU
		Waveform.CHIME:
			return (
				sin(phase) + 0.35 * _harmonic_gain(frequency * 2.0) * sin(phase * 2.0)
				+ 0.12 * _harmonic_gain(frequency * 3.0) * sin(phase * 3.0)
			)
		Waveform.ROUNDED_BUZZ:
			return (
				sin(phase) + 0.22 * _harmonic_gain(frequency * 2.0) * sin(phase * 2.0)
				+ 0.32 * _harmonic_gain(frequency * 3.0) * sin(phase * 3.0)
			)
		_:
			return 0.0

func _harmonic_gain(frequency: float) -> float:
	if frequency <= HARMONIC_FADE_START_HZ:
		return 1.0
	# A partial crossing Nyquist during a sweep must fade out continuously.
	return 1.0 - smoothstep(HARMONIC_FADE_START_HZ, NYQUIST_HZ, frequency)
