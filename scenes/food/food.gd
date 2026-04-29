extends Node2D

const ConfigData = preload("res://autoload/config.gd")

const BASE_COLOR := Color(0.854902, 0.14902, 0.14902, 1)
const SPAWN_DURATION := 0.28
const EAT_DURATION := 0.22

# Visual state, all driven by tweens.
var _size: float = float(ConfigData.GRID_SIZE)
var _scale: float = 0.0
var _corner_radius: float = 6.0
var _color: Color = BASE_COLOR
var _eaten: bool = false

@onready var _color_rect: ColorRect = $ColorRect

func _ready() -> void:
	# Hide the legacy ColorRect; we paint the food ourselves so we can round corners.
	if _color_rect:
		_color_rect.visible = false
	z_index = 0
	queue_redraw()
	_play_spawn()

func _draw() -> void:
	var s := _size * _scale
	if s <= 0.0:
		return
	# Center the visual within the cell so shrink animations stay centered.
	var offset := (_size - s) * 0.5
	var rect := Rect2(Vector2(offset, offset), Vector2(s, s))
	var radius: float = min(_corner_radius, s * 0.5)
	_draw_rounded_rect(rect, radius, _color)

func _draw_rounded_rect(rect: Rect2, radius: float, color: Color) -> void:
	if radius <= 0.5:
		draw_rect(rect, color, true)
		return
	# Body + sides via two overlapping rects, then four corner circles.
	var inner_h := Rect2(
		Vector2(rect.position.x + radius, rect.position.y),
		Vector2(rect.size.x - radius * 2.0, rect.size.y)
	)
	var inner_v := Rect2(
		Vector2(rect.position.x, rect.position.y + radius),
		Vector2(rect.size.x, rect.size.y - radius * 2.0)
	)
	if inner_h.size.x > 0.0 and inner_h.size.y > 0.0:
		draw_rect(inner_h, color, true)
	if inner_v.size.x > 0.0 and inner_v.size.y > 0.0:
		draw_rect(inner_v, color, true)
	var corners := [
		rect.position + Vector2(radius, radius),
		Vector2(rect.position.x + rect.size.x - radius, rect.position.y + radius),
		Vector2(rect.position.x + radius, rect.position.y + rect.size.y - radius),
		rect.position + rect.size - Vector2(radius, radius),
	]
	for c in corners:
		draw_circle(c, radius, color)

func _play_spawn() -> void:
	_scale = 0.0
	_color = BASE_COLOR
	_corner_radius = 6.0
	queue_redraw()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_method(_set_scale, 0.0, 1.08, SPAWN_DURATION * 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.chain().tween_method(_set_scale, 1.08, 1.0, SPAWN_DURATION * 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# Public: gameplay calls this when the snake eats the food. The node frees itself
# at the end of the animation. Returns the tween so callers can await it if needed.
func eat() -> Tween:
	if _eaten:
		return null
	_eaten = true
	# Make sure we draw beneath the snake head so it slides over us.
	z_index = -1
	var tween := create_tween()
	tween.set_parallel(true)
	# Round the corners further as we shrink, so it feels like it's being absorbed.
	tween.tween_method(_set_corner_radius, _corner_radius, _size * 0.5, EAT_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_scale, _scale, 0.0, EAT_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	# Soften & fade so it doesn't pop out abruptly.
	tween.tween_method(_set_color, _color, Color(_color.r, _color.g, _color.b, 0.0), EAT_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)
	return tween

func _set_scale(v: float) -> void:
	_scale = v
	queue_redraw()

func _set_corner_radius(v: float) -> void:
	_corner_radius = v
	queue_redraw()

func _set_color(c: Color) -> void:
	_color = c
	queue_redraw()
