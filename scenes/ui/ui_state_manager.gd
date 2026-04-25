class_name UIStateManager
extends Node

signal state_changed(old_state: UIState, new_state: UIState)
signal pause_state_changed(is_paused: bool)

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
var previous_state: UIState = UIState.MAIN_MENU

var ui_elements: Dictionary[UIState, Node] = {}
var focus_targets: Dictionary[UIState, Button] = {}

var main_node: Node

func _ready() -> void:
	main_node = get_parent()

func register_ui_element(state: UIState, node: Node) -> void:
	ui_elements[state] = node

func register_focus_target(state: UIState, button: Button) -> void:
	focus_targets[state] = button

func change_state(new_state: UIState) -> void:
	if new_state == current_state:
		return
		
	previous_state = current_state
	current_state = new_state
	
	for state in ui_elements:
		if ui_elements[state] != null:
			ui_elements[state].visible = false
	
	if ui_elements.has(current_state) and ui_elements[current_state] != null:
		ui_elements[current_state].visible = true
	
	if focus_targets.has(current_state) and focus_targets[current_state] != null:
		focus_targets[current_state].grab_focus()
	
	state_changed.emit(previous_state, current_state)

func go_back() -> void:
	change_state(previous_state)

func get_state_name() -> String:
	return UIState.keys()[current_state]

func set_paused(paused_state: bool) -> void:
	var currently_paused = current_state == UIState.PAUSED
	if paused_state == currently_paused:
		return

	get_tree().set_pause(paused_state)
	
	if main_node:
		var game_manager = main_node.get("game_manager")
		if game_manager and game_manager.has_method("set_paused"):
			game_manager.set_paused(paused_state)
	
	if paused_state:
		if current_state == UIState.GAMEPLAY:
			change_state(UIState.PAUSED)
	else:
		if current_state == UIState.PAUSED:
			change_state(UIState.GAMEPLAY)
	
	pause_state_changed.emit(paused_state)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if current_state == UIState.MAIN_MENU:
			return

		if current_state == UIState.GAMEPLAY:
			set_paused(true)
			get_viewport().set_input_as_handled()
			return
		
		if current_state == UIState.PAUSED:
			set_paused(false)
			get_viewport().set_input_as_handled()
			return

		if current_state == UIState.GAME_OVER:
			if main_node and main_node.has_method("_cleanup_game"):
				main_node._cleanup_game()
			get_tree().set_pause(true)
			change_state(UIState.MAIN_MENU)
			get_viewport().set_input_as_handled()
			return

		get_viewport().set_input_as_handled()
		go_back()
