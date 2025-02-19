extends Node2D

signal moved(new_position)
signal grew
signal died

const GRID_SIZE = 32
@export var direction = Vector2.RIGHT  # Made public for camera access
var next_direction = Vector2.RIGHT  # Buffer the next direction
var can_move = true
var last_touch_pos = Vector2.ZERO
var using_touch = false

func _ready():
	# Enable touch/mouse emulation
	Input.emulate_touch_from_mouse = true
	Input.emulate_mouse_from_touch = true
	position = position.snapped(Vector2(GRID_SIZE, GRID_SIZE))

func _process(_delta):
	if can_move:
		var touch_dir = Vector2.ZERO
		
		# Handle touch/mouse input
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			var mouse_pos = get_viewport().get_mouse_position()
			
			# Convert screen position to world position
			var camera = get_viewport().get_camera_2d()
			if camera:
				mouse_pos += camera.position - Vector2(get_viewport().size / 2)
			
			# Get direction to mouse
			var to_mouse = (mouse_pos - position).normalized()
			
			# Convert to cardinal direction
			if abs(to_mouse.x) > abs(to_mouse.y):
				touch_dir = Vector2(sign(to_mouse.x), 0)
			else:
				touch_dir = Vector2(0, sign(to_mouse.y))
		
		# Traditional input
		var input_x = Input.get_axis("left", "right")
		var input_y = Input.get_axis("up", "down")
		
		if abs(input_x) > 0.5 or abs(input_y) > 0.5:
			if abs(input_x) > abs(input_y):
				touch_dir = Vector2(sign(input_x), 0)
			else:
				touch_dir = Vector2(0, sign(input_y))
		
		# Apply movement if we have input and it's not reversing
		if touch_dir != Vector2.ZERO and touch_dir != -direction:
			next_direction = touch_dir

func move():
	# Apply the buffered direction
	direction = next_direction
	var new_position = position + direction * GRID_SIZE
	
	# Check wall collision using tilemap bounds
	if new_position.x < 0 or new_position.x >= 768 or \
	   new_position.y < 0 or new_position.y >= 576:
		died.emit()
		return
		
	position = new_position
	can_move = true
	moved.emit(position)

func grow():
	grew.emit()
