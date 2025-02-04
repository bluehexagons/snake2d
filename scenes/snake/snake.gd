extends Node2D

const GRID_SIZE = 32
var direction = Vector2.RIGHT
var can_move = true

func _ready():
	position = position.snapped(Vector2(GRID_SIZE, GRID_SIZE))

func _process(_delta):
	if can_move:
		if Input.is_action_pressed("ui_up") and direction != Vector2.DOWN:
			direction = Vector2.UP
		if Input.is_action_pressed("ui_down") and direction != Vector2.UP:
			direction = Vector2.DOWN
		if Input.is_action_pressed("ui_left") and direction != Vector2.RIGHT:
			direction = Vector2.LEFT
		if Input.is_action_pressed("ui_right") and direction != Vector2.LEFT:
			direction = Vector2.RIGHT

func move():
	position += direction * GRID_SIZE
	can_move = true
