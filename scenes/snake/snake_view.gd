class_name SnakeView
extends Node2D

## Pixel-space presentation for the model's snake head.

const HEAD_COLOR := Color(0.055, 0.56, 0.14, 1)
## Matches the old translucent arrow's perceived color over the head without
## re-blending against subpixel edges as the snake moves.
const DIRECTION_COLOR := Color(0.50, 0.80, 0.30, 1)

var cell_size := 32
var logical_position := Vector2.ZERO
var visual_previous_position := Vector2.ZERO
var queued_direction := Vector2i.RIGHT

@onready var _head: SnakeSegment = $Head
var _direction_indicator: Polygon2D

func _ready() -> void:
	_direction_indicator = Polygon2D.new()
	_direction_indicator.name = "DirectionIndicator"
	_direction_indicator.color = DIRECTION_COLOR
	add_child(_direction_indicator)
	_resize_head()
	_resize_direction_indicator()
	_update_direction_indicator_rotation()

func configure(new_cell_size: int) -> void:
	cell_size = new_cell_size
	if is_node_ready():
		_resize_head()
		_resize_direction_indicator()

func snap_to_cell(cell: Vector2i) -> void:
	logical_position = Vector2(cell * cell_size)
	visual_previous_position = logical_position
	position = logical_position

func move_to_cell(cell: Vector2i) -> void:
	visual_previous_position = logical_position
	logical_position = Vector2(cell * cell_size)
	position = logical_position

func show_queued_direction(direction: Vector2i) -> void:
	queued_direction = direction
	if _direction_indicator:
		_update_direction_indicator_rotation()
		_direction_indicator.show()

func hide_direction_indicator() -> void:
	if _direction_indicator:
		_direction_indicator.hide()

func mark_dead() -> void:
	hide_direction_indicator()
	_head.mark_dead()

func apply_visual_interpolation(progress: float) -> void:
	var t := clampf(progress, 0.0, 1.0)
	var eased := t * t * t * (t * (t * 6.0 - 15.0) + 10.0)
	position = visual_previous_position.lerp(logical_position, eased)

func _resize_head() -> void:
	_head.configure(cell_size, HEAD_COLOR)

func _resize_direction_indicator() -> void:
	var half := cell_size / 2.0
	_direction_indicator.position = Vector2(half, half)
	# Keep one right-facing mesh and rotate it around the center of the head.
	# Replacing the polygon at a turn can produce a one-frame flash in WebGL.
	var tip_distance := half - 5.0
	_direction_indicator.polygon = PackedVector2Array([
		Vector2(tip_distance, 0.0),
		Vector2(tip_distance - 7.0, 4.0),
		Vector2(tip_distance - 7.0, -4.0),
	])

func _update_direction_indicator_rotation() -> void:
	_direction_indicator.rotation = Vector2(queued_direction).angle()
