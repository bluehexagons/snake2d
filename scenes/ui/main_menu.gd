class_name MainMenu
extends CenterContainer

signal start_requested(mode: GameMode.Value, world_seed: int)
signal scores_requested
signal options_requested
signal credits_requested
signal quit_requested

const MIN_WORLD_SEED := 1
const MAX_WORLD_SEED := 999_999_999

@onready var start_button: Button = %StartButton
@onready var mode_selector: OptionButton = %ModeSelector
@onready var mode_description: Label = %ModeDescription
@onready var seed_row: HBoxContainer = %SeedRow
@onready var world_seed_spin_box: SpinBox = %WorldSeedSpinBox
@onready var scores_button: Button = %ScoresButton
@onready var options_button: Button = %OptionsButton
@onready var credits_button: Button = %CreditsButton
@onready var quit_button: Button = %QuitButton

var _seed_random := RandomNumberGenerator.new()
var _last_generated_seed := 0
var _seed_line_edit: LineEdit

func _ready() -> void:
	_seed_random.randomize()
	_seed_line_edit = world_seed_spin_box.get_line_edit()
	_seed_line_edit.focus_mode = Control.FOCUS_ALL
	_prepare_next_world_seed()
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

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or (event is InputEventKey and event.echo):
		return
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner == mode_selector:
		if event.is_action_pressed("ui_up"):
			_move_focus_to(quit_button)
		elif event.is_action_pressed("ui_down"):
			if seed_row.visible:
				_move_focus_to(_seed_line_edit, true)
			else:
				_move_focus_to(start_button)
	elif focus_owner == _seed_line_edit:
		if event.is_action_pressed("ui_up"):
			_move_focus_to(mode_selector)
		elif event.is_action_pressed("ui_down"):
			_move_focus_to(start_button)
		elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
			if event.is_action_pressed("ui_left"):
				_adjust_world_seed(-1)
			elif event.is_action_pressed("ui_right"):
				_adjust_world_seed(1)

func _on_start_pressed() -> void:
	var mode := mode_selector.get_selected_id() as GameMode.Value
	var selected_seed := roundi(world_seed_spin_box.value)
	start_requested.emit(
		mode,
		selected_seed
	)
	if mode == GameMode.Value.OBSTACLES:
		_prepare_next_world_seed()

func _on_mode_selected(_index: int) -> void:
	var mode := mode_selector.get_selected_id() as GameMode.Value
	seed_row.visible = mode == GameMode.Value.OBSTACLES
	var input_above_start: Control = _seed_line_edit if seed_row.visible else mode_selector
	mode_selector.focus_neighbor_bottom = (
		mode_selector.get_path_to(_seed_line_edit)
		if seed_row.visible
		else mode_selector.get_path_to(start_button)
	)
	mode_selector.focus_next = mode_selector.focus_neighbor_bottom
	_seed_line_edit.focus_neighbor_top = _seed_line_edit.get_path_to(mode_selector)
	_seed_line_edit.focus_neighbor_bottom = _seed_line_edit.get_path_to(start_button)
	_seed_line_edit.focus_previous = _seed_line_edit.focus_neighbor_top
	_seed_line_edit.focus_next = _seed_line_edit.focus_neighbor_bottom
	start_button.focus_neighbor_top = start_button.get_path_to(input_above_start)
	start_button.focus_previous = start_button.focus_neighbor_top
	match mode:
		GameMode.Value.PITFALL:
			mode_description.text = "Every third meal creates a new pit. Keep moving carefully."
		GameMode.Value.OBSTACLES:
			mode_description.text = "Fresh seed each run. Type one, or use left/right, to override."
		_:
			mode_description.text = "No obstacles — grab food, grow, and chase your best score."

func _prepare_next_world_seed() -> void:
	var current_seed := roundi(world_seed_spin_box.value)
	var next_seed := _seed_random.randi_range(MIN_WORLD_SEED, MAX_WORLD_SEED)
	while next_seed == current_seed or next_seed == _last_generated_seed:
		next_seed = _seed_random.randi_range(MIN_WORLD_SEED, MAX_WORLD_SEED)
	_last_generated_seed = next_seed
	world_seed_spin_box.set_value_no_signal(next_seed)

func _move_focus_to(control: Control, select_seed_text := false) -> void:
	if control != _seed_line_edit and _seed_line_edit.is_editing():
		_seed_line_edit.unedit()
	control.grab_focus()
	if select_seed_text:
		_seed_line_edit.edit()
		_seed_line_edit.select_all()
	get_viewport().set_input_as_handled()

func _adjust_world_seed(amount: int) -> void:
	world_seed_spin_box.value = clampi(
		roundi(world_seed_spin_box.value) + amount,
		MIN_WORLD_SEED,
		MAX_WORLD_SEED
	)
	_seed_line_edit.select_all()
	get_viewport().set_input_as_handled()

func get_buttons() -> Array[Button]:
	return [mode_selector, start_button, scores_button, options_button, credits_button, quit_button]

func get_default_focus() -> Button:
	return start_button
