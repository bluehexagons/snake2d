class_name SnakeSegment
extends ColorRect

## Reusable authored visual for both the snake head and pooled body segments.

var alive_color := Color.WHITE

func configure(segment_size: int, segment_color: Color) -> void:
	size = Vector2.ONE * segment_size
	alive_color = segment_color
	color = alive_color
	show()

func mark_dead() -> void:
	var dead_color := Color(0.78, 0.12, 0.12, color.a)
	color = color.lerp(dead_color, 0.6)
