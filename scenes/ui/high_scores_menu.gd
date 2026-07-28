class_name HighScoresMenu
extends CenterContainer

signal high_scores_closed

@onready var scores_list: VBoxContainer = %ScoresList
@onready var back_button: Button = %BackButton
@onready var scroll_container: ScrollContainer = $PanelContainer/MarginContainer/VBoxContainer/ScoresContainer/ScrollContainer

const SCROLL_SPEED := 400.0
var _scroll_position := 0.0

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	back_button.button_down.connect(AudioManager.play_click)
	back_button.focus_entered.connect(AudioManager.play_focus)
	set_process(false)
	visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed() -> void:
	set_process(self.visible)
	_scroll_position = float(scroll_container.scroll_vertical)

func _process(delta: float) -> void:
	var scroll_input: float = Input.get_axis("ui_up", "ui_down")
	if scroll_input != 0:
		_scroll_position += scroll_input * SCROLL_SPEED * delta
		var requested_scroll := roundi(_scroll_position)
		scroll_container.scroll_vertical = requested_scroll
		if scroll_container.scroll_vertical != requested_scroll:
			_scroll_position = float(scroll_container.scroll_vertical)
	else:
		_scroll_position = float(scroll_container.scroll_vertical)

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
	_scroll_position = 0.0
	high_scores_closed.emit()
