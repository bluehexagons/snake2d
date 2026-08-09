class_name PauseMenu
extends CenterContainer

signal resume_requested
signal menu_requested

@onready var resume_button: Button = %ResumeButton
@onready var menu_button: Button = %QuitButton

func _ready() -> void:
	resume_button.pressed.connect(resume_requested.emit)
	menu_button.pressed.connect(menu_requested.emit)

func get_buttons() -> Array[Button]:
	return [resume_button, menu_button]

func get_default_focus() -> Button:
	return resume_button
