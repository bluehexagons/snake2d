class_name OptionsMenu
extends ScrollContainer

signal options_closed
signal reset_scores_requested
signal volume_preview_requested

var sound_button: SettingToggle
var volume_label: Label
var volume_slider: HSlider
var fullscreen_button: SettingToggle
var reduced_motion_button: SettingToggle
var grid_button: SettingToggle
var fps_limit_button: SettingToggle
var reset_settings_button: Button
var reset_scores_button: Button
var back_button: Button
var _settings_service: SettingsService
var _confirmation_dialog: ConfirmationDialog

@onready var _volume_preview_timer: Timer = $VolumePreviewTimer

func _ready() -> void:
	sound_button = %SoundButton
	volume_label = %VolumeLabel
	volume_slider = %VolumeSlider
	fullscreen_button = %FullscreenButton
	reduced_motion_button = %ReducedMotionButton
	grid_button = %GridButton
	fps_limit_button = %FPSLimitButton
	reset_settings_button = %ResetSettingsButton
	reset_scores_button = %ResetScoresButton
	back_button = %BackButton

	sound_button.pressed.connect(_on_sound_toggled)
	volume_slider.value_changed.connect(_on_volume_changed)
	_volume_preview_timer.timeout.connect(_preview_volume)
	fullscreen_button.pressed.connect(_on_fullscreen_toggled)
	reduced_motion_button.pressed.connect(_on_reduced_motion_toggled)
	grid_button.pressed.connect(_on_grid_toggled)
	fps_limit_button.pressed.connect(_on_fps_limit_toggled)
	if not SettingsService.supports_gameplay_fps_limit():
		fps_limit_button.hide()
		grid_button.focus_neighbor_bottom = grid_button.get_path_to(reset_settings_button)
		reset_settings_button.focus_neighbor_top = reset_settings_button.get_path_to(grid_button)
	reset_settings_button.pressed.connect(_on_reset_settings_pressed)
	reset_scores_button.pressed.connect(_on_reset_scores_pressed)
	back_button.pressed.connect(_on_back_pressed)
	resized.connect(_update_confirmation_layout)
	_update_button_states()

func _notification(what: int) -> void:
	if what == NOTIFICATION_DISABLED and is_instance_valid(_volume_preview_timer):
		_volume_preview_timer.stop()

## Supplies the versioned settings boundary this menu edits.
func set_settings_service(service: SettingsService) -> void:
	if is_instance_valid(_settings_service):
		_settings_service.settings_changed.disconnect(_update_button_states)
	_settings_service = service
	if _settings_service != null:
		_settings_service.settings_changed.connect(_update_button_states)
	_update_button_states()

func _on_sound_toggled() -> void:
	_settings_service.toggle_mute()

func _on_volume_changed(volume_db: float) -> void:
	if _settings_service == null:
		return
	_settings_service.set_effects_volume_db(volume_db)
	if can_process() and is_visible_in_tree() and not _settings_service.is_muted:
		_volume_preview_timer.start()

func _preview_volume() -> void:
	if is_visible_in_tree() and _settings_service != null and not _settings_service.is_muted:
		volume_preview_requested.emit()

func _on_fullscreen_toggled() -> void:
	_settings_service.toggle_fullscreen()

func _on_reduced_motion_toggled() -> void:
	_settings_service.toggle_reduced_motion()

func _on_grid_toggled() -> void:
	_settings_service.toggle_grid()

func _on_fps_limit_toggled() -> void:
	_settings_service.toggle_gameplay_fps_limit()

func _on_reset_settings_pressed() -> void:
	_show_confirmation_dialog(
		"Reset Settings",
		"Restore the default sound, display, and accessibility settings?",
		"Reset",
		func() -> void:
			_settings_service.reset_settings()
	)

func _on_reset_scores_pressed() -> void:
	_show_confirmation_dialog(
		"Clear High Scores",
		"Delete the saved scores for all three modes?",
		"Clear scores",
		func() -> void:
			reset_scores_requested.emit()
	)

func _on_back_pressed() -> void:
	options_closed.emit()

func get_buttons() -> Array[Button]:
	var buttons: Array[Button] = [
		sound_button,
		fullscreen_button,
		reduced_motion_button,
		grid_button,
		fps_limit_button,
		reset_settings_button,
		reset_scores_button,
		back_button,
	]
	if not fps_limit_button.visible:
		buttons.erase(fps_limit_button)
	return buttons

func get_default_focus() -> Button:
	return sound_button

func _update_button_states() -> void:
	_volume_preview_timer.stop()
	if _settings_service == null:
		return
	sound_button.show_setting(not _settings_service.is_muted)
	var volume_db := _settings_service.effects_volume_db
	volume_slider.set_value_no_signal(volume_db)
	var linear_volume := db_to_linear(volume_db)
	volume_label.text = "Effects Volume: %d%%" % roundi(linear_volume * 100.0)
	fullscreen_button.show_setting(_settings_service.is_fullscreen)
	reduced_motion_button.show_setting(_settings_service.reduced_motion)
	grid_button.show_setting(_settings_service.grid_enabled)
	fps_limit_button.show_setting(_settings_service.limit_gameplay_fps)

func _show_confirmation_dialog(title: String, text: String, confirmation: String, on_confirm: Callable) -> void:
	if is_instance_valid(_confirmation_dialog):
		return
	var dialog := ConfirmationDialog.new()
	_confirmation_dialog = dialog
	dialog.title = title
	dialog.borderless = true
	dialog.theme = theme
	dialog.ok_button_text = confirmation
	dialog.dialog_autowrap = true
	dialog.dialog_text = "%s\n\n%s" % [title, text]
	var opener := get_viewport().gui_get_focus_owner()
	var close_dialog := func() -> void:
		dialog.hide()
		dialog.queue_free()
		if is_instance_valid(opener) and can_process():
			opener.grab_focus()
	dialog.confirmed.connect(func() -> void:
		on_confirm.call()
		close_dialog.call()
	)
	dialog.close_requested.connect(close_dialog)
	dialog.canceled.connect(close_dialog)
	add_child(dialog)
	var cancel_on_back := func(event: InputEvent) -> void:
		if event.is_action_pressed("ui_cancel"):
			dialog.set_input_as_handled()
			close_dialog.call()
	dialog.get_cancel_button().gui_input.connect(cancel_on_back)
	dialog.get_ok_button().gui_input.connect(cancel_on_back)
	# Autowrapped text can adjust the minimum height after the popup appears.
	dialog.size_changed.connect(func() -> void:
		dialog.position = Vector2i((get_viewport_rect().size - Vector2(dialog.size)) / 2.0)
	)
	_update_confirmation_layout()
	# A zero popup rect preserves these embedded viewport coordinates. Passing a
	# rect to popup_centered_clamped also caps it against physical screen pixels.
	dialog.popup()
	dialog.get_cancel_button().grab_focus()

func _update_confirmation_layout() -> void:
	if not is_instance_valid(_confirmation_dialog):
		return
	var dialog := _confirmation_dialog
	# Embedded Windows do not inherit the CanvasLayer's scale like Controls do.
	dialog.content_scale_factor = get_canvas_transform().get_scale().x
	var viewport_size := get_viewport_rect().size
	dialog.size = Vector2i((Vector2(360.0, 180.0) * dialog.content_scale_factor).min(viewport_size * 0.9))
	dialog.position = Vector2i((viewport_size - Vector2(dialog.size)) / 2.0)
