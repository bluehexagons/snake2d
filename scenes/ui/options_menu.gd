class_name OptionsMenu
extends ScrollContainer

signal options_closed
signal reset_scores_requested
signal volume_preview_requested(cue: AudioService.Cue)

const VOLUME_LABELS: Dictionary[AudioService.Cue, String] = {
	AudioService.Cue.ALL: "Effects volume",
	AudioService.Cue.MOVEMENT: "Movement",
	AudioService.Cue.FOOD: "Food pickup",
	AudioService.Cue.COLLISION: "Collision",
	AudioService.Cue.MENU: "Menu sounds",
}

var sound_button: SettingToggle
var volume_sliders: Dictionary[AudioService.Cue, HSlider] = {}
var fullscreen_button: SettingToggle
var reduced_motion_button: SettingToggle
var grid_button: SettingToggle
var fps_limit_button: SettingToggle
var reset_settings_button: Button
var reset_scores_button: Button
var back_button: Button
var _settings_service: SettingsService
var _confirmation_dialog: ConfirmationDialog
var _volume_values: Dictionary[AudioService.Cue, Label] = {}
var _preview_cue := AudioService.Cue.ALL

@onready var _volume_preview_timer: Timer = $VolumePreviewTimer

func _ready() -> void:
	sound_button = %SoundButton
	fullscreen_button = %FullscreenButton
	reduced_motion_button = %ReducedMotionButton
	grid_button = %GridButton
	fps_limit_button = %FPSLimitButton
	reset_settings_button = %ResetSettingsButton
	reset_scores_button = %ResetScoresButton
	back_button = %BackButton

	sound_button.pressed.connect(_on_sound_toggled)
	_create_volume_controls()
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

func _create_volume_controls() -> void:
	var controls: VBoxContainer = %VolumeControls
	var previous: Control = sound_button
	for cue in VOLUME_LABELS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var label := Label.new()
		label.text = VOLUME_LABELS[cue]
		label.custom_minimum_size.x = 104.0
		row.add_child(label)

		var slider := HSlider.new()
		slider.accessibility_name = label.text
		slider.custom_minimum_size = Vector2(70, 44)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.scrollable = false
		if cue == AudioService.Cue.ALL:
			slider.min_value = -30.0
			slider.max_value = 0.0
			slider.step = 1.0
		else:
			slider.step = 5.0
		slider.value_changed.connect(_on_volume_changed.bind(cue))
		row.add_child(slider)
		volume_sliders[cue] = slider

		var value := Label.new()
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.custom_minimum_size.x = 40.0
		row.add_child(value)
		_volume_values[cue] = value

		controls.add_child(row)
		previous.focus_neighbor_bottom = previous.get_path_to(slider)
		slider.focus_neighbor_top = slider.get_path_to(previous)
		previous = slider
	previous.focus_neighbor_bottom = previous.get_path_to(fullscreen_button)
	fullscreen_button.focus_neighbor_top = fullscreen_button.get_path_to(previous)

func _on_volume_changed(value: float, cue: AudioService.Cue) -> void:
	if _settings_service == null:
		return
	if cue == AudioService.Cue.ALL:
		_settings_service.set_effects_volume_db(value)
	else:
		_settings_service.set_cue_volume_percent(cue, value)
	if (
		can_process() and is_visible_in_tree() and not _settings_service.is_muted
		and _settings_service.get_cue_volume_percent(cue) > 0.0
	):
		_preview_cue = cue
		_volume_preview_timer.start()

func _preview_volume() -> void:
	if is_visible_in_tree() and _settings_service != null and not _settings_service.is_muted:
		volume_preview_requested.emit(_preview_cue)

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
	volume_sliders[AudioService.Cue.ALL].set_value_no_signal(volume_db)
	_volume_values[AudioService.Cue.ALL].text = "%d%%" % roundi(db_to_linear(volume_db) * 100.0)
	for cue in SettingsService.CUE_VOLUME_KEYS:
		var percent := _settings_service.get_cue_volume_percent(cue)
		volume_sliders[cue].set_value_no_signal(percent)
		_volume_values[cue].text = "%d%%" % roundi(percent)
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
