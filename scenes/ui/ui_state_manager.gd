extends Node
# UI State Manager handles transitions between different UI screens
# Makes it easier to manage complex UI navigation flows and screen states

signal state_changed(old_state, new_state)

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

var ui_elements := {}
var focus_targets := {}

# Register a UI element with the state manager
func register_ui_element(state: UIState, node: Node) -> void:
	ui_elements[state] = node

# Register the focus target for a specific state
func register_focus_target(state: UIState, button: Button) -> void:
	focus_targets[state] = button

# Change to a specified UI state
func change_state(new_state: UIState) -> void:
	if new_state == current_state:
		return
		
	previous_state = current_state
	current_state = new_state
	
	# Hide all UI elements
	for state in ui_elements:
		if ui_elements[state] != null:
			ui_elements[state].visible = false
	
	# Show the current UI element
	if ui_elements.has(current_state) and ui_elements[current_state] != null:
		ui_elements[current_state].visible = true
	
	# Set focus on the appropriate button
	if focus_targets.has(current_state) and focus_targets[current_state] != null:
		focus_targets[current_state].grab_focus()
	
	# Emit signal for any listeners
	state_changed.emit(previous_state, current_state)

# Go back to the previous state
func go_back() -> void:
	change_state(previous_state)

# Get a text representation of the current state (useful for debugging)
func get_state_name() -> String:
	return UIState.keys()[current_state]

func set_paused(paused_state: bool) -> void:
	var currently_paused = current_state == UIState.PAUSED
	if paused_state == currently_paused:
		return

	get_tree().paused = paused_state
	
	if paused_state:
		change_state(UIState.PAUSED)
	else:
		change_state(UIState.GAMEPLAY)

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
			change_state(UIState.MAIN_MENU)
			get_viewport().set_input_as_handled()
			return

		# For other states, go back to previous state
		get_viewport().set_input_as_handled()
		go_back()
