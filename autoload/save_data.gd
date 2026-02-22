extends RefCounted

const ConfigData = preload("res://autoload/config.gd")

static func load_high_scores() -> Array[int]:
	if not FileAccess.file_exists(ConfigData.HIGHSCORE_FILE):
		return []

	var file := FileAccess.open(ConfigData.HIGHSCORE_FILE, FileAccess.READ)
	if not file:
		return []

	var loaded_scores = file.get_var()
	if loaded_scores is not Array:
		return []

	var parsed_scores: Array[int] = []
	for value in loaded_scores:
		if value is int and value > 0:
			parsed_scores.append(value)

	return sanitize_high_scores(parsed_scores)

static func save_high_scores(scores: Array[int]) -> void:
	var file := FileAccess.open(ConfigData.HIGHSCORE_FILE, FileAccess.WRITE)
	if file:
		file.store_var(sanitize_high_scores(scores))

static func sanitize_high_scores(scores: Array[int]) -> Array[int]:
	var cleaned_scores: Array[int] = []
	for score in scores:
		if score > 0:
			cleaned_scores.append(score)

	cleaned_scores.sort_custom(func(a: int, b: int): return a > b)
	if cleaned_scores.size() > ConfigData.MAX_HIGH_SCORES:
		cleaned_scores.resize(ConfigData.MAX_HIGH_SCORES)

	return cleaned_scores
