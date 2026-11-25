class_name GameOverPanel
extends ScrollContainer

signal restart_requested
signal new_seed_requested
signal menu_requested

@onready var title_label: Label = %GameOverLabel
@onready var score_label: Label = %FinalScoreLabel
@onready var cause_label: Label = %CollisionCauseLabel
@onready var personal_best_label: Label = %PersonalBestLabel
@onready var restart_button: Button = %RestartButton
@onready var new_seed_button: Button = %NewSeedButton
@onready var menu_button: Button = %GameOverMenuButton

func _ready() -> void:
	restart_button.pressed.connect(restart_requested.emit)
	new_seed_button.pressed.connect(new_seed_requested.emit)
	menu_button.pressed.connect(menu_requested.emit)

func show_result(final_score: int, result: SnakeGame.StepResult, mode: GameMode.Value, new_best: bool) -> void:
	title_label.text = "BOARD COMPLETE" if result == SnakeGame.StepResult.FILLED_BOARD else "GAME OVER"
	score_label.text = "Final Score: %d" % final_score
	var cause := ""
	match result:
		SnakeGame.StepResult.HIT_WALL:
			cause = "Hit the wall"
		SnakeGame.StepResult.HIT_SELF:
			cause = "Hit your own body"
		SnakeGame.StepResult.HIT_OBSTACLE:
			cause = "Fell into a pit" if mode == GameMode.Value.PITFALL else "Hit an obstacle"
	cause_label.text = cause
	cause_label.visible = not cause.is_empty()
	personal_best_label.visible = new_best
	var seeded := mode == GameMode.Value.OBSTACLES
	new_seed_button.visible = seeded
	restart_button.text = "Retry Layout" if seeded else "Play Again"
	restart_button.focus_neighbor_bottom = restart_button.get_path_to(new_seed_button if seeded else menu_button)
	menu_button.focus_neighbor_top = menu_button.get_path_to(new_seed_button if seeded else restart_button)

func get_buttons() -> Array[Button]:
	return [restart_button, new_seed_button, menu_button]

func get_default_focus() -> Button:
	return restart_button
