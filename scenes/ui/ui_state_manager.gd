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

const TRANSITION_DURATION := 0.18
var _transition_tweens: Dictionary = {}

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
		var elem = ui_elements[state]
		if elem == null:
			continue
		if state == current_state:
			_fade_in(elem)
		elif elem.visible:
			_fade_out(elem)
	
	if focus_targets.has(current_state) and focus_targets[current_state] != null:
		focus_targets[current_state].grab_focus()
	
	state_changed.emit(previous_state, current_state)

func _kill_transition(elem: CanvasItem) -> void:
	if _transition_tweens.has(elem):
		var t: Tween = _transition_tweens[elem]
		if t and t.is_valid():
			t.kill()
		_transition_tweens.erase(elem)

func _fade_in(elem: CanvasItem) -> void:
	if elem == null:
		return
	_kill_transition(elem)
	elem.visible = true
	var start_mod := elem.modulate
	start_mod.a = 0.0
	elem.modulate = start_mod
	var tween := get_tree().create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(elem, "modulate:a", 1.0, TRANSITION_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if elem is Control:
		var ctrl: Control = elem
		var orig_pivot := ctrl.pivot_offset
		ctrl.pivot_offset = ctrl.size * 0.5
		ctrl.scale = Vector2(0.96, 0.96)
		tween.parallel().tween_property(ctrl, "scale", Vector2.ONE, TRANSITION_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_callback(func() -> void: ctrl.pivot_offset = orig_pivot)
	_transition_tweens[elem] = tween

func _fade_out(elem: CanvasItem) -> void:
	if elem == null:
		return
	_kill_transition(elem)
	var tween := get_tree().create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(elem, "modulate:a", 0.0, TRANSITION_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		elem.visible = false
		var m := elem.modulate
		m.a = 1.0
		elem.modulate = m
	)
	_transition_tweens[elem] = tween

func go_back() -> void:
	change_state(previous_state)

func get_state_name() -> String:
	return UIState.keys()[current_state]

func set_paused(paused_state: bool) -> void:
	var currently_paused = current_state == UIState.PAUSED
	if paused_state == currently_paused:
		return

	get_tree().paused = paused_state
	
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
			get_tree().paused = true
			change_state(UIState.MAIN_MENU)
			get_viewport().set_input_as_handled()
			return

		get_viewport().set_input_as_handled()
		go_back()
