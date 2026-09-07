class_name TestFiles
extends RefCounted

## Each test process owns a disposable directory; never use player save paths.
var directory := "user://test_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]

func _init() -> void:
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	assert(error == OK, "Could not create test directory.")

func path(filename: String) -> String:
	return directory.path_join(filename)

func cleanup() -> void:
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path(filename)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))
