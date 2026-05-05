extends Node

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const UIStateManagerScript := preload("res://scenes/ui/ui_state_manager.gd")

func _ready() -> void:
	call_deferred("_run_smoke_test")

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)

func _run_smoke_test() -> void:
	var main: Node = MAIN_SCENE.instantiate()
	add_child(main)

	await get_tree().process_frame

	var main_menu := main.get_node_or_null("UILayer/MainMenu") as Control
	if main_menu == null or not main_menu.visible:
		_fail("Expected the main menu to be visible after startup.")
		return

	var start_button := main.get_node_or_null("UILayer/MainMenu/PanelContainer/MarginContainer/VBoxContainer/StartButton") as Button
	if start_button == null:
		_fail("Expected the main menu StartButton to exist.")
		return

	start_button.button_down.emit()
	start_button.pressed.emit()
	await get_tree().process_frame
	await get_tree().physics_frame

	if not bool(main.get("in_game")):
		_fail("Expected the game to enter gameplay after pressing Start.")
		return

	var ui_state_manager := main.get_node_or_null("UIStateManager")
	if ui_state_manager == null:
		_fail("Expected the UI state manager to exist.")
		return

	if int(ui_state_manager.get("current_state")) != UIStateManagerScript.UIState.GAMEPLAY:
		_fail("Expected UI state to switch to gameplay after pressing Start.")
		return

	var game_world := main.get_node_or_null("GameLayer/GameViewport/GameWorld") as CanvasItem
	if game_world == null or not game_world.visible:
		_fail("Expected the game world to be visible during gameplay.")
		return

	var score_label := main.get_node_or_null("UILayer/ScoreLabel") as CanvasItem
	if score_label == null or not score_label.visible:
		_fail("Expected the score label to be visible during gameplay.")
		return

	var gameplay := main.get_node_or_null("GameLayer/GameViewport/GameWorld/GameManager")
	if gameplay == null:
		_fail("Expected the gameplay manager to exist.")
		return

	if gameplay.get("snake") == null:
		_fail("Expected gameplay to spawn a snake when the game starts.")
		return

	if gameplay.get("food") == null:
		_fail("Expected gameplay to spawn food when the game starts.")
		return

	print("Smoke test passed.")
	get_tree().quit()
