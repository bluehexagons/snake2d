extends Node2D

const ConfigData = preload("res://autoload/config.gd")

signal moved(new_position: Vector2)
signal grew
signal died
signal first_move

@export var direction := Vector2.RIGHT
var next_direction: Vector2 = Vector2.RIGHT
var can_move := true
var using_touch := false
var waiting_for_input := true

func _ready() -> void:
	Input.emulate_touch_from_mouse = true
	Input.emulate_mouse_from_touch = true
	position = position.snapped(Vector2(ConfigData.GRID_SIZE, ConfigData.GRID_SIZE))

func _process(_delta) -> void:
	if can_move:
		var touch_dir := Vector2.ZERO
		
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			var viewport := get_viewport()
			var mouse_pos := viewport.get_mouse_position()
			
			var screen_size := viewport.get_visible_rect().size
			mouse_pos *= Vector2(viewport.size) / screen_size
			
			var camera := get_viewport().get_camera_2d()
			if camera:
				mouse_pos += camera.position - Vector2(get_viewport().size / 2)
			
			var to_mouse := (mouse_pos - position).normalized()
			
			if abs(to_mouse.x) > abs(to_mouse.y):
				touch_dir = Vector2(sign(to_mouse.x), 0)
			else:
				touch_dir = Vector2(0, sign(to_mouse.y))
		
		var input_vector := Input.get_vector("left", "right", "up", "down")

		if input_vector != Vector2.ZERO:
			if abs(input_vector.x) > abs(input_vector.y):
				touch_dir = Vector2(sign(input_vector.x), 0)
			else:
				touch_dir = Vector2(0, sign(input_vector.y))
		
		if touch_dir != Vector2.ZERO and (touch_dir != -direction or waiting_for_input):
			next_direction = touch_dir
			
			if waiting_for_input:
				waiting_for_input = false
				first_move.emit()

func move() -> void:
	if waiting_for_input:
		can_move = true
		return

	direction = next_direction
	var new_position := position + direction * ConfigData.GRID_SIZE
	
	if new_position.x < 0 or new_position.x >= ConfigData.GRID_WIDTH * ConfigData.GRID_SIZE or new_position.y < 0 or new_position.y >= ConfigData.GRID_HEIGHT * ConfigData.GRID_SIZE:
		died.emit()
		return
		
	position = new_position
	can_move = true
	moved.emit(position)

func grow() -> void:
	grew.emit()
