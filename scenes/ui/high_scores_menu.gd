class_name HighScoresMenu
extends CenterContainer

signal high_scores_closed

@onready var scores_list: VBoxContainer = %ScoresList
@onready var back_button: Button = %BackButton
@onready var scroll_container: ScrollContainer = %ScrollContainer
@onready var mode_selector: OptionButton = %ModeSelector

const SCROLL_SPEED := 400.0
var _scroll_position := 0.0
var _score_tables: Dictionary = {}

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	for mode in GameMode.ALL:
		mode_selector.add_item(GameMode.display_name(mode), mode)
	mode_selector.item_selected.connect(_on_mode_selected)
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

func update_scores(score_tables: Dictionary) -> void:
	_score_tables = score_tables.duplicate(true)
	_show_selected_scores()

func _on_mode_selected(_index: int) -> void:
	_show_selected_scores()

func _show_selected_scores() -> void:
	for child in scores_list.get_children():
		child.queue_free()

	var mode := mode_selector.get_selected_id() as GameMode.Value
	var scores: Array[int] = []
	scores.assign(_score_tables.get(GameMode.key(mode), []))
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

func get_buttons() -> Array[Button]:
	return [mode_selector, back_button]

func get_default_focus() -> Button:
	return back_button
