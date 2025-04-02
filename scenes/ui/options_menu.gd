extends CenterContainer

signal options_closed

# Reference to AudioManager for sound handling
var sound_button: Button
var fullscreen_button: Button
var back_button: Button

# Called when the node enters the scene tree for the first time.
func _ready():
	# Get button references
	sound_button = $VBoxContainer/SoundButton
	fullscreen_button = $VBoxContainer/FullscreenButton
	back_button = $VBoxContainer/BackButton
	
	# Connect signals
	sound_button.pressed.connect(_on_sound_toggled)
	sound_button.button_down.connect(AudioManager.play_click)
	
	fullscreen_button.pressed.connect(_on_fullscreen_toggled)
	fullscreen_button.button_down.connect(AudioManager.play_click)
	
	back_button.pressed.connect(_on_back_pressed)
	back_button.button_down.connect(AudioManager.play_click)
	
	# Initial update of button states
	update_button_states()

func _on_sound_toggled() -> void:
	var is_muted := AudioManager.toggle_mute()
	update_sound_button()
	# Still play click when unmuting
	if not is_muted:
		AudioManager.play_click()

func _on_fullscreen_toggled() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	update_fullscreen_button()

func _on_back_pressed() -> void:
	options_closed.emit()

func update_button_states() -> void:
	update_sound_button()
	update_fullscreen_button()

func update_sound_button() -> void:
	sound_button.text = "Sound: " + ("Off" if AudioManager.is_muted else "On")

func update_fullscreen_button() -> void:
	var is_fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen_button.text = "Fullscreen: " + ("On" if is_fullscreen else "Off")