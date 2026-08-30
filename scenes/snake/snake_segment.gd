class_name SnakeSegment
extends ColorRect

## Reusable authored visual for both the snake head and pooled body segments.

var alive_color := Color.WHITE

func configure(segment_size: int, segment_color: Color) -> void:
	set_alive_color(segment_color)
	show_full_size(segment_size)

func set_alive_color(segment_color: Color) -> void:
	alive_color = segment_color
	color = alive_color

func show_full_size(segment_size: int) -> void:
	size = Vector2.ONE * segment_size
	show()

## Clips the terminal tail cell toward the body as the head extends forward.
func apply_tail_retraction(
	cell_origin: Vector2,
	forward_direction: Vector2i,
	progress: float,
	segment_size: int
) -> void:
	var t := clampf(progress, 0.0, 1.0)
	var full_size := float(segment_size)
	var remaining := full_size * (1.0 - t)
	position = cell_origin
	size = Vector2.ONE * full_size

	if forward_direction.x != 0:
		size.x = remaining
		if forward_direction.x > 0:
			position.x += full_size - remaining
	else:
		size.y = remaining
		if forward_direction.y > 0:
			position.y += full_size - remaining

	visible = remaining > 0.01

func mark_dead() -> void:
	var dead_color := Color(0.78, 0.12, 0.12, color.a)
	color = color.lerp(dead_color, 0.6)
