class_name OptionsMenu
extends CenterContainer

signal options_closed
signal reset_scores_requested

var sound_button: Button
var fullscreen_button: Button
var reset_settings_button: Button
var reset_scores_button: Button
var back_button: Button

func _ready() -> void:
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
	_show_confirmation_dialog(
		"Reset Settings",
		"Are you sure you want to reset all settings?",
		func() -> void:
		AudioManager.reset_settings()
		update_button_states()
	)

func _on_reset_scores_pressed() -> void:
	_show_confirmation_dialog(
		"Reset High Scores",
		"Are you sure you want to reset all high scores?",
		func() -> void:
		reset_scores_requested.emit()
	)

func _on_back_pressed() -> void:
	options_closed.emit()

func update_button_states() -> void:
	update_sound_button()
	update_fullscreen_button()

func update_sound_button() -> void:
	sound_button.text = str("Sound: ", "Off" if AudioManager.is_muted else "On")

func update_fullscreen_button() -> void:
	var is_fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen_button.text = str("Fullscreen: ", "On" if is_fullscreen else "Off")

func _show_confirmation_dialog(title: String, text: String, on_confirm: Callable) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = title
	dialog.dialog_text = text
	dialog.confirmed.connect(on_confirm)
	add_child(dialog)
	dialog.popup_centered()
