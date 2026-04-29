extends Node

enum Waveform {SINE, SQUARE, TRIANGLE, SAW}

const ConfigData = preload("res://autoload/config.gd")
const SETTINGS_FILE := ConfigData.SETTINGS_FILE

const CHANNEL_COUNT := 32
const SAMPLE_HZ := 44100.0
const BUFFER_LENGTH_SECONDS := 0.6
const ATTACK_SECONDS := 0.004
const RELEASE_SECONDS := 0.02
const MASTER_GAIN_DB := -10.0
const SOFT_CLIP_DRIVE := 1.25

const PITCH_ACCELERATION := 0.04
const PITCH_DAMPING := 0.9
const PITCH_RANGE := 0.95
const PITCH_VARIATION := 0.04

var audio_players: Array[AudioStreamPlayer] = []
var next_channel_index := 0

var is_muted := false
var current_pitch_momentum := 0.0
var target_pitch_offset := 0.0

func _ready() -> void:
	load_settings()
	_update_players()

func _ensure_audio_players() -> void:
	if not audio_players.is_empty():
		return

	for i in range(CHANNEL_COUNT):
		var generator := AudioStreamGenerator.new()
		generator.mix_rate = int(SAMPLE_HZ)
		generator.buffer_length = BUFFER_LENGTH_SECONDS

		var player := AudioStreamPlayer.new()
		player.stream = generator
		add_child(player)
		player.play()

		audio_players.append(player)

	_update_players()

func _exit_tree() -> void:
	for player in audio_players:
		player.stop()
		player.stream = null
	audio_players.clear()

func _update_players() -> void:
	for player in audio_players:
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

	play_tone(ConfigData.BASE_FREQUENCY * 0.5 * final_pitch, 0.07, -20.0, Waveform.SINE)

func play_eat() -> void:
	play_tone(ConfigData.BASE_FREQUENCY * 1.9, 0.13, -16.0, Waveform.TRIANGLE)

func play_die() -> void:
	play_tone(ConfigData.BASE_FREQUENCY * 0.5, 0.3, -3.0, Waveform.SAW)

func play_click() -> void:
	play_tone(ConfigData.BASE_FREQUENCY * 2.5, 0.05, -12.0, Waveform.TRIANGLE)

func play_focus() -> void:
	play_tone(ConfigData.BASE_FREQUENCY * 2.0, 0.05, -20.0, Waveform.TRIANGLE)

func reset_pitch() -> void:
	current_pitch_momentum = 0.0
	target_pitch_offset = 0.0

func play_tone(frequency: float, duration: float, volume_db: float, waveform: Waveform) -> void:
	if is_muted or DisplayServer.get_name() == "headless":
		return
	_play_tone(frequency, duration, volume_db, waveform)

func _play_tone(frequency: float, duration: float, volume_db: float, waveform: Waveform) -> void:
	_ensure_audio_players()

	if audio_players.is_empty():
		return
	var volume_linear := db_to_linear(volume_db)

	for _attempt in range(audio_players.size()):
		var channel := _acquire_channel_index()
		var player := audio_players[channel]

		if not player.playing:
			player.play()

		var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
		if playback == null:
			continue

		if _push_tone(playback, frequency, duration, volume_linear, waveform):
			return

func _acquire_channel_index() -> int:
	var selected := next_channel_index
	var best_available := -1

	for i in range(audio_players.size()):
		if not audio_players[i].playing:
			selected = i
			break

		var playback := audio_players[i].get_stream_playback() as AudioStreamGeneratorPlayback
		if playback == null:
			continue

		var available := playback.get_frames_available()
		if available > best_available:
			best_available = available
			selected = i

	next_channel_index = (selected + 1) % audio_players.size()
	return selected

func _push_tone(playback: AudioStreamGeneratorPlayback, frequency: float, duration: float, volume_linear: float, waveform: Waveform) -> bool:
	var sample_count := int(duration * SAMPLE_HZ)
	if sample_count <= 0:
		return false
	if playback.get_frames_available() < sample_count:
		return false

	var pushed_samples := 0

	for i in sample_count:
		var t := float(i) / SAMPLE_HZ
		var envelope := _envelope_gain(i, sample_count)
		var raw_sample := _wave_sample(t, frequency, waveform) * envelope * volume_linear
		var sample := _soft_clip(raw_sample)
		playback.push_frame(Vector2(sample, sample))
		pushed_samples += 1

	return pushed_samples > 0

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
