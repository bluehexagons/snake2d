extends Node2D

signal moved(new_position)
signal grew
signal died

const GRID_SIZE = 32
@export var direction = Vector2.RIGHT  # Made public for camera access
var next_direction = Vector2.RIGHT  # Buffer the next direction
var can_move = true

func _ready():
	position = position.snapped(Vector2(GRID_SIZE, GRID_SIZE))

func _process(_delta):
	if can_move:
		var input_x = Input.get_axis("left", "right")
		var input_y = Input.get_axis("up", "down")
		
		# Only update direction if there's significant input
		if abs(input_x) > 0.5 or abs(input_y) > 0.5:
			# Choose the strongest input direction
			if abs(input_x) > abs(input_y):
				next_direction = Vector2(sign(input_x), 0)
			else:
				next_direction = Vector2(0, sign(input_y))
			
			# Don't allow reversing
			if next_direction == -direction:
				next_direction = direction

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
