class_name SnakeView
extends Node2D

## Pixel-space presentation for the model's snake head.

const HEAD_COLOR := Color(0.055, 0.56, 0.14, 1)

var cell_size := 32
var logical_position := Vector2.ZERO
var visual_previous_position := Vector2.ZERO
var queued_direction := Vector2i.RIGHT

@onready var _head: SnakeSegment = $Head
var _direction_indicator: Polygon2D

func _ready() -> void:
	_direction_indicator = Polygon2D.new()
	_direction_indicator.color = Color(0.85, 1.0, 0.4, 0.55)
	add_child(_direction_indicator)
	_resize_head()
	_update_direction_indicator()

func configure(new_cell_size: int) -> void:
	cell_size = new_cell_size
	if is_node_ready():
		_resize_head()
		_update_direction_indicator()

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
		_direction_indicator.show()
		_update_direction_indicator()

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

func _update_direction_indicator() -> void:
	var half := cell_size / 2.0
	var direction := Vector2(queued_direction)
	var tip := Vector2(half, half) + direction * (half - 5.0)
	var perpendicular := Vector2(-direction.y, direction.x)
	_direction_indicator.polygon = PackedVector2Array([
		tip,
		tip - direction * 7.0 + perpendicular * 4.0,
		tip - direction * 7.0 - perpendicular * 4.0,
	])
