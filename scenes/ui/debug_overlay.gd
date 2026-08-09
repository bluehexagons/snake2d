class_name DebugOverlay
extends PanelContainer

## Debug-build teaching aid for inspecting model state and stepping paused ticks.

const MAX_EVENTS := 5

@onready var details_label: Label = %DetailsLabel

var _game_session: GameSession
var _gameplay: Gameplay
var _recent_events: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	set_process(OS.is_debug_build())
	set_process_unhandled_input(OS.is_debug_build())

func configure(game_session: GameSession, gameplay: Gameplay) -> void:
	_game_session = game_session
	_gameplay = gameplay
	_game_session.state_changed.connect(_on_session_state_changed)
	_gameplay.tick_completed.connect(_on_tick_completed)
	_gameplay.food_spawned.connect(_on_food_spawned)

func _process(_delta: float) -> void:
	if visible:
		_refresh_text()

func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build() or not event is InputEventKey or not event.pressed or event.echo:
		return

	if event.keycode == KEY_F1:
		visible = not visible
		if visible:
			_refresh_text()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_F2 and visible and _game_session.state == GameSession.State.PAUSED:
		var result := _gameplay.advance_one_tick_and_snap()
		_add_event("manual step: %s" % SnakeGame.StepResult.keys()[result])
		_refresh_text()
		get_viewport().set_input_as_handled()

func _refresh_text() -> void:
	if _game_session == null or _gameplay == null:
		return

	var snapshot := _gameplay.get_debug_snapshot()
	var lines: Array[String] = [
		"F1 hide  |  F2 step while paused",
		"session: %s" % _game_session.get_state_name(),
		"tree paused: %s" % get_tree().paused,
	]
	if bool(snapshot.get("round_ready", false)):
		lines.append("tick: %d  interval: %.3fs" % [snapshot.tick, snapshot.tick_seconds])
		lines.append("accumulator: %.3fs" % snapshot.accumulator)
		lines.append("head: %s  food: %s" % [snapshot.head, snapshot.food])
		lines.append("direction: %s -> %s" % [snapshot.direction, snapshot.queued_direction])
		lines.append("waiting: %s  score: %d" % [snapshot.waiting_for_input, snapshot.score])
		lines.append("body: %s" % snapshot.body)
	else:
		lines.append("round model: not created")

	if not _recent_events.is_empty():
		lines.append("events:")
		for event_text in _recent_events:
			lines.append("  %s" % event_text)
	details_label.text = "\n".join(lines)

func _on_session_state_changed(_previous: GameSession.State, current: GameSession.State) -> void:
	_add_event("state: %s" % GameSession.State.keys()[current])

func _on_tick_completed(result: SnakeGame.StepResult) -> void:
	_add_event("tick: %s" % SnakeGame.StepResult.keys()[result])

func _on_food_spawned(position: Vector2) -> void:
	_add_event("food view: %s" % position)

func _add_event(event_text: String) -> void:
	_recent_events.append(event_text)
	if _recent_events.size() > MAX_EVENTS:
		_recent_events.pop_front()
