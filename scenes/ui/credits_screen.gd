class_name CreditsScreen
extends CenterContainer

signal credits_screen_closed

var back_button: Button

func _ready() -> void:
	back_button = %BackButton
	back_button.pressed.connect(_on_back_pressed)
	back_button.button_down.connect(AudioManager.play_click)

	var credits_text: RichTextLabel = $PanelContainer/MarginContainer/VBoxContainer/CreditsRichText
	var version: String = ProjectSettings.get_setting("application/config/version", "unknown")
	credits_text.text = credits_text.text.replace("[/center]", "\nVersion: " + version + "[/center]")

func _on_back_pressed() -> void:
	credits_screen_closed.emit()
