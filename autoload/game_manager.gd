extends Node

# Signals to communicate with UI
signal game_started
signal game_paused
signal game_resumed
signal game_over(final_score: int)
signal score_updated(score: int)
signal high_scores_updated(high_scores: Array[int])

# Game state
var is_running := false
var is_paused := false
var current_score := 0
var high_scores: Array[int] = []

# Dependencies (will be set via setters)
var gameplay: Node
var save_data_util: RefCounted
var config: RefCounted
var ui_state_manager: Node

func _ready() -> void:
	# Load high scores on startup
	if save_data_util:
		high_scores = save_data_util.load_high_scores()

func start_game() -> void:
	is_running = true
	is_paused = false
	current_score = 0
	
	# Reset gameplay
	if gameplay and gameplay.has_method("start_game"):
		gameplay.start_game()
	
	# Notify UI
	game_started.emit()
	score_updated.emit(current_score)

func pause_game() -> void:
	if not is_running or is_paused:
		return
	
	is_paused = true
	
	# Pause gameplay
	if gameplay and gameplay.has_method("set_paused"):
		gameplay.set_paused(true)
	
	# Notify UI
	game_paused.emit()

func resume_game() -> void:
	if not is_running or not is_paused:
		return
	
	is_paused = false
	
	# Resume gameplay
	if gameplay and gameplay.has_method("set_paused"):
		gameplay.set_paused(false)
	
	# Notify UI
	game_resumed.emit()

func end_game(final_score: int) -> void:
	is_running = false
	is_paused = false
	current_score = final_score
	
	# Update high scores
	var score_added := false
	for i in high_scores.size():
		if final_score > high_scores[i]:
			high_scores.insert(i, final_score)
			score_added = true
			break
	
	if not score_added and high_scores.size() < config.get_max_high_scores():
		high_scores.append(final_score)
	
	# Sanitize and save high scores
	if save_data_util:
		high_scores = save_data_util.sanitize_high_scores(high_scores)
		save_data_util.save_high_scores(high_scores)
	
	# Notify UI
	game_over.emit(final_score)
	high_scores_updated.emit(high_scores)

func reset_game() -> void:
	end_game(0)  # This will handle cleanup and reset

func add_score(points: int) -> void:
	if not is_running:
		return
	
	current_score += points
	score_updated.emit(current_score)

func is_game_running() -> bool:
	return is_running

func is_game_paused() -> bool:
	return is_paused

func get_current_score() -> int:
	return current_score

func get_high_scores() -> Array[int]:
	return high_scores.duplicate()  # Return copy to prevent external modification

# Setter methods for dependency injection
func set_gameplay(gameplay_node: Node) -> void:
	gameplay = gameplay_node

func set_save_data_util(save_data: RefCounted) -> void:
	save_data_util = save_data

func set_config(config_node: RefCounted) -> void:
	config = config_node

func set_ui_state_manager(ui_manager: Node) -> void:
	ui_state_manager = ui_manager