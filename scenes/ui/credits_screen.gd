class_name CreditsScreen
extends CenterContainer

signal credits_screen_closed

var back_button: Button

func _ready() -> void:
	back_button = %BackButton
	back_button.pressed.connect(_on_back_pressed)

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
		"project_version": project_version,
	})

func _on_back_pressed() -> void:
	credits_screen_closed.emit()

func get_buttons() -> Array[Button]:
	return [back_button]

func get_default_focus() -> Button:
	return back_button
