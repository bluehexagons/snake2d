extends RefCounted

## Publishes a complete save without truncating the current file in place.
const RECOVERY_SUFFIX := ".previous"

static func path_for_read(path: String) -> String:
	var recovery_path := path + RECOVERY_SUFFIX
	if not FileAccess.file_exists(path) and FileAccess.file_exists(recovery_path):
		return recovery_path
	return path

static func write(path: String, data: PackedByteArray) -> Error:
	# Keep the temporary file on the same filesystem as the save.
	var staged_path := "%s.%d.%d.tmp" % [path, OS.get_process_id(), Time.get_ticks_usec()]
	var file := FileAccess.open(staged_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()

	var stored := file.store_buffer(data)
	file.close()
	var error := ERR_FILE_CANT_WRITE
	# The write can succeed in the OS buffer while closing fails to flush it.
	if stored and _matches_written_file(staged_path, data):
		error = _publish(path, staged_path)
	if error != OK:
		DirAccess.remove_absolute(staged_path)
	return error

static func _matches_written_file(path: String, data: PackedByteArray) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	return file != null and file.get_length() == data.size() and file.get_buffer(data.size()) == data

static func _publish(path: String, staged_path: String) -> Error:
	var recovery_path := path + RECOVERY_SUFFIX
	# On Windows, Godot removes an existing destination before renaming. Keep
	# the current save available at the recovery path until publication succeeds.
	if OS.has_feature("windows") and FileAccess.file_exists(path):
		var error := DirAccess.rename_absolute(path, recovery_path)
		if error != OK:
			return error

	var error := DirAccess.rename_absolute(staged_path, path)
	if error == OK and FileAccess.file_exists(recovery_path):
		DirAccess.remove_absolute(recovery_path)
	return error
