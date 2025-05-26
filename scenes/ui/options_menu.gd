extends CenterContainer

signal options_closed

var sound_button: Button
var fullscreen_button: Button
var reset_settings_button: Button
var reset_scores_button: Button
var back_button: Button

func _ready():
	sound_button = %SoundButton
	fullscreen_button = %FullscreenButton
	reset_settings_button = %ResetSettingsButton
	reset_scores_button = %ResetScoresButton
	back_button = %BackButton
	
	sound_button.pressed.connect(_on_sound_toggled)
	sound_button.button_down.connect(AudioManager.play_click)
	
	fullscreen_button.pressed.connect(_on_fullscreen_toggled)
	fullscreen_button.button_down.connect(AudioManager.play_click)
	
	reset_settings_button.pressed.connect(_on_reset_settings_pressed)
	reset_settings_button.button_down.connect(AudioManager.play_click)
	
	reset_scores_button.pressed.connect(_on_reset_scores_pressed)
	reset_scores_button.button_down.connect(AudioManager.play_click)
	
	back_button.pressed.connect(_on_back_pressed)
	back_button.button_down.connect(AudioManager.play_click)
	
	update_button_states()

func _on_sound_toggled() -> void:
	var is_muted := AudioManager.toggle_mute()
	update_sound_button()
	if not is_muted:
		AudioManager.play_click()

func _on_fullscreen_toggled() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	update_fullscreen_button()
	AudioManager.save_settings()

func _on_reset_settings_pressed() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Reset Settings"
	dialog.dialog_text = "Are you sure you want to reset all settings?"
	dialog.confirmed.connect(func():
		AudioManager.reset_settings()
		update_button_states()
	)
	add_child(dialog)
	dialog.popup_centered()

func _on_reset_scores_pressed() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Reset High Scores"
	dialog.dialog_text = "Are you sure you want to reset all high scores?"
	dialog.confirmed.connect(func():
		get_node("/root/Main").reset_high_scores()
	)
	add_child(dialog)
	dialog.popup_centered()

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
