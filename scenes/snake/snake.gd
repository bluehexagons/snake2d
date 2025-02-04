extends Node2D

signal moved(new_position)
signal grew
signal died

const GRID_SIZE = 32
var direction = Vector2.RIGHT
var can_move = true

func _ready():
	position = position.snapped(Vector2(GRID_SIZE, GRID_SIZE))

func _process(_delta):
	if can_move:
		if Input.is_action_pressed("up") and direction != Vector2.DOWN:
			direction = Vector2.UP
		if Input.is_action_pressed("down") and direction != Vector2.UP:
			direction = Vector2.DOWN
		if Input.is_action_pressed("left") and direction != Vector2.RIGHT:
			direction = Vector2.LEFT
		if Input.is_action_pressed("right") and direction != Vector2.LEFT:
			direction = Vector2.RIGHT

func move():
	var new_position = position + direction * GRID_SIZE
	
	# Check wall collision using viewport bounds
	if new_position.x < 0 or new_position.x >= 800 or \
	   new_position.y < 0 or new_position.y >= 600:
		died.emit()
		return
		
	position = new_position
	can_move = true
	moved.emit(position)

func grow():
	grew.emit()
