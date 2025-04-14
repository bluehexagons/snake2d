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
	# Handle input for scrolling
	var scroll_input: float = Input.get_axis("ui_up", "ui_down")
	if scroll_input != 0:
		# Scroll the container based on input direction
		scroll_container.scroll_vertical += int(scroll_input * SCROLL_SPEED)

func _input(event: InputEvent) -> void:
	if not self.visible:
		return

	var handled := false
	# Handle gamepad stick input for scrolling
	if event is InputEventJoypadMotion:
		if event.axis == JOY_AXIS_LEFT_Y or event.axis == JOY_AXIS_RIGHT_Y:
			if abs(event.axis_value) > 0.2:  # Small deadzone
				var direction = sign(event.axis_value)
				scroll_container.scroll_vertical += int(direction * SCROLL_SPEED * 0.5)
				handled = true
	
	if handled:
		get_viewport().set_input_as_handled()

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
