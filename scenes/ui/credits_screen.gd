extends CenterContainer

signal credits_screen_closed

var back_button: Button

func _ready():
	back_button = %BackButton
	
	back_button.pressed.connect(_on_back_pressed)
	back_button.button_down.connect(AudioManager.play_click)

func _on_back_pressed() -> void:
	credits_screen_closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()
