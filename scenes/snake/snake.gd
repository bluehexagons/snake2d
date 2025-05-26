extends Node2D

signal moved(new_position)
signal grew
signal died
signal first_move

@export var direction := Vector2.RIGHT
var next_direction := Vector2.RIGHT
var can_move := true
var last_touch_pos := Vector2.ZERO
var using_touch := false
var waiting_for_input := true

func _ready() -> void:
	Input.emulate_touch_from_mouse = true
	Input.emulate_mouse_from_touch = true
	position = position.snapped(Vector2(Config.GRID_SIZE, Config.GRID_SIZE))

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
		
		var input_x := Input.get_axis("left", "right")
		var input_y := Input.get_axis("up", "down")
		
		if abs(input_x) > 0.5 or abs(input_y) > 0.5:
			if abs(input_x) > abs(input_y):
				touch_dir = Vector2(sign(input_x), 0)
			else:
				touch_dir = Vector2(0, sign(input_y))
		
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
	var new_position := position + direction * Config.GRID_SIZE
	
	if new_position.x < 0 or new_position.x >= Config.GRID_WIDTH * Config.GRID_SIZE or new_position.y < 0 or new_position.y >= Config.GRID_HEIGHT * Config.GRID_SIZE:
		died.emit()
		return
		
	position = new_position
	can_move = true
	moved.emit(position)

func grow() -> void:
	grew.emit()
