class_name GameplayGrid
extends Node2D

## Draws a quiet cell-aligned guide behind every gameplay entity.

const GRID_COLOR := Color(0.33, 0.65, 0.45, 0.12)

var columns := 0
var rows := 0
var cell_size := 0

func configure(rules: GameRules) -> void:
	columns = rules.columns
	rows = rules.rows
	cell_size = rules.cell_size
	queue_redraw()

func set_grid_enabled(enabled: bool) -> void:
	visible = enabled

func line_count() -> int:
	return maxi(0, columns - 1) + maxi(0, rows - 1)

func _draw() -> void:
	if columns <= 0 or rows <= 0 or cell_size <= 0:
		return
	var board_size := Vector2(columns * cell_size, rows * cell_size)
	for column in range(1, columns):
		var x := float(column * cell_size)
		draw_line(Vector2(x, 0.0), Vector2(x, board_size.y), GRID_COLOR, 1.0)
	for row in range(1, rows):
		var y := float(row * cell_size)
		draw_line(Vector2(0.0, y), Vector2(board_size.x, y), GRID_COLOR, 1.0)
