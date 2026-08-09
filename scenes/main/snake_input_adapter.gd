class_name SnakeInputAdapter
extends Node2D

## Translates device-specific events into cardinal grid directions.
## It deliberately does not decide whether a requested turn is legal.

signal direction_requested(direction: Vector2i)

@export_category("Touch Gestures")
@export_range(0.005, 0.1, 0.005) var drag_threshold_window_ratio := 0.025
@export_range(8.0, 96.0, 1.0) var minimum_drag_threshold_pixels := 16.0

var _gameplay: Gameplay
var _touch_gestures: Dictionary[int, TouchGesture] = {}
var _enabled := false

func _ready() -> void:
	set_process_unhandled_input(_enabled)

func configure(gameplay: Gameplay) -> void:
	_gameplay = gameplay

func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	set_process_unhandled_input(enabled)
	if not enabled:
		_touch_gestures.clear()

func _unhandled_input(event: InputEvent) -> void:
	if not _enabled:
		return

	var requested := Vector2i.ZERO
	var consume_touch_event := false

	if event.is_action_pressed("up"):
		requested = Vector2i.UP
	elif event.is_action_pressed("down"):
		requested = Vector2i.DOWN
	elif event.is_action_pressed("left"):
		requested = Vector2i.LEFT
	elif event.is_action_pressed("right"):
		requested = Vector2i.RIGHT
	elif event is InputEventMouseButton:
		if (
			event.device != InputEvent.DEVICE_ID_EMULATION
			and event.button_index == MOUSE_BUTTON_LEFT
			and event.pressed
		):
			requested = _direction_toward_screen_position(event.position)
	elif event is InputEventMouseMotion:
		if (
			event.device != InputEvent.DEVICE_ID_EMULATION
			and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) > 0
		):
			requested = _direction_toward_screen_position(event.position)
	elif event is InputEventScreenTouch:
		consume_touch_event = true
		if event.pressed:
			_touch_gestures[event.index] = TouchGesture.new(event.position)
		else:
			var gesture: TouchGesture = _touch_gestures.get(event.index)
			_touch_gestures.erase(event.index)
			if gesture != null and gesture.is_tap(event.canceled):
				requested = _direction_toward_screen_position(event.position)
	elif event is InputEventScreenDrag:
		consume_touch_event = true
		var gesture: TouchGesture = _touch_gestures.get(event.index)
		if gesture == null:
			gesture = TouchGesture.new(event.position - event.relative)
			_touch_gestures[event.index] = gesture
		requested = gesture.update_drag(
			event.position,
			event.screen_relative,
			get_drag_threshold_pixels()
		)

	if requested != Vector2i.ZERO:
		direction_requested.emit(requested)
	if requested != Vector2i.ZERO or consume_touch_event:
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()

static func cardinal_direction(vector: Vector2) -> Vector2i:
	return TouchGesture.cardinal_direction(vector)

func get_drag_threshold_pixels(window_size := Vector2i.ZERO) -> float:
	var effective_window_size := window_size
	if effective_window_size == Vector2i.ZERO:
		effective_window_size = DisplayServer.window_get_size()
	return TouchGesture.threshold_for_window(
		effective_window_size,
		drag_threshold_window_ratio,
		minimum_drag_threshold_pixels
	)

func _direction_toward_screen_position(screen_position: Vector2) -> Vector2i:
	if _gameplay == null:
		return Vector2i.ZERO
	var local_pointer := get_global_transform_with_canvas().affine_inverse() * screen_position
	return cardinal_direction(local_pointer - _gameplay.get_snake_position())
