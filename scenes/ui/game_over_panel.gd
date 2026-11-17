class_name GameOverPanel
extends ScrollContainer

signal restart_requested
signal menu_requested

@onready var title_label: Label = %GameOverLabel
@onready var score_label: Label = %FinalScoreLabel
@onready var restart_button: Button = %RestartButton
@onready var menu_button: Button = %GameOverMenuButton

func _ready() -> void:
	restart_button.pressed.connect(restart_requested.emit)
	menu_button.pressed.connect(menu_requested.emit)

func show_final_score(final_score: int, board_complete := false) -> void:
	title_label.text = "BOARD COMPLETE" if board_complete else "GAME OVER"
	score_label.text = "Final Score: %d" % final_score

func get_buttons() -> Array[Button]:
	return [restart_button, menu_button]

func get_default_focus() -> Button:
	return restart_button
