class_name OptionsMenu
extends ScrollContainer

signal options_closed
signal reset_scores_requested

var sound_button: Button
var volume_label: Label
var volume_slider: HSlider
var fullscreen_button: Button
var reduced_motion_button: Button
var grid_button: Button
var reset_settings_button: Button
var reset_scores_button: Button
var back_button: Button
var _settings_service: SettingsService
var _updating_controls := false
var _confirmation_dialog: ConfirmationDialog

func _ready() -> void:
	sound_button = %SoundButton
	volume_label = %VolumeLabel
	volume_slider = %VolumeSlider
	fullscreen_button = %FullscreenButton
	reduced_motion_button = %ReducedMotionButton
	grid_button = %GridButton
	reset_settings_button = %ResetSettingsButton
	reset_scores_button = %ResetScoresButton
	back_button = %BackButton
	
	sound_button.pressed.connect(_on_sound_toggled)
	volume_slider.value_changed.connect(_on_volume_changed)
	fullscreen_button.pressed.connect(_on_fullscreen_toggled)
	reduced_motion_button.pressed.connect(_on_reduced_motion_toggled)
	grid_button.pressed.connect(_on_grid_toggled)
	reset_settings_button.pressed.connect(_on_reset_settings_pressed)
	
	reset_scores_button.pressed.connect(_on_reset_scores_pressed)
	
	back_button.pressed.connect(_on_back_pressed)
	resized.connect(_update_confirmation_layout)
	update_button_states()

## Supplies the versioned settings boundary this menu edits.
func set_settings_service(service: SettingsService) -> void:
	if is_instance_valid(_settings_service):
		_settings_service.settings_changed.disconnect(update_button_states)
	_settings_service = service
	if _settings_service != null:
		_settings_service.settings_changed.connect(update_button_states)
	update_button_states()

func _on_sound_toggled() -> void:
	_settings_service.toggle_mute()
	update_sound_button()

func _on_volume_changed(volume_db: float) -> void:
	if _updating_controls or _settings_service == null:
		return
	_settings_service.set_effects_volume_db(volume_db)
	update_volume_label()

func _on_fullscreen_toggled() -> void:
	_settings_service.toggle_fullscreen()
	update_fullscreen_button()

func _on_reduced_motion_toggled() -> void:
	_settings_service.toggle_reduced_motion()
	update_reduced_motion_button()

func _on_grid_toggled() -> void:
	_settings_service.toggle_grid()
	update_grid_button()

func _on_reset_settings_pressed() -> void:
	_show_confirmation_dialog(
		"Reset Settings",
		"Are you sure you want to reset all settings?",
		func() -> void:
			_settings_service.reset_settings()
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

func get_buttons() -> Array[Button]:
	return [
		sound_button,
		fullscreen_button,
		reduced_motion_button,
		grid_button,
		reset_settings_button,
		reset_scores_button,
		back_button,
	]

func get_default_focus() -> Button:
	return sound_button

func update_button_states() -> void:
	if _settings_service == null:
		return
	_updating_controls = true
	update_sound_button()
	volume_slider.value = _settings_service.effects_volume_db
	update_volume_label()
	update_fullscreen_button()
	update_reduced_motion_button()
	update_grid_button()
	_updating_controls = false

func update_sound_button() -> void:
	sound_button.text = str("Sound: ", "Off" if _settings_service.is_muted else "On")

func update_volume_label() -> void:
	var linear_volume := db_to_linear(_settings_service.effects_volume_db)
	volume_label.text = "Effects Volume: %d%%" % roundi(linear_volume * 100.0)

func update_fullscreen_button() -> void:
	fullscreen_button.text = str("Fullscreen: ", "On" if _settings_service.is_fullscreen else "Off")

func update_reduced_motion_button() -> void:
	reduced_motion_button.text = str(
		"Reduced Motion: ",
		"On" if _settings_service.reduced_motion else "Off"
	)

func update_grid_button() -> void:
	grid_button.text = str("Gameplay Grid: ", "On" if _settings_service.grid_enabled else "Off")

func _show_confirmation_dialog(title: String, text: String, on_confirm: Callable) -> void:
	if is_instance_valid(_confirmation_dialog):
		return
	var dialog := ConfirmationDialog.new()
	_confirmation_dialog = dialog
	dialog.title = title
	dialog.dialog_text = text
	dialog.dialog_autowrap = true
	dialog.theme = theme
	dialog.confirmed.connect(func() -> void: on_confirm.call(); dialog.queue_free())
	dialog.close_requested.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	# Autowrapped text can adjust the minimum height after the popup appears.
	dialog.size_changed.connect(func() -> void:
		dialog.position = Vector2i((get_viewport_rect().size - Vector2(dialog.size)) / 2.0)
	)
	_update_confirmation_layout()
	# A zero popup rect preserves these embedded viewport coordinates. Passing a
	# rect to popup_centered_clamped also caps it against physical screen pixels.
	dialog.popup()

func _update_confirmation_layout() -> void:
	if not is_instance_valid(_confirmation_dialog):
		return
	var dialog := _confirmation_dialog
	# Embedded Windows do not inherit the CanvasLayer's scale like Controls do.
	dialog.content_scale_factor = get_canvas_transform().get_scale().x
	var viewport_size := get_viewport_rect().size
	dialog.size = Vector2i((Vector2(360.0, 180.0) * dialog.content_scale_factor).min(viewport_size * 0.9))
	dialog.position = Vector2i((viewport_size - Vector2(dialog.size)) / 2.0)
