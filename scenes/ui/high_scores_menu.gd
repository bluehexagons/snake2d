class_name HighScoresMenu
extends ScrollContainer

signal high_scores_closed

@onready var scores_list: VBoxContainer = %ScoresList
@onready var back_button: Button = %BackButton
@onready var scroll_container: ScrollContainer = %ScrollContainer
@onready var mode_selector: OptionButton = %ModeSelector

var _score_tables: Dictionary = {}

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	for mode in GameMode.ALL:
		mode_selector.add_item(GameMode.display_name(mode), mode)
	mode_selector.item_selected.connect(_on_mode_selected)
	scroll_container.gui_input.connect(_on_score_list_input)

func _on_score_list_input(event: InputEvent) -> void:
	var down := event.is_action_pressed(&"ui_down", true, true)
	var up := event.is_action_pressed(&"ui_up", true, true)
	if not (down or up):
		return
	var previous := scroll_container.scroll_vertical
	var step := maxi(1, roundi(scroll_container.get_v_scroll_bar().page / 2.0))
	scroll_container.scroll_vertical = previous + (step if down else -step)
	# A fresh press at either end moves focus. Holding a key stops at the edge.
	if scroll_container.scroll_vertical != previous or event.is_echo():
		scroll_container.accept_event()

func update_scores(score_tables: Dictionary) -> void:
	_score_tables = score_tables.duplicate(true)
	_show_selected_scores()

func _on_mode_selected(_index: int) -> void:
	_show_selected_scores()

func _show_selected_scores() -> void:
	scroll_container.scroll_vertical = 0
	for child in scores_list.get_children():
		scores_list.remove_child(child)
		child.queue_free()

	var mode := mode_selector.get_selected_id() as GameMode.Value
	var scores: Array[int] = []
	scores.assign(_score_tables.get(GameMode.key(mode), []))
	if scores.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No scores in this mode yet"
		empty_label.theme_type_variation = &"HintLabel"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scores_list.add_child(empty_label)
	else:
		for i in scores.size():
			var row := HBoxContainer.new()
			var rank_label := Label.new()
			rank_label.text = str(i + 1)
			rank_label.theme_type_variation = &"HintLabel"
			rank_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var score_label := Label.new()
			score_label.name = "Score"
			score_label.text = str(scores[i])
			if i == 0:
				score_label.theme_type_variation = &"ScoreLabel"
			row.add_child(rank_label)
			row.add_child(score_label)
			scores_list.add_child(row)

func _on_back_pressed() -> void:
	high_scores_closed.emit()

func get_buttons() -> Array[Button]:
	return [mode_selector, back_button]

func get_default_focus() -> Button:
	return back_button
