class_name UIStateManager
extends Node

signal state_changed(old_state: UIState, new_state: UIState)

enum UIState {
	MAIN_MENU,
	OPTIONS_MENU,
	CREDITS_SCREEN,
	HIGH_SCORES,
	GAMEPLAY,
	PAUSED,
	GAME_OVER
}

var current_state: UIState = UIState.MAIN_MENU

var ui_elements: Dictionary[UIState, Control] = {}
var focus_targets: Dictionary[UIState, Control] = {}

const TRANSITION_DURATION := 0.14
var _transition: Tween
var _reduced_motion := false

func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled
	if enabled:
		_stop_transition()
		if ui_elements.has(current_state):
			ui_elements[current_state].modulate.a = 1.0

func register_ui_element(state: UIState, node: Control) -> void:
	ui_elements[state] = node
	node.visible = state == current_state
	_set_interactive(node, state == current_state)

func register_focus_target(state: UIState, button: Control) -> void:
	focus_targets[state] = button

func change_state(new_state: UIState, focus_override: Control = null) -> void:
	if new_state == current_state:
		return

	_stop_transition()
	var old_state := current_state
	current_state = new_state
	for state in ui_elements:
		var panel := ui_elements[state]
		var active := state == current_state
		_set_interactive(panel, active)
		panel.visible = active
		panel.modulate.a = 1.0
		if active and not _reduced_motion:
			_fade_in(panel)

	var focus_target: Control = focus_override if focus_override != null else focus_targets.get(current_state)
	if focus_target != null:
		focus_target.grab_focus()
	state_changed.emit(old_state, current_state)

func _set_interactive(panel: Control, enabled: bool) -> void:
	# Disable input on the whole panel, including any focused child.
	panel.mouse_behavior_recursive = (
		Control.MOUSE_BEHAVIOR_ENABLED if enabled else Control.MOUSE_BEHAVIOR_DISABLED
	)
	panel.focus_behavior_recursive = (
		Control.FOCUS_BEHAVIOR_ENABLED if enabled else Control.FOCUS_BEHAVIOR_DISABLED
	)
	panel.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED

func _stop_transition() -> void:
	if _transition != null:
		_transition.kill()
		_transition = null

func _fade_in(panel: Control) -> void:
	panel.modulate.a = 0.55
	_transition = create_tween()
	_transition.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_transition.tween_property(panel, "modulate:a", 1.0, TRANSITION_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func get_state_name() -> String:
	return UIState.keys()[current_state]
