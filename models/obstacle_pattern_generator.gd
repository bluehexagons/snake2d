class_name ObstaclePatternGenerator
extends RefCounted

## Seeded, sparse wall arrangements. Each family keeps openings so the board
## remains navigable while still changing the route to food.

const PATTERN_NAMES: Array[String] = ["Gates", "Islands", "Ribbons"]

static func generate(
	board_size: Vector2i,
	spawn_cell: Vector2i,
	world_seed: int
) -> Dictionary:
	var random := RandomNumberGenerator.new()
	random.seed = world_seed
	var pattern_index := random.randi_range(0, PATTERN_NAMES.size() - 1)
	var candidates: Array[Vector2i]
	if board_size.x < 8 or board_size.y < 8:
		pattern_index = 1
		candidates = _generate_compact_islands(board_size, world_seed)
	else:
		match pattern_index:
			0:
				candidates = _generate_gates(board_size, random)
			1:
				candidates = _generate_islands(board_size, random)
			_:
				candidates = _generate_ribbons(board_size, random)

	var unique_cells: Dictionary[Vector2i, bool] = {}
	for cell in candidates:
		if (
			cell.x <= 0
			or cell.y <= 0
			or cell.x >= board_size.x - 1
			or cell.y >= board_size.y - 1
			or _manhattan_distance(cell, spawn_cell) <= 2
		):
			continue
		unique_cells[cell] = true

	var cells: Array[Vector2i] = []
	cells.assign(unique_cells.keys())
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x)
	)
	return {
		"name": PATTERN_NAMES[pattern_index],
		"cells": cells,
	}

static func _generate_gates(
	board_size: Vector2i,
	random: RandomNumberGenerator
) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var horizontal_count := clampi(board_size.y / 7, 2, 3)
	for index in horizontal_count:
		var y := clampi(
			roundi(float(index + 1) * board_size.y / float(horizontal_count + 1))
			+ random.randi_range(-1, 1),
			2,
			board_size.y - 3
		)
		var gap_center := random.randi_range(3, board_size.x - 4)
		for x in range(2, board_size.x - 2):
			if absi(x - gap_center) > 1:
				cells.append(Vector2i(x, y))

	var vertical_x := random.randi_range(3, board_size.x - 4)
	var vertical_gap := random.randi_range(3, board_size.y - 4)
	for y in range(2, board_size.y - 2):
		if absi(y - vertical_gap) > 1 and random.randf() < 0.7:
			cells.append(Vector2i(vertical_x, y))
	return cells

static func _generate_islands(
	board_size: Vector2i,
	random: RandomNumberGenerator
) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var island_count := clampi((board_size.x * board_size.y) / 70, 4, 8)
	for index in island_count:
		var center := Vector2i(
			random.randi_range(2, board_size.x - 3),
			random.randi_range(2, board_size.y - 3)
		)
		cells.append(center)
		var directions: Array[Vector2i] = [
			Vector2i.UP,
			Vector2i.DOWN,
			Vector2i.LEFT,
			Vector2i.RIGHT,
		]
		var first_direction := random.randi_range(0, directions.size() - 1)
		var arm_count := random.randi_range(1, 3)
		for arm in arm_count:
			cells.append(center + directions[(first_direction + arm) % directions.size()])
	return cells

static func _generate_compact_islands(
	board_size: Vector2i,
	world_seed: int
) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in range(1, board_size.x - 1):
		for y in range(1, board_size.y - 1):
			if posmod(x * 17 + y * 31 + world_seed, 5) == 0:
				cells.append(Vector2i(x, y))
	return cells

static func _generate_ribbons(
	board_size: Vector2i,
	random: RandomNumberGenerator
) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var ribbon_count := clampi(board_size.y / 8, 2, 3)
	for ribbon in ribbon_count:
		var base_y := roundi(float(ribbon + 1) * board_size.y / float(ribbon_count + 1))
		var phase := random.randi_range(0, 5)
		for x in range(2, board_size.x - 2):
			# Alternating three-cell dashes leave regular passages through the ribbon.
			if (x + phase) % 6 >= 3:
				continue
			var rising := floori(float(x + phase) / 3.0) % 2 == 0
			var wave_y := base_y + (1 if rising else -1)
			cells.append(Vector2i(x, clampi(wave_y, 2, board_size.y - 3)))
	return cells

static func _manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
