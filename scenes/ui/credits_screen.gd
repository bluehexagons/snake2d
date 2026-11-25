class_name CreditsScreen
extends ScrollContainer

signal credits_screen_closed

const SOURCE_URL := "https://github.com/bluehexagons/snake2d"

var back_button: Button
@onready var source_button: Button = %SourceButton

func _ready() -> void:
	back_button = %BackButton
	back_button.pressed.connect(_on_back_pressed)
	source_button.pressed.connect(_on_source_pressed)

	var credits_text: RichTextLabel = %CreditsRichText
	var engine_version := Engine.get_version_info()
	var godot_version := "%d.%d.%d" % [
		engine_version.major,
		engine_version.minor,
		engine_version.patch,
	]
	var project_version := str(ProjectSettings.get_setting("application/config/version", "unknown"))
	credits_text.text = credits_text.text.format({
		"godot_version": godot_version,
	})
	var license_text: RichTextLabel = %LicenseText
	license_text.text = license_text.text.format({"project_version": project_version})

func _on_back_pressed() -> void:
	credits_screen_closed.emit()

func _on_source_pressed() -> void:
	OS.shell_open(SOURCE_URL)

func get_buttons() -> Array[Button]:
	return [source_button, back_button]

func get_default_focus() -> Button:
	return back_button
