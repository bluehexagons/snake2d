extends Node

enum Waveform {SINE, SQUARE, TRIANGLE, SAW}

const MIN_PITCH = 0.8
const MAX_PITCH = 1.2
const BASE_FREQUENCY = 440.0  # A4 note

# Quality settings for square/saw waves
const HARMONICS = 8  # Number of harmonics for complex waveforms

var audio_players: Array[AudioStreamPlayer] = []
var is_muted = false

func _ready():
	# Create a pool of audio players
	for i in range(4):
		var player = AudioStreamPlayer.new()
		add_child(player)
		audio_players.append(player)

func get_available_player() -> AudioStreamPlayer:
	for player in audio_players:
		if not player.playing:
			return player
	return audio_players[0]  # Fallback to first player if all busy

func toggle_mute() -> bool:
	is_muted = !is_muted
	for player in audio_players:
		player.volume_db = -999.0 if is_muted else 0.0
	return is_muted

func play_move():
	if is_muted:
		return
	var player = get_available_player()
	_generate_tone(player, BASE_FREQUENCY * 1.5, 0.1, -20, Waveform.SINE)
	player.pitch_scale = randf_range(MIN_PITCH, MAX_PITCH)
	player.play()

func play_eat():
	if is_muted:
		return
	var player = get_available_player()
	_generate_tone(player, BASE_FREQUENCY * 2, 0.15, -14, Waveform.SQUARE)
	player.pitch_scale = 1.0
	player.play()

func play_die():
	if is_muted:
		return
	var player = get_available_player()
	_generate_tone(player, BASE_FREQUENCY * 0.5, 0.3, -3, Waveform.SAW)
	player.pitch_scale = 0.8
	player.play()

func play_click():
	if is_muted:
		return
	var player = get_available_player()
	_generate_tone(player, BASE_FREQUENCY * 2.5, 0.05, -12, Waveform.TRIANGLE)
	player.pitch_scale = 1.2
	player.play()

func _generate_tone(player: AudioStreamPlayer, frequency: float, duration: float, volume_db: float, waveform: Waveform):
	var sample_hz = 44100.0
	var samples = int(duration * sample_hz)
	
	var data = PackedByteArray()
	data.resize(samples * 2)  # 2 bytes per sample for 16-bit
	
	for i in samples:
		var t = float(i) / sample_hz
		var sample = 0.0
		
		match waveform:
			Waveform.SINE:
				sample = sin(t * TAU * frequency)
			
			Waveform.SQUARE:
				# Additive synthesis for antialiased square wave
				for h in HARMONICS:
					var harmonic = h * 2 + 1  # Odd harmonics only
					sample += sin(t * TAU * frequency * harmonic) / harmonic
				sample = sample * 4.0 / TAU  # Normalize
			
			Waveform.TRIANGLE:
				# Additive synthesis for triangle wave
				for h in HARMONICS:
					var harmonic = h * 2 + 1  # Odd harmonics only
					var amplitude = pow(-1, h) / (harmonic * harmonic)
					sample += amplitude * sin(t * TAU * frequency * harmonic)
				sample = sample * 8.0 / (TAU * TAU)  # Normalize
			
			Waveform.SAW:
				# Additive synthesis for antialiased sawtooth
				for h in HARMONICS:
					var harmonic = h + 1
					sample += sin(t * TAU * frequency * harmonic) / harmonic
				sample = sample * 2.0 / TAU  # Normalize
		
		# Apply ADSR envelope (simple linear decay in this case)
		var envelope = 1.0 - (float(i) / samples)
		sample *= envelope
		
		# Convert to 16-bit integer (-32768 to 32767)
		var sample_int = int(sample * 32767.0)
		
		# Store as two bytes (little-endian)
		data[i * 2] = sample_int & 0xFF
		data[i * 2 + 1] = (sample_int >> 8) & 0xFF
	
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.data = data
	stream.mix_rate = int(sample_hz)
	
	player.stream = stream
	player.volume_db = volume_db
