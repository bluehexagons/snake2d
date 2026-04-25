extends RefCounted

const ConfigData = preload("res://autoload/config.gd")
const SAVE_VERSION := 1

static func load_high_scores() -> Array[int]:
	if not FileAccess.file_exists(ConfigData.HIGHSCORE_FILE):
		return []
	
	var file := FileAccess.open(ConfigData.HIGHSCORE_FILE, FileAccess.READ)
	if not file:
		return []
	
	var loaded = file.get_var()
	var parsed_scores: Array[int] = []
	
	if loaded is Array:
		for value in loaded:
			if value is int and value > 0:
				parsed_scores.append(value)
	elif loaded is Dictionary and loaded.has("version"):
		var version = loaded.get("version", 0)
		match version:
			1:
				var scores = loaded.get("scores", [])
				if scores is Array:
					for value in scores:
						if value is int and value > 0:
							parsed_scores.append(value)
			_:
				return []
	else:
		return []
	
	return sanitize_high_scores(parsed_scores)

static func save_high_scores(scores: Array[int]) -> void:
	var sanitized = sanitize_high_scores(scores)
	var save_data = {
		"version": SAVE_VERSION,
		"scores": sanitized
	}
	var file := FileAccess.open(ConfigData.HIGHSCORE_FILE, FileAccess.WRITE)
	if file:
		file.store_var(save_data)

static func sanitize_high_scores(scores: Array[int]) -> Array[int]:
	var cleaned_scores: Array[int] = []
	for score in scores:
		if score > 0:
			cleaned_scores.append(score)
	
	cleaned_scores.sort_custom(func(a: int, b: int): return a > b)
	if cleaned_scores.size() > ConfigData.MAX_HIGH_SCORES:
		cleaned_scores.resize(ConfigData.MAX_HIGH_SCORES)
	
	return cleaned_scores
