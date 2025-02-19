extends Node

const MIN_PITCH = 0.8
const MAX_PITCH = 1.2
const BASE_FREQUENCY = 440.0  # A4 note

var audio_players: Array[AudioStreamPlayer] = []

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

func play_move():
	var player = get_available_player()
	_generate_tone(player, BASE_FREQUENCY * 1.5, 0.1, -12)
	player.pitch_scale = randf_range(MIN_PITCH, MAX_PITCH)
	player.play()

func play_eat():
	var player = get_available_player()
	_generate_tone(player, BASE_FREQUENCY * 2, 0.15, -6)
	player.pitch_scale = 1.0
	player.play()

func play_die():
	var player = get_available_player()
	_generate_tone(player, BASE_FREQUENCY * 0.5, 0.3, -3)
	player.pitch_scale = 0.8
	player.play()

func play_click():
	var player = get_available_player()
	_generate_tone(player, BASE_FREQUENCY * 2.5, 0.05, -12)
	player.pitch_scale = 1.2
	player.play()

func _generate_tone(player: AudioStreamPlayer, frequency: float, duration: float, volume_db: float):
	var sample_hz = 44100.0
	var samples = int(duration * sample_hz)
	
	var data = PackedByteArray()
	data.resize(samples * 2)  # 2 bytes per sample for 16-bit
	
	for i in samples:
		var t = float(i) / sample_hz
		var sample = sin(t * TAU * frequency)
		# Apply simple envelope
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
