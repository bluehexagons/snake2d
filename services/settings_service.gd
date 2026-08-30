class_name SettingsService
extends Node

## Versioned user settings plus the code that applies them to runtime services.

signal settings_changed

const CURRENT_VERSION := 1
const DEFAULT_SETTINGS_PATH := "user://settings.cfg"
const LEGACY_SETTINGS_PATH := "user://settings.dat"

@export var settings_path := DEFAULT_SETTINGS_PATH

var is_muted := false
var effects_volume_db := 0.0
var is_fullscreen := false
var reduced_motion := false
var grid_enabled := true

var _audio_service: AudioService
var _ui_state_manager: UIStateManager
var _gameplay_grid: GameplayGrid

func configure(
	audio_service: AudioService,
	ui_state_manager: UIStateManager,
	gameplay_grid: GameplayGrid = null
) -> void:
	_audio_service = audio_service
	_ui_state_manager = ui_state_manager
	_gameplay_grid = gameplay_grid
	load_settings()
	_apply_settings()

func load_settings() -> void:
	_reset_values()
	var config := ConfigFile.new()
	var error := config.load(settings_path)
	if error == OK:
		var version := int(config.get_value("meta", "version", 0))
		if version == CURRENT_VERSION:
			is_muted = bool(config.get_value("audio", "muted", false))
			effects_volume_db = clampf(float(config.get_value("audio", "effects_volume_db", 0.0)), -30.0, 0.0)
			is_fullscreen = bool(config.get_value("display", "fullscreen", false))
			grid_enabled = bool(config.get_value("display", "grid_enabled", true))
			reduced_motion = bool(config.get_value("accessibility", "reduced_motion", false))
		return

	if not FileAccess.file_exists(settings_path) and FileAccess.file_exists(LEGACY_SETTINGS_PATH):
		_load_legacy_settings()
		save_settings()

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("meta", "version", CURRENT_VERSION)
	config.set_value("audio", "muted", is_muted)
	config.set_value("audio", "effects_volume_db", effects_volume_db)
	config.set_value("display", "fullscreen", is_fullscreen)
	config.set_value("display", "grid_enabled", grid_enabled)
	config.set_value("accessibility", "reduced_motion", reduced_motion)
	var error := config.save(settings_path)
	if error != OK:
		push_warning("Could not save settings to %s (error %d)." % [settings_path, error])

func toggle_mute() -> bool:
	is_muted = not is_muted
	_commit_change()
	return is_muted

func set_effects_volume_db(volume_db: float) -> void:
	var clamped := clampf(volume_db, -30.0, 0.0)
	if is_equal_approx(clamped, effects_volume_db):
		return
	effects_volume_db = clamped
	_commit_change()

func toggle_fullscreen() -> bool:
	is_fullscreen = not is_fullscreen
	_commit_change()
	return is_fullscreen

func toggle_reduced_motion() -> bool:
	reduced_motion = not reduced_motion
	_commit_change()
	return reduced_motion

func toggle_grid() -> bool:
	grid_enabled = not grid_enabled
	_commit_change()
	return grid_enabled

func reset_settings() -> void:
	_reset_values()
	_commit_change()

func _reset_values() -> void:
	is_muted = false
	effects_volume_db = 0.0
	is_fullscreen = false
	reduced_motion = false
	grid_enabled = true

func _commit_change() -> void:
	_apply_settings()
	save_settings()
	settings_changed.emit()

func _apply_settings() -> void:
	if _audio_service:
		_audio_service.set_muted(is_muted)
		_audio_service.set_effects_volume_db(effects_volume_db)
	if _ui_state_manager:
		_ui_state_manager.set_reduced_motion(reduced_motion)
	if _gameplay_grid:
		_gameplay_grid.set_grid_enabled(grid_enabled)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_FULLSCREEN
			if is_fullscreen
			else DisplayServer.WINDOW_MODE_WINDOWED
		)

func _load_legacy_settings() -> void:
	var file := FileAccess.open(LEGACY_SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return
	is_muted = file.get_8() == 1
	is_fullscreen = file.get_8() == 1
