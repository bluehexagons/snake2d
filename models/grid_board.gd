class_name GridBoard
extends RefCounted

## Board dimensions plus deterministic free-cell queries.

var size: Vector2i

func _init(board_size: Vector2i) -> void:
	assert(board_size.x > 0 and board_size.y > 0, "GridBoard dimensions must be positive.")
	size = board_size

func contains(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y

func available_cells(occupied_cells: Array[Vector2i]) -> Array[Vector2i]:
	var occupied: Dictionary[Vector2i, bool] = {}
	for cell in occupied_cells:
		occupied[cell] = true

	var available: Array[Vector2i] = []
	for x in size.x:
		for y in size.y:
			var cell := Vector2i(x, y)
			if not occupied.has(cell):
				available.append(cell)
	return available

func choose_available_cell(
	occupied_cells: Array[Vector2i],
	random: RandomNumberGenerator
) -> Vector2i:
	var available := available_cells(occupied_cells)
	if available.is_empty():
		return Vector2i(-1, -1)
	return available[random.randi_range(0, available.size() - 1)]
