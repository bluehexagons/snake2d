class_name Gameplay
extends Node2D

signal score_updated(new_score)
signal game_over(final_score)
signal food_spawned(position)
signal snake_moved(position)
signal snake_grew(position)

const Snake = preload("res://scenes/snake/snake.tscn")
const Food = preload("res://scenes/food/food.tscn")

const GRID_SIZE := 32
const GRID_WIDTH := 24
const GRID_HEIGHT := 18

const BASE_TIMER_WAIT := 0.2
const MIN_TIMER_WAIT := 0.05  # Maximum speed
const SPEED_INCREASE_PER_SEGMENT := 0.005  # How much faster per segment

var snake: Node2D
var food: Node2D
var tail_segments: Array[ColorRect] = []
var tail_positions: Array[Vector2] = []
var score := 0
var game_over_state := false
var game_timer: Timer = null

# Get a reference to the parent game world
@onready var game_world: Node2D = get_parent()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_INHERIT

func start_game() -> void:
	# Initialize game state
	game_over_state = false
	score = 0
	score_updated.emit(score)
	
	# Clear any existing segments
	for segment in tail_segments:
		segment.queue_free()
	tail_segments.clear()
	tail_positions.clear()
	
	# Initialize snake
	if snake:
		snake.queue_free()
	snake = Snake.instantiate()
	game_world.add_child(snake)
	@warning_ignore("integer_division")
	snake.position = Vector2(GRID_WIDTH/2, GRID_HEIGHT/2) * GRID_SIZE
	snake.moved.connect(_on_snake_moved)
	snake.grew.connect(_on_snake_grew)
	snake.died.connect(_on_snake_died)
	
	# Spawn initial food
	spawn_food()
	
	# Start the game timer
	if game_timer:
		game_timer.queue_free()
	game_timer = Timer.new()
	add_child(game_timer)
	game_timer.wait_time = BASE_TIMER_WAIT
	game_timer.timeout.connect(_on_timer_timeout)
	game_timer.start()
	
	AudioManager.reset_pitch()

func is_position_occupied(pos: Vector2) -> bool:
	# Convert position to grid coordinates
	var grid_pos := pos / GRID_SIZE
	
	# Check snake head
	if snake and (snake.position / GRID_SIZE) == grid_pos:
		return true
	
	# Check tail segments
	for segment in tail_segments:
		if (segment.position / GRID_SIZE) == grid_pos:
			return true
	
	return false

func spawn_food() -> void:
	if food:
		food.queue_free()
	
	# Find an unoccupied position
	var valid_position := false
	var x := 0
	var y := 0
	
	while not valid_position:
		x = randi_range(0, GRID_WIDTH - 2)
		y = randi_range(0, GRID_HEIGHT - 2)
		var test_pos := Vector2(x, y) * GRID_SIZE
		valid_position = not is_position_occupied(test_pos)
	
	food = Food.instantiate()
	game_world.add_child(food)
	food.position = Vector2(x, y) * GRID_SIZE
	food_spawned.emit(food.position)

func _update_game_speed() -> void:
	if game_timer:
		var segment_count := tail_segments.size()
		var new_wait: float = max(
			BASE_TIMER_WAIT - (segment_count * SPEED_INCREASE_PER_SEGMENT),
			MIN_TIMER_WAIT
		)
		game_timer.wait_time = new_wait

func _on_snake_moved(new_position) -> void:
	if game_over_state:
		return
	
	AudioManager.play_move()
	snake_moved.emit(new_position)
	
	# Store the current position for tail
	tail_positions.insert(0, new_position)
	
	# Check if snake ate food
	var ate_food: bool = food and (new_position == food.position)
	if ate_food:
		snake.grow()
		# Don't remove the last tail position when growing
		spawn_food()
	else:
		# Only remove last position if we didn't eat food
		if tail_positions.size() > tail_segments.size() + 1:
			tail_positions.pop_back()
	
	# Move tail
	for i in tail_segments.size():
		tail_segments[i].position = tail_positions[i + 1]
	
	# Check tail collision
	if not ate_food:  # Don't check collision if we just ate (prevents false positives)
		for segment in tail_segments:
			if segment.position == new_position:
				_on_snake_died()
				return

func _on_snake_grew() -> void:
	AudioManager.play_eat()
	
	var segment := ColorRect.new()
	segment.size = Vector2(GRID_SIZE, GRID_SIZE)
	
	# Vary the color based on position in tail
	var base_color := Color(0.0862745, 0.741176, 0.0862745)
	var segment_count := tail_segments.size()
	
	if segment_count == 0:
		# First segment should be slightly darker than base
		segment.color = base_color.darkened(0.1)
	else:
		# Gradually lighten towards the tail end
		var progress := float(segment_count) / 20.0
		var hue_shift := randf_range(-0.02, 0.02)
		var new_color := base_color.lightened(progress * 0.3)
		new_color = Color.from_hsv(
			fmod(new_color.h + hue_shift, 1.0),
			new_color.s,
			new_color.v
		)
		segment.color = new_color
	
	# Position the new segment at the food location
	segment.position = food.position
	
	game_world.add_child(segment)
	tail_segments.append(segment)
	
	# Update game speed
	_update_game_speed()
	
	# Update score
	score += 10
	score_updated.emit(score)
	snake_grew.emit(segment.position)

func _on_snake_died() -> void:
	AudioManager.play_die()
	AudioManager.reset_pitch()
	
	game_over_state = true
	
	# Change snake head color
	var head := snake.get_node("Head")
	if head:
		head.color = Color(0.8, 0.2, 0.2, 1)
	
	# Change tail segment colors to reddish versions of their current colors
	for segment in tail_segments:
		var current_color := segment.color
		segment.color = Color(
			lerp(current_color.g, 0.8, 0.5),
			current_color.r * 0.1,
			current_color.b * 0.1,
			current_color.a
		)
	
	# Signal game over with final score
	game_over.emit(score)

func _on_timer_timeout() -> void:
	if game_over_state:
		return
	snake.can_move = false
	snake.move()

func set_paused(is_paused: bool) -> void:
	if game_timer:
		game_timer.paused = is_paused
	if snake:
		snake.process_mode = Node.PROCESS_MODE_DISABLED if is_paused else Node.PROCESS_MODE_INHERIT

func cleanup() -> void:
	if snake:
		snake.queue_free()
		snake = null
	if food:
		food.queue_free()
		food = null
	for segment in tail_segments:
		segment.queue_free()
	tail_segments.clear()
	tail_positions.clear()
	
	if game_timer:
		game_timer.stop()
		game_timer.queue_free()
		game_timer = null
		
	game_over_state = false

func get_snake_position() -> Vector2:
	return snake.position if snake else Vector2.ZERO

func get_food_position() -> Vector2:
	return food.position if food else Vector2.ZERO
	
func get_snake_direction() -> Vector2:
	return snake.direction if snake else Vector2.RIGHT
	
func get_weighted_snake_center() -> Vector2:
	if snake and not tail_segments.is_empty():
		var sum_pos := snake.position * 2.0
		var total_weight := 2.0
		for i in tail_segments.size():
			var weight := 1.0 / (i + 2.0)
			sum_pos += tail_segments[i].position * weight
			total_weight += weight
		return sum_pos / total_weight
	return snake.position if snake else Vector2.ZERO