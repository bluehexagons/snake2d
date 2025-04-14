extends CenterContainer

signal high_scores_closed

@onready var scores_list: VBoxContainer = %ScoresList
@onready var back_button: Button = $VBoxContainer/BackButton

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	back_button.button_down.connect(AudioManager.play_click)
	back_button.focus_entered.connect(AudioManager.play_focus)

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
	high_scores_closed.emit()
