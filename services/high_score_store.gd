class_name HighScoreStore
extends Node

const AppConstants = preload("res://core/app_constants.gd")
const SAVE_VERSION := 2

## File-backed, versioned persistence for the local high-score table.
@export var save_path := AppConstants.HIGHSCORE_FILE
@export_range(1, 1000, 1) var max_scores := AppConstants.MAX_HIGH_SCORES

func load_high_scores_by_mode() -> Dictionary:
	var tables := empty_score_tables()
	if not FileAccess.file_exists(save_path):
		return tables
	
	var file := FileAccess.open(save_path, FileAccess.READ)
	if not file:
		return tables
	
	var loaded = file.get_var()
	# Array-only and v1 documents predate modes, so their scores belong to Classic.
	if loaded is Array:
		tables[GameMode.key(GameMode.Value.CLASSIC)] = _sanitize_untyped_scores(loaded)
	elif loaded is Dictionary and loaded.has("version"):
		var version = loaded.get("version", 0)
		match version:
			1:
				var legacy_scores = loaded.get("scores", [])
				if legacy_scores is Array:
					tables[GameMode.key(GameMode.Value.CLASSIC)] = _sanitize_untyped_scores(legacy_scores)
			2:
				var stored_tables = loaded.get("scores_by_mode", {})
				if not stored_tables is Dictionary:
					return tables
				for mode in GameMode.ALL:
					var mode_key := GameMode.key(mode)
					var scores = stored_tables.get(mode_key, [])
					if scores is Array:
						tables[mode_key] = _sanitize_untyped_scores(scores)
			_:
				return tables
	else:
		return tables
	return tables

func save_high_scores_by_mode(score_tables: Dictionary) -> void:
	var sanitized_tables := empty_score_tables()
	for mode in GameMode.ALL:
		var mode_key := GameMode.key(mode)
		var scores = score_tables.get(mode_key, [])
		if scores is Array:
			sanitized_tables[mode_key] = _sanitize_untyped_scores(scores)
	var save_data = {
		"version": SAVE_VERSION,
		"scores_by_mode": sanitized_tables,
	}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_var(save_data)

## Compatibility helpers keep older callers focused on the Classic table.
func load_high_scores() -> Array[int]:
	return load_high_scores_for_mode(GameMode.Value.CLASSIC)

func load_high_scores_for_mode(mode: GameMode.Value) -> Array[int]:
	var tables := load_high_scores_by_mode()
	return tables[GameMode.key(mode)].duplicate()

func save_high_scores(scores: Array[int]) -> void:
	var tables := load_high_scores_by_mode()
	tables[GameMode.key(GameMode.Value.CLASSIC)] = sanitize_high_scores(scores)
	save_high_scores_by_mode(tables)

func empty_score_tables() -> Dictionary:
	var tables := {}
	for mode in GameMode.ALL:
		tables[GameMode.key(mode)] = [] as Array[int]
	return tables

func sanitize_high_scores(scores: Array[int]) -> Array[int]:
	var cleaned_scores: Array[int] = []
	for score in scores:
		if score > 0:
			cleaned_scores.append(score)
	
	cleaned_scores.sort_custom(func(a: int, b: int): return a > b)
	if cleaned_scores.size() > max_scores:
		cleaned_scores.resize(max_scores)
	
	return cleaned_scores

func _sanitize_untyped_scores(scores: Array) -> Array[int]:
	var typed_scores: Array[int] = []
	for value in scores:
		if value is int and value > 0:
			typed_scores.append(value)
	return sanitize_high_scores(typed_scores)
