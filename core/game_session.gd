class_name GameSession
extends Node

## Owns one play session and coordinates gameplay with persisted high scores.

signal state_changed(previous_state: State, current_state: State)
signal round_ended(final_score: int)
signal score_updated(score: int)
signal high_scores_updated(mode: GameMode.Value, high_scores: Array[int])

enum State {
	MAIN_MENU,
	PLAYING,
	PAUSED,
	GAME_OVER,
}

var state: State = State.MAIN_MENU
var current_score := 0
var high_scores_by_mode: Dictionary = {}
var current_mode: GameMode.Value = GameMode.Value.CLASSIC
var current_world_seed := 0

var _gameplay: Gameplay
var _high_score_store: HighScoreStore

## Supplies the authored dependencies owned by Main.
func configure(gameplay: Gameplay, high_score_store: HighScoreStore) -> void:
	_gameplay = gameplay
	_high_score_store = high_score_store
	high_scores_by_mode = _high_score_store.load_high_scores_by_mode()
	_apply_tree_pause()

	if not _gameplay.game_over.is_connected(end_round):
		_gameplay.game_over.connect(end_round)
	if not _gameplay.score_updated.is_connected(_on_gameplay_score_updated):
		_gameplay.score_updated.connect(_on_gameplay_score_updated)

func start_new_round(
	mode: GameMode.Value = GameMode.Value.CLASSIC,
	world_seed: int = 0
) -> void:
	if state == State.PLAYING:
		return

	current_score = 0
	current_mode = mode
	current_world_seed = world_seed
	_transition_to(State.PLAYING)
	_gameplay.start_game(current_mode, current_world_seed)

func pause_round() -> void:
	if state != State.PLAYING:
		return
	_transition_to(State.PAUSED)

func resume_round() -> void:
	if state != State.PAUSED:
		return
	_transition_to(State.PLAYING)

func toggle_pause() -> void:
	if state == State.PLAYING:
		pause_round()
	elif state == State.PAUSED:
		resume_round()

func end_round(final_score: int) -> void:
	if state != State.PLAYING and state != State.PAUSED:
		return

	current_score = final_score

	var high_scores := get_high_scores(current_mode)
	var score_added := false
	for i in high_scores.size():
		if final_score > high_scores[i]:
			high_scores.insert(i, final_score)
			score_added = true
			break

	if not score_added and high_scores.size() < _high_score_store.max_scores:
		high_scores.append(final_score)

	high_scores = _high_score_store.sanitize_high_scores(high_scores)
	high_scores_by_mode[GameMode.key(current_mode)] = high_scores
	_high_score_store.save_high_scores_by_mode(high_scores_by_mode)

	round_ended.emit(final_score)
	high_scores_updated.emit(current_mode, get_high_scores(current_mode))
	_transition_to(State.GAME_OVER)

func return_to_menu() -> void:
	if state == State.MAIN_MENU:
		return
	_gameplay.cleanup()
	current_score = 0
	_transition_to(State.MAIN_MENU)

func clear_high_scores() -> void:
	high_scores_by_mode = _high_score_store.empty_score_tables()
	_high_score_store.save_high_scores_by_mode(high_scores_by_mode)
	for mode in GameMode.ALL:
		high_scores_updated.emit(mode, get_high_scores(mode))

func is_round_active() -> bool:
	return state == State.PLAYING or state == State.PAUSED

func is_round_paused() -> bool:
	return state == State.PAUSED

func get_current_score() -> int:
	return current_score

func get_high_scores(mode: GameMode.Value = current_mode) -> Array[int]:
	var scores = high_scores_by_mode.get(GameMode.key(mode), [])
	var copy: Array[int] = []
	copy.assign(scores)
	return copy

func get_all_high_scores() -> Dictionary:
	var copy := {}
	for mode in GameMode.ALL:
		copy[GameMode.key(mode)] = get_high_scores(mode)
	return copy

func get_state_name() -> String:
	return State.keys()[state]

func _on_gameplay_score_updated(new_score: int) -> void:
	current_score = new_score
	score_updated.emit(current_score)

func _transition_to(new_state: State) -> void:
	if new_state == state:
		return
	var previous_state := state
	state = new_state
	_apply_tree_pause()
	state_changed.emit(previous_state, state)

func _apply_tree_pause() -> void:
	if is_inside_tree():
		get_tree().paused = state != State.PLAYING
