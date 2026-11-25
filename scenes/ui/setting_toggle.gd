class_name SettingToggle
extends Button

const ON_COLOR := Color("#a1efba")

@onready var _value_label := Label.new()

func _ready() -> void:
	_value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_value_label.theme_type_variation = &"HintLabel"
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_value_label)
	_value_label.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	_value_label.offset_left = -56.0
	_value_label.offset_right = -14.0
	show_setting(button_pressed)

func show_setting(enabled: bool) -> void:
	set_pressed_no_signal(enabled)
	_value_label.text = "On" if enabled else "Off"
	if enabled:
		_value_label.add_theme_color_override("font_color", ON_COLOR)
	else:
		_value_label.remove_theme_color_override("font_color")
