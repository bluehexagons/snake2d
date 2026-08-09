class_name MainMenu
extends CenterContainer

signal start_requested
signal scores_requested
signal options_requested
signal credits_requested
signal quit_requested

@onready var start_button: Button = %StartButton
@onready var scores_button: Button = %ScoresButton
@onready var options_button: Button = %OptionsButton
@onready var credits_button: Button = %CreditsButton
@onready var quit_button: Button = %QuitButton

func _ready() -> void:
	var version_label: Label = $PanelContainer/MarginContainer/Label
	version_label.text = "v" + ProjectSettings.get_setting("application/config/version", "?")
	start_button.pressed.connect(start_requested.emit)
	scores_button.pressed.connect(scores_requested.emit)
	options_button.pressed.connect(options_requested.emit)
	credits_button.pressed.connect(credits_requested.emit)
	quit_button.pressed.connect(quit_requested.emit)

func get_buttons() -> Array[Button]:
	return [start_button, scores_button, options_button, credits_button, quit_button]

func get_default_focus() -> Button:
	return start_button
