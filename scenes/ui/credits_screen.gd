extends CenterContainer

signal credits_screen_closed

var back_button: Button

func _ready():
	back_button = %BackButton
	back_button.pressed.connect(_on_back_pressed)
	back_button.button_down.connect(AudioManager.play_click)

func _on_back_pressed() -> void:
	credits_screen_closed.emit()
