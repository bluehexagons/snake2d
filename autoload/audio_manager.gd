extends Node

enum Waveform {SINE, SQUARE, TRIANGLE, SAW}

const BASE_FREQUENCY := 420.0
const SETTINGS_FILE := "user://settings.dat"

const HARMONICS := 8

const PITCH_ACCELERATION := 0.04
const PITCH_DAMPING := 0.9
const PITCH_RANGE := 0.95
const PITCH_VARIATION := 0.04

var audio_players: Array[AudioStreamPlayer] = []
var is_muted := false
var current_pitch_momentum := 0.0
var target_pitch_offset := 0.0

func _ready() -> void:
	for i in range(4):
		var player := AudioStreamPlayer.new()
		add_child(player)
		audio_players.append(player)
		
	load_settings()

func _update_players() -> void:
	for player in audio_players:
		player.volume_db = -999.0 if is_muted else 0.0

func save_settings() -> void:
	var file := FileAccess.open(SETTINGS_FILE, FileAccess.WRITE)
	if file:
		file.store_8(1 if is_muted else 0)
		file.store_8(1 if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else 0)
		
func load_settings() -> void:
	if FileAccess.file_exists(SETTINGS_FILE):
		var file := FileAccess.open(SETTINGS_FILE, FileAccess.READ)
		if file:
			var muted := file.get_8() == 1
			is_muted = muted
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

func get_available_player() -> AudioStreamPlayer:
	for player in audio_players:
		if not player.playing:
			return player
	return audio_players[0]

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
	current_pitch_momentum = lerp(current_pitch_momentum, target_pitch_offset, 0.2)
	target_pitch_offset *= PITCH_DAMPING
	
	var momentum_pitch := 1.0 + current_pitch_momentum
	var variation := randf_range(-PITCH_VARIATION, PITCH_VARIATION)
	var final_pitch := momentum_pitch + variation
	
	var player := get_available_player()
	_generate_tone(player, BASE_FREQUENCY * 0.5, 0.07, -20, Waveform.SINE)
	player.pitch_scale = final_pitch
	player.play()

func play_eat() -> void:
	if is_muted:
		return
	var player := get_available_player()
	_generate_tone(player, BASE_FREQUENCY * 2, 0.15, -14, Waveform.SQUARE)
	player.pitch_scale = 1.0
	player.play()

func play_die() -> void:
	if is_muted:
		return
	var player := get_available_player()
	_generate_tone(player, BASE_FREQUENCY * 0.5, 0.3, -3, Waveform.SAW)
	player.pitch_scale = 0.8
	player.play()

func play_click() -> void:
	if is_muted:
		return
	var player := get_available_player()
	_generate_tone(player, BASE_FREQUENCY * 2.5, 0.05, -12, Waveform.TRIANGLE)
	player.pitch_scale = 1.2
	player.play()

func play_focus() -> void:
	if is_muted:
		return
	var player := get_available_player()
	_generate_tone(player, BASE_FREQUENCY * 2, 0.05, -20, Waveform.TRIANGLE)
	player.pitch_scale = 1.5
	player.play()

func reset_pitch() -> void:
	current_pitch_momentum = 0.0
	target_pitch_offset = 0.0

func _generate_tone(player: AudioStreamPlayer, frequency: float, duration: float, volume_db: float, waveform: Waveform) -> void:
	var sample_hz := 44100.0
	var samples := int(duration * sample_hz)
	
	var data := PackedByteArray()
	data.resize(samples * 2)
	
	for i in samples:
		var t := float(i) / sample_hz
		var sample := 0.0
		
		match waveform:
			Waveform.SINE:
				sample = sin(t * TAU * frequency)
			
			Waveform.SQUARE:
				for h in HARMONICS:
					var harmonic := h * 2 + 1
					sample += sin(t * TAU * frequency * harmonic) / harmonic
				sample = sample * 4.0 / TAU
			
			Waveform.TRIANGLE:
				for h in HARMONICS:
					var harmonic := h * 2 + 1
					var amplitude := pow(-1, h) / (harmonic * harmonic)
					sample += amplitude * sin(t * TAU * frequency * harmonic)
				sample = sample * 8.0 / (TAU * TAU)
			
			Waveform.SAW:
				for h in HARMONICS:
					var harmonic := h + 1
					sample += sin(t * TAU * frequency * harmonic) / harmonic
				sample = sample * 2.0 / TAU
		
		var envelope := 1.0 - (float(i) / samples)
		sample *= envelope
		
		var sample_int := int(sample * 32767.0)
		
		data[i * 2] = sample_int & 0xFF
		data[i * 2 + 1] = (sample_int >> 8) & 0xFF
	
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.data = data
	stream.mix_rate = int(sample_hz)
	
	player.stream = stream
	player.volume_db = volume_db
