class_name MainMenu
extends CenterContainer

func _ready() -> void:
	var version_label: Label = $PanelContainer/MarginContainer/Label
	version_label.text = "v" + ProjectSettings.get_setting("application/config/version", "?")
