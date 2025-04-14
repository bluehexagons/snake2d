extends CenterContainer

signal high_scores_closed

@onready var scores_list: VBoxContainer = %ScoresList
@onready var back_button: Button = %BackButton
@onready var scroll_container: ScrollContainer = $PanelContainer/MarginContainer/VBoxContainer/ScoresContainer/ScrollContainer

# Scroll speed for keyboard/gamepad navigation
const SCROLL_SPEED: float = 6.66

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	back_button.button_down.connect(AudioManager.play_click)
	back_button.focus_entered.connect(AudioManager.play_focus)

func _process(delta: float) -> void:
	if not self.visible:
		return

	# Handle input for scrolling
	var scroll_input: float = Input.get_axis("ui_up", "ui_down")
	if scroll_input != 0:
		# Scroll the container based on input direction
		scroll_container.scroll_vertical += int(scroll_input * SCROLL_SPEED)

func update_scores(scores: Array[int]) -> void:
	for child in scores_list.get_children():
		child.queue_free()

	if scores.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No scores yet!"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		scores_list.add_child(empty_label)
	else:
		for i in scores.size():
			var score_label := Label.new()
			score_label.text = "%d. %d" % [i + 1, scores[i]]
			score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			scores_list.add_child(score_label)

func _on_back_pressed() -> void:
	scroll_container.scroll_vertical = 0
	high_scores_closed.emit()
