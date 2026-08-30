class_name MainMenu
extends CenterContainer

signal start_requested(mode: GameMode.Value, world_seed: int)
signal scores_requested
signal options_requested
signal credits_requested
signal quit_requested

@onready var start_button: Button = %StartButton
@onready var mode_selector: OptionButton = %ModeSelector
@onready var mode_description: Label = %ModeDescription
@onready var seed_row: HBoxContainer = %SeedRow
@onready var world_seed_spin_box: SpinBox = %WorldSeedSpinBox
@onready var scores_button: Button = %ScoresButton
@onready var options_button: Button = %OptionsButton
@onready var credits_button: Button = %CreditsButton
@onready var quit_button: Button = %QuitButton

func _ready() -> void:
	var version_label: Label = $PanelContainer/MarginContainer/Label
	version_label.text = "v" + ProjectSettings.get_setting("application/config/version", "?")
	for mode in GameMode.ALL:
		mode_selector.add_item(GameMode.display_name(mode), mode)
	mode_selector.select(GameMode.Value.CLASSIC)
	mode_selector.item_selected.connect(_on_mode_selected)
	start_button.pressed.connect(_on_start_pressed)
	scores_button.pressed.connect(scores_requested.emit)
	options_button.pressed.connect(options_requested.emit)
	credits_button.pressed.connect(credits_requested.emit)
	quit_button.pressed.connect(quit_requested.emit)
	_on_mode_selected(mode_selector.selected)

func _on_start_pressed() -> void:
	start_requested.emit(
		mode_selector.get_selected_id() as GameMode.Value,
		roundi(world_seed_spin_box.value)
	)

func _on_mode_selected(_index: int) -> void:
	var mode := mode_selector.get_selected_id() as GameMode.Value
	seed_row.visible = mode == GameMode.Value.OBSTACLES
	start_button.focus_neighbor_top = (
		start_button.get_path_to(world_seed_spin_box)
		if seed_row.visible
		else start_button.get_path_to(mode_selector)
	)
	match mode:
		GameMode.Value.PITFALL:
			mode_description.text = "A new pit appears after every few meals. Keep moving carefully."
		GameMode.Value.OBSTACLES:
			mode_description.text = "Navigate a reproducible world of seeded wall patterns."
		_:
			mode_description.text = "No obstacles — grab food, grow, and chase your best score."

func get_buttons() -> Array[Button]:
	return [mode_selector, start_button, scores_button, options_button, credits_button, quit_button]

func get_default_focus() -> Button:
	return start_button
