class_name ResponsiveMenuLayout
extends BoxContainer

## Authored groups keep their controls and focus paths when the layout changes.
const WIDE_ASPECT := 2.0
const MIN_WIDE_WIDTH := 720.0
const WIDE_WIDTH := 760.0

@export var stacked_separation := 24
@export var stacked_minimum_width := 0.0

@onready var _menu := get_parent().get_parent().get_parent().get_parent() as ScrollContainer
@onready var _panel := get_parent().get_parent() as PanelContainer

func _ready() -> void:
	_menu.resized.connect(_update_layout)
	_update_layout()

func _update_layout() -> void:
	fit_to_size(_menu.size)

func fit_to_size(available: Vector2) -> void:
	var wide := available.x >= MIN_WIDE_WIDTH and available.x >= available.y * WIDE_ASPECT
	vertical = not wide
	add_theme_constant_override("separation", 32 if wide else stacked_separation)
	for group: VBoxContainer in get_children():
		group.alignment = BoxContainer.ALIGNMENT_CENTER if wide else BoxContainer.ALIGNMENT_BEGIN
		group.add_theme_constant_override("separation", 12 if wide else stacked_separation)
	var target_width := WIDE_WIDTH if wide else stacked_minimum_width
	_panel.custom_minimum_size.x = minf(target_width, maxf(0.0, available.x - 24.0))
