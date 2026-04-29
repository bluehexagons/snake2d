extends Node2D

const ConfigData = preload("res://autoload/config.gd")

signal moved(new_position: Vector2)
signal grew()
signal died()
signal first_move()

@export var direction := Vector2.RIGHT
var next_direction: Vector2 = Vector2.RIGHT
var can_move := true
var waiting_for_input := true

# Logical (grid-snapped) head position; the actual `position` is animated visually.
var logical_position: Vector2
var visual_prev_position: Vector2

var _direction_indicator: Polygon2D

func _ready() -> void:
	Input.emulate_touch_from_mouse = true
	Input.emulate_mouse_from_touch = true
	position = position.snapped(Vector2(ConfigData.GRID_SIZE, ConfigData.GRID_SIZE))
	logical_position = position
	visual_prev_position = position

	_direction_indicator = Polygon2D.new()
	_direction_indicator.color = Color(0.85, 1.0, 0.4, 0.55)
	add_child(_direction_indicator)
	_update_direction_indicator()

func _update_direction_indicator() -> void:
	var half := ConfigData.GRID_SIZE / 2.0
	var tip := Vector2(half, half) + next_direction * (half - 5)
	var perp := Vector2(-next_direction.y, next_direction.x)
	_direction_indicator.polygon = PackedVector2Array([
		tip,
		tip - next_direction * 7 + perp * 4,
		tip - next_direction * 7 - perp * 4
	])

func _input(event: InputEvent) -> void:
	if not can_move:
		return

	var touch_dir := Vector2.ZERO

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var to_mouse := (get_global_mouse_position() - global_position).normalized()
		if abs(to_mouse.x) > abs(to_mouse.y):
			touch_dir = Vector2(sign(to_mouse.x), 0)
		else:
			touch_dir = Vector2(0, sign(to_mouse.y))

	if event.is_action_pressed("up"):
		touch_dir = Vector2(0, -1)
	elif event.is_action_pressed("down"):
		touch_dir = Vector2(0, 1)
	elif event.is_action_pressed("left"):
		touch_dir = Vector2(-1, 0)
	elif event.is_action_pressed("right"):
		touch_dir = Vector2(1, 0)

	if touch_dir != Vector2.ZERO and (touch_dir != -direction or waiting_for_input):
		next_direction = touch_dir
		_update_direction_indicator()
		if waiting_for_input:
			waiting_for_input = false
			first_move.emit()

func move() -> void:
	if waiting_for_input:
		can_move = true
		return

	direction = next_direction
	var new_position := logical_position + direction * ConfigData.GRID_SIZE
	
	if new_position.x < 0 or new_position.x >= ConfigData.GRID_WIDTH * ConfigData.GRID_SIZE or new_position.y < 0 or new_position.y >= ConfigData.GRID_HEIGHT * ConfigData.GRID_SIZE:
		_direction_indicator.hide()
		died.emit()
		return
		
	visual_prev_position = logical_position
	logical_position = new_position
	position = new_position
	can_move = true
	moved.emit(new_position)

func grow() -> void:
	grew.emit()

func hide_indicator() -> void:
	_direction_indicator.hide()

# Apply visual interpolation between the previous and current logical cell.
# `t` is the normalized [0,1] progress through the current move tick.
func apply_visual_interp(t: float) -> void:
	t = clamp(t, 0.0, 1.0)
	# Smootherstep: 6t^5 - 15t^4 + 10t^3. Gradual start, fast middle, soft tail.
	var eased := t * t * t * (t * (t * 6.0 - 15.0) + 10.0)
	position = visual_prev_position.lerp(logical_position, eased)
