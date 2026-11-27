class_name ObstacleView
extends Node2D

## Keeps solid Obstacles tiles and hollow Pitfall hazards distinct at small scales.

const BLOCK_COLOR := Color("#687d73")
const PIT_RIM_COLOR := Color("#bd7b86")
const PIT_CENTER_COLOR := Color("#101214")

var _cell_size := 32.0
var _is_pit := false

func _ready() -> void:
	z_index = 0
	scale = Vector2.ZERO
	queue_redraw()
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func configure(cell_size: int, is_pit: bool) -> void:
	_cell_size = float(cell_size)
	_is_pit = is_pit
	queue_redraw()

func _draw() -> void:
	if _is_pit:
		_draw_pit()
	else:
		_draw_block()

func _draw_pit() -> void:
	var center := Vector2.ONE * _cell_size * 0.5
	draw_circle(center, _cell_size * 0.43, PIT_RIM_COLOR, true, -1.0, true)
	draw_circle(center, _cell_size * 0.34, PIT_CENTER_COLOR, true, -1.0, true)

func _draw_block() -> void:
	var cell := Rect2(Vector2.ZERO, Vector2.ONE * _cell_size)
	draw_rect(cell.grow(-_cell_size * 0.08), BLOCK_COLOR)
