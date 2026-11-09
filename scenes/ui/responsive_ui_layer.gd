class_name ResponsiveUILayer
extends CanvasLayer

## Compensate for board downscaling so menu text stays at its authored pixel size.
## The board and its input/camera transforms keep the project stretch unchanged.
var _full_rect_controls: Array[Control] = []

func _ready() -> void:
	for child in get_children():
		if child is Control and child.anchor_right == 1.0 and child.anchor_bottom == 1.0:
			_full_rect_controls.append(child)
			child.set_anchors_preset(Control.PRESET_TOP_LEFT)
			# Minimum sizes settle asynchronously as title/description text wraps.
			# Growing toward the end keeps the full-screen origin fixed meanwhile.
			child.grow_horizontal = Control.GROW_DIRECTION_END
			child.grow_vertical = Control.GROW_DIRECTION_END
	get_viewport().size_changed.connect(_update_layout)
	_update_layout()

func _update_layout() -> void:
	# Web canvas dimensions include devicePixelRatio; target CSS pixels there.
	var density := DisplayServer.screen_get_scale() if OS.has_feature("web") else 1.0
	fit_to_viewport(density)

func fit_to_viewport(pixel_density: float) -> void:
	var stretch := get_viewport().get_stretch_transform().get_scale().x
	var compensation := maxf(1.0, pixel_density / maxf(stretch, 0.01))
	scale = Vector2.ONE * compensation
	var available := get_viewport().get_visible_rect().size / compensation
	# Keep the title on one line on desktop, while allowing a narrow menu to wrap.
	var main_panel := get_node("MainMenu/Content/PanelContainer") as Control
	main_panel.custom_minimum_size.x = minf(448.0, maxf(0.0, available.x - 24.0))
	for control in _full_rect_controls:
		control.position = Vector2.ZERO
		control.size = available
	var mode_label := get_node("HUDModeLabel") as Label
	mode_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mode_label.size.x = maxf(1.0, available.x - mode_label.position.x - 16.0)
