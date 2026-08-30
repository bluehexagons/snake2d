class_name GameRules
extends Resource

## Inspector-editable rules shared by the deterministic model and its presentation.

@export_category("Board")
@export_range(8, 64, 1, "or_greater") var cell_size := 32
@export_range(4, 100, 1, "or_greater") var columns := 23
@export_range(4, 100, 1, "or_greater") var rows := 18

@export_category("Scoring and timing")
@export_range(1, 1000, 1, "or_greater") var points_per_food := 10
@export_range(0.02, 2.0, 0.01, "or_greater") var initial_tick_seconds := 0.2
@export_range(0.01, 1.0, 0.01, "or_greater") var minimum_tick_seconds := 0.05
@export_range(0.0, 0.1, 0.001, "or_greater") var tick_decrease_per_food := 0.005
@export_range(1, 16, 1, "or_greater") var maximum_catch_up_steps := 4

@export_category("Pitfall mode")
@export_range(1, 20, 1, "or_greater") var foods_per_pit := 3
@export_range(1, 10, 1, "or_greater") var pit_safe_distance_cells := 3

@export_category("Camera")
@export_range(0.0, 10.0, 0.1, "or_greater") var camera_look_ahead_cells := 3.0
@export_range(0.0, 1.0, 0.001) var camera_smoothing := 0.115
@export_range(0.0, 2.0, 0.01, "or_greater") var center_pull_weight := 0.4
@export_range(0.0, 2.0, 0.01, "or_greater") var food_attraction_weight := 0.5
@export_range(0.0, 2.0, 0.01, "or_greater") var look_ahead_weight := 0.66
@export_range(0.0, 2.0, 0.01, "or_greater") var snake_center_weight := 0.3

func board_size_cells() -> Vector2i:
	return Vector2i(columns, rows)

func board_size_pixels() -> Vector2i:
	return board_size_cells() * cell_size

func tick_seconds_for_length(body_length: int) -> float:
	var foods_eaten := maxi(0, body_length - 1)
	return maxf(
		initial_tick_seconds - foods_eaten * tick_decrease_per_food,
		minimum_tick_seconds
	)

## Returns 0 at the initial speed and 1 once the configured minimum tick is reached.
## Presentation systems can follow game difficulty without duplicating timing rules.
func speed_progress_for_length(body_length: int) -> float:
	var speed_range := initial_tick_seconds - minimum_tick_seconds
	if speed_range <= 0.0:
		return 0.0
	var elapsed_range := initial_tick_seconds - tick_seconds_for_length(body_length)
	return clampf(elapsed_range / speed_range, 0.0, 1.0)
