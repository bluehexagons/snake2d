class_name SnakeState
extends RefCounted

## Grid-only snake state. It knows nothing about nodes, pixels, input devices, or audio.

const CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i.UP,
	Vector2i.DOWN,
	Vector2i.LEFT,
	Vector2i.RIGHT,
]

var body: Array[Vector2i] = []
var direction := Vector2i.RIGHT
var queued_direction := Vector2i.RIGHT
var waiting_for_input := true
var alive := true
var _turn_queued := false
var _buffered_direction := Vector2i.ZERO

func reset(start_cell: Vector2i) -> void:
	body.assign([start_cell])
	direction = Vector2i.RIGHT
	queued_direction = Vector2i.RIGHT
	waiting_for_input = true
	alive = true
	_turn_queued = false
	_buffered_direction = Vector2i.ZERO

## Keeps the next turn and one follow-up. Each takes effect on its own tick.
func request_direction(requested_direction: Vector2i) -> bool:
	if not alive or requested_direction not in CARDINAL_DIRECTIONS or _buffered_direction != Vector2i.ZERO:
		return false
	var previous_direction := queued_direction if _turn_queued else direction
	if not waiting_for_input and requested_direction in [previous_direction, -previous_direction]:
		return false

	if _turn_queued:
		_buffered_direction = requested_direction
	else:
		queued_direction = requested_direction
		_turn_queued = true
		waiting_for_input = false
	return true

func next_head_cell() -> Vector2i:
	return body[0] + queued_direction

func would_hit_self(next_head: Vector2i, will_grow: bool) -> bool:
	# A non-growing move may enter the cell vacated by the tail on this tick.
	var occupied_count := body.size() if will_grow else maxi(0, body.size() - 1)
	for i in occupied_count:
		if body[i] == next_head:
			return true
	return false

func advance(next_head: Vector2i, grow: bool) -> void:
	direction = queued_direction
	_turn_queued = _buffered_direction != Vector2i.ZERO
	queued_direction = _buffered_direction if _turn_queued else direction
	_buffered_direction = Vector2i.ZERO
	body.push_front(next_head)
	if not grow:
		body.pop_back()

func mark_dead() -> void:
	alive = false
