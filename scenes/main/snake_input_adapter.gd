class_name SnakeInputAdapter
extends Node2D

## Translates device-specific events into cardinal grid directions.
## It deliberately does not decide whether a requested turn is legal.

signal direction_requested(direction: Vector2i)

const DIRECTION_ACTIONS: Dictionary[StringName, Vector2i] = {
	&"up": Vector2i.UP,
	&"down": Vector2i.DOWN,
	&"left": Vector2i.LEFT,
	&"right": Vector2i.RIGHT,
}
const STICK_RELEASE_DEADZONE_FRACTION := 0.7

@export_category("Touch Gestures")
@export_range(0.005, 0.1, 0.005) var drag_threshold_window_ratio := 0.025
@export_range(8.0, 96.0, 1.0) var minimum_drag_threshold_pixels := 16.0

var _gameplay: Gameplay
var _touch_gestures: Dictionary[int, TouchGesture] = {}
var _held_stick_actions: Dictionary[Vector2i, StringName] = {}
var _enabled := false

func _ready() -> void:
	set_process_unhandled_input(_enabled)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)

func configure(gameplay: Gameplay) -> void:
	_gameplay = gameplay

func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	set_process_unhandled_input(enabled)
	if not enabled:
		_touch_gestures.clear()
		_held_stick_actions.clear()

func _unhandled_input(event: InputEvent) -> void:
	if not _enabled:
		return

	var action := _pressed_direction_action(event)
	if event is InputEventJoypadMotion and not _is_new_stick_press(event, action):
		return

	var requested := Vector2i.ZERO
	var consume_touch_event := false

	if not action.is_empty():
		requested = DIRECTION_ACTIONS[action]
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
		# A drag after pause/cancellation must not revive an ended gesture.
		# Only a press received while enabled can begin a new one.
		if gesture != null:
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

func _pressed_direction_action(event: InputEvent) -> StringName:
	for action in DIRECTION_ACTIONS:
		if event.is_action_pressed(action):
			return action
	return &""

func _is_new_stick_press(event: InputEventJoypadMotion, action: StringName) -> bool:
	var axis := Vector2i(event.device, event.axis)
	var previous: StringName = _held_stick_actions.get(axis, &"")
	if action.is_empty():
		# Require a deeper return toward center so jitter at the press threshold
		# cannot rearm an axis and fill the follow-up turn slot.
		if not previous.is_empty():
			var release_threshold := InputMap.action_get_deadzone(previous) * STICK_RELEASE_DEADZONE_FRACTION
			if absf(event.axis_value) <= release_threshold:
				_held_stick_actions.erase(axis)
		return false
	if action == previous:
		return false
	_held_stick_actions[axis] = action
	return true

func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if not connected:
		for axis in _held_stick_actions.keys():
			if axis.x == device:
				_held_stick_actions.erase(axis)

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
	return cardinal_direction(local_pointer - _gameplay.get_snake_center())
