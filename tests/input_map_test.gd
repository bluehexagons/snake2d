extends SceneTree

var _failed := false

func _initialize() -> void:
	_expect_key_action(&"up", KEY_W, true)
	_expect_key_action(&"up", KEY_UP, true)
	_expect_key_action(&"ui_up", KEY_UP, false)
	_expect_key_action(&"pause", KEY_P, true)
	_expect_key_action(&"ui_cancel", KEY_ESCAPE, false)

	if _failed:
		quit(1)
	else:
		print("Input map test passed.")
		quit()

func _expect_key_action(action: StringName, key: Key, use_physical_key: bool) -> void:
	var event := InputEventKey.new()
	event.device = InputEvent.DEVICE_ID_KEYBOARD
	event.pressed = true
	if use_physical_key:
		event.physical_keycode = key
	else:
		event.keycode = key

	if not InputMap.event_is_action(event, action):
		_failed = true
		push_error("Expected keyboard event %s to match action %s." % [event.as_text(), action])
