extends Node

enum Waveform {SINE, SQUARE, TRIANGLE, SAW}
enum TonePriority {MOVE, UI, EAT, DIE}

const ConfigData = preload("res://autoload/config.gd")
const SETTINGS_FILE := ConfigData.SETTINGS_FILE

const CHANNEL_COUNT := 12
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

var audio_players: Array[AudioStreamPlayer] = []
var player_priorities: Array[int] = []
var player_started_usec: Array[int] = []
var next_channel_index := 0

var is_muted := false
var current_pitch_momentum := 0.0
var target_pitch_offset := 0.0

func _ready() -> void:
	load_settings()
	if DisplayServer.get_name() != "headless":
		_ensure_synth_bus()
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
		player_priorities.append(TonePriority.MOVE)
		player_started_usec.append(0)

	_update_players()

func _exit_tree() -> void:
	for player in audio_players:
		player.stop()
		player.stream = null
	audio_players.clear()
	player_priorities.clear()
	player_started_usec.clear()

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
	var index := audio_players.find(player)
	if index == -1:
		return

	player.stream = null
	player_priorities[index] = TonePriority.MOVE
	player_started_usec[index] = 0

func _update_players() -> void:
	for player in audio_players:
		player.bus = _get_synth_bus_name()
		player.volume_db = -999.0 if is_muted else MASTER_GAIN_DB

func save_settings() -> void:
	var file := FileAccess.open(SETTINGS_FILE, FileAccess.WRITE)
	if file:
		file.store_8(1 if is_muted else 0)
		file.store_8(1 if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else 0)

func load_settings() -> void:
	if FileAccess.file_exists(SETTINGS_FILE):
		var file := FileAccess.open(SETTINGS_FILE, FileAccess.READ)
		if file:
			is_muted = file.get_8() == 1
			_update_players()

			var fullscreen := file.get_8() == 1
			DisplayServer.window_set_mode(
				DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
			)

func reset_settings() -> void:
	is_muted = false
	_update_players()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	save_settings()

func toggle_mute() -> bool:
	is_muted = !is_muted
	_update_players()
	save_settings()
	return is_muted

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

	_play_tone(ConfigData.BASE_FREQUENCY * 0.5 * final_pitch, MOVE_TONE_SECONDS, -20.0, Waveform.SINE, TonePriority.MOVE)

func play_eat() -> void:
	_play_tone(ConfigData.BASE_FREQUENCY * 1.9, 0.13, -16.0, Waveform.TRIANGLE, TonePriority.EAT)

func play_die() -> void:
	_play_tone(ConfigData.BASE_FREQUENCY * 0.5, 0.3, -4.5, Waveform.SAW, TonePriority.DIE)

func play_click() -> void:
	_play_tone(ConfigData.BASE_FREQUENCY * 2.5, 0.05, -12.0, Waveform.TRIANGLE, TonePriority.UI)

func play_focus() -> void:
	_play_tone(ConfigData.BASE_FREQUENCY * 2.0, 0.05, -20.0, Waveform.TRIANGLE, TonePriority.UI)

func reset_pitch() -> void:
	current_pitch_momentum = 0.0
	target_pitch_offset = 0.0

func play_tone(frequency: float, duration: float, volume_db: float, waveform: Waveform) -> void:
	if is_muted or DisplayServer.get_name() == "headless":
		return
	_play_tone(frequency, duration, volume_db, waveform, TonePriority.UI)

func _play_tone(frequency: float, duration: float, volume_db: float, waveform: Waveform, priority: TonePriority) -> void:
	if is_muted or DisplayServer.get_name() == "headless":
		return

	_ensure_audio_players()

	if audio_players.is_empty():
		return

	var channel := _acquire_channel_index(priority)
	if channel == -1:
		return

	var stream := _render_tone_stream(frequency, duration, db_to_linear(volume_db), waveform)
	if stream == null:
		return

	var player := audio_players[channel]
	if player.playing:
		player.stop()
	player.stream = stream
	player.volume_db = -999.0 if is_muted else MASTER_GAIN_DB
	player.bus = _get_synth_bus_name()
	player_priorities[channel] = priority
	player_started_usec[channel] = Time.get_ticks_usec()
	player.play()

func _acquire_channel_index(priority: TonePriority) -> int:
	for offset in range(audio_players.size()):
		var channel := (next_channel_index + offset) % audio_players.size()
		if not audio_players[channel].playing:
			next_channel_index = (channel + 1) % audio_players.size()
			return channel

	var selected := -1
	var selected_priority := priority
	var selected_started_usec := 0
	for i in range(audio_players.size()):
		var existing_priority := player_priorities[i]
		if priority != TonePriority.DIE and existing_priority >= priority:
			continue

		if (
			selected == -1
			or existing_priority < selected_priority
			or (
				existing_priority == selected_priority
				and player_started_usec[i] < selected_started_usec
			)
		):
			selected = i
			selected_priority = existing_priority
			selected_started_usec = player_started_usec[i]

	if selected != -1:
		next_channel_index = (selected + 1) % audio_players.size()

	return selected

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
			for h in ConfigData.AUDIO_HARMONICS:
				var harmonic := h * 2 + 1
				if frequency * harmonic >= SAMPLE_HZ * 0.5:
					break
				square_sample += sin(t * TAU * frequency * harmonic) / harmonic
			return square_sample * 4.0 / TAU
		Waveform.TRIANGLE:
			var triangle_sample := 0.0
			for h in ConfigData.AUDIO_HARMONICS:
				var harmonic := h * 2 + 1
				if frequency * harmonic >= SAMPLE_HZ * 0.5:
					break
				var amplitude := pow(-1, h) / (harmonic * harmonic)
				triangle_sample += amplitude * sin(t * TAU * frequency * harmonic)
			return triangle_sample * 8.0 / (TAU * TAU)
		Waveform.SAW:
			var saw_sample := 0.0
			for h in ConfigData.AUDIO_HARMONICS:
				var harmonic := h + 1
				if frequency * harmonic >= SAMPLE_HZ * 0.5:
					break
				saw_sample += sin(t * TAU * frequency * harmonic) / harmonic
			return saw_sample * 2.0 / TAU
		_:
			return 0.0
