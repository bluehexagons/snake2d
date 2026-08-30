class_name ObstacleView
extends Node2D

## Draws either a solid seeded wall or a Pitfall hazard without texture assets.

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
		_draw_wall()

func _draw_pit() -> void:
	var center := Vector2.ONE * _cell_size * 0.5
	var radius := _cell_size * 0.43
	draw_circle(center, radius, Color(0.025, 0.035, 0.03, 1.0))
	draw_arc(center, radius, 0.0, TAU, 32, Color(0.47, 0.18, 0.25, 1.0), 2.0, true)
	draw_arc(center, radius * 0.62, 0.0, TAU, 24, Color(0.18, 0.08, 0.12, 1.0), 2.0, true)

func _draw_wall() -> void:
	var inset := maxf(2.0, _cell_size * 0.08)
	var rect := Rect2(Vector2.ONE * inset, Vector2.ONE * (_cell_size - inset * 2.0))
	draw_style_box(_wall_style(), rect)
	var mortar := Color(0.12, 0.15, 0.14, 0.8)
	var middle_y := _cell_size * 0.5
	draw_line(Vector2(inset, middle_y), Vector2(_cell_size - inset, middle_y), mortar, 1.0)
	draw_line(Vector2(_cell_size * 0.5, inset), Vector2(_cell_size * 0.5, middle_y), mortar, 1.0)
	draw_line(Vector2(_cell_size * 0.32, middle_y), Vector2(_cell_size * 0.32, _cell_size - inset), mortar, 1.0)

func _wall_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.25, 0.36, 0.32, 1.0)
	style.border_color = Color(0.44, 1.0, 0.76, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	return style
