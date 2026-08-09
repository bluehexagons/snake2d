class_name TouchGesture
extends RefCounted

## Tracks one finger without depending on nodes, cameras, or game rules.
## Screen-relative motion stays stable when the viewport uses content stretching.

var start_position: Vector2
var latest_position: Vector2
var accumulated_screen_delta := Vector2.ZERO
var swipe_committed := false

func _init(position := Vector2.ZERO) -> void:
	start_position = position
	latest_position = position

func update_drag(position: Vector2, screen_relative: Vector2, threshold_pixels: float) -> Vector2i:
	latest_position = position
	if swipe_committed:
		return Vector2i.ZERO

	accumulated_screen_delta += screen_relative
	var safe_threshold := maxf(1.0, threshold_pixels)
	if accumulated_screen_delta.length_squared() < safe_threshold * safe_threshold:
		return Vector2i.ZERO

	swipe_committed = true
	return cardinal_direction(accumulated_screen_delta)

func is_tap(canceled: bool) -> bool:
	return not canceled and not swipe_committed

static func cardinal_direction(vector: Vector2) -> Vector2i:
	if vector == Vector2.ZERO:
		return Vector2i.ZERO
	if absf(vector.x) > absf(vector.y):
		return Vector2i(1 if vector.x > 0.0 else -1, 0)
	return Vector2i(0, 1 if vector.y > 0.0 else -1)

static func threshold_for_window(
	window_size: Vector2i,
	window_ratio: float,
	minimum_pixels: float
) -> float:
	var shortest_side := float(mini(absi(window_size.x), absi(window_size.y)))
	return maxf(minimum_pixels, shortest_side * maxf(0.0, window_ratio))
