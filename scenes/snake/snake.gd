extends Node2D

signal moved(new_position)
signal grew
signal died

const GRID_SIZE = 32
var direction = Vector2.RIGHT
var next_direction = Vector2.RIGHT  # Buffer the next direction
var can_move = true

func _ready():
	position = position.snapped(Vector2(GRID_SIZE, GRID_SIZE))

func _process(_delta):
	if can_move:
		# Only update next_direction if it's a valid turn
		if Input.is_action_pressed("up") and direction != Vector2.DOWN:
			next_direction = Vector2.UP
		if Input.is_action_pressed("down") and direction != Vector2.UP:
			next_direction = Vector2.DOWN
		if Input.is_action_pressed("left") and direction != Vector2.RIGHT:
			next_direction = Vector2.LEFT
		if Input.is_action_pressed("right") and direction != Vector2.LEFT:
			next_direction = Vector2.RIGHT

func move():
	# Apply the buffered direction
	direction = next_direction
	var new_position = position + direction * GRID_SIZE
	
	# Check wall collision using tilemap bounds
	if new_position.x < 0 or new_position.x >= 768 or \
	   new_position.y < 0 or new_position.y >= 576:
		died.emit()
		return
		
	position = new_position
	can_move = true
	moved.emit(position)

func grow():
	grew.emit()
