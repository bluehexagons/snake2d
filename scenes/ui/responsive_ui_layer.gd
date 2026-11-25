class_name ResponsiveUILayer
extends CanvasLayer

signal gameplay_inset_changed(top_inset: float)

const HUD_MARGIN := 12.0
const HUD_GAP := 8.0
const HUD_MAX_WIDTH := 460.0
const INLINE_HINT_MIN_VIEWPORT_WIDTH := 780.0
const INLINE_HINT_WIDTH := 300.0

## Compensate for board downscaling so menu text stays at its authored pixel size.
## Report the HUD space in game viewport units so the camera can frame around it.
var _full_rect_controls: Array[Control] = []
var _gameplay_pause_visible := false
var _hud_height := 42.0

@onready var _pause_button: Button = %GameplayPauseButton
@onready var _hud: PanelContainer = %GameplayHUD
@onready var _stats: BoxContainer = _hud.get_node("Stats")
@onready var _first_move_hint_area: CenterContainer = %ControlsTutorial.get_node("HintArea")

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
	_hud.resized.connect(_on_hud_resized)
	_hud.minimum_size_changed.connect(_fit_hud_height)
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
	for control in _full_rect_controls:
		if control is ScrollContainer:
			# Release the previous panel minimum before shrinking its scroll root.
			var layout := control.get_node("Content/PanelContainer/MarginContainer/MenuLayout") as ResponsiveMenuLayout
			layout.fit_to_size(available)
		control.position = Vector2.ZERO
		control.size = available
	_pause_button.position = Vector2(available.x - HUD_MARGIN - _pause_button.size.x, HUD_MARGIN)
	_update_pause_visibility()
	var hud_width := _pause_button.position.x - HUD_MARGIN - HUD_GAP
	if available.x >= INLINE_HINT_MIN_VIEWPORT_WIDTH:
		hud_width -= INLINE_HINT_WIDTH + HUD_GAP
	var narrow := available.x < 440.0
	_stats.vertical = narrow
	_stats.add_theme_constant_override("separation", 4 if narrow else 16)
	_hud_height = 60.0 if narrow else 42.0
	_hud.size = Vector2(minf(HUD_MAX_WIDTH, hud_width), _hud_height)
	_on_hud_resized()

func _fit_hud_height() -> void:
	# A wrapped label reports its new minimum after the container assigns its width.
	_hud.size.y = _hud_height

func _on_hud_resized() -> void:
	_layout_first_move_hint()
	gameplay_inset_changed.emit(gameplay_top_inset())

func gameplay_top_inset() -> float:
	return maxf(_hud.get_rect().end.y, _pause_button.get_rect().end.y) * scale.y

func _layout_first_move_hint() -> void:
	var available_width := get_viewport().get_visible_rect().size.x / scale.x
	var hud_rect := _hud.get_rect()
	const HINT_HEIGHT := 44.0
	if available_width >= INLINE_HINT_MIN_VIEWPORT_WIDTH:
		var left := hud_rect.end.x + HUD_GAP
		_first_move_hint_area.position = Vector2(left, hud_rect.get_center().y - HINT_HEIGHT / 2.0)
		_first_move_hint_area.size = Vector2(_pause_button.position.x - left - HUD_GAP, HINT_HEIGHT)
	else:
		_first_move_hint_area.position = Vector2(0, hud_rect.end.y + HUD_GAP)
		_first_move_hint_area.size = Vector2(available_width, HINT_HEIGHT)

func set_gameplay_pause_visible(visible: bool) -> void:
	_gameplay_pause_visible = visible
	_update_pause_visibility()

func _update_pause_visibility() -> void:
	_pause_button.visible = _gameplay_pause_visible and _pause_button.position.x >= HUD_MARGIN
