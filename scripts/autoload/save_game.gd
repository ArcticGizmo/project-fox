extends Node
## The campaign save (one slot): `profile` plus reading and writing it as JSON
## at `path`. Levels with LevelRoot.uses_save apply it on load and save at
## checkpoints, purchases, pickups, gadget unlocks, respawns and level exits;
## the wave arena never touches it. The test runner and screenshot tool call
## use_memory_only() so they never read or overwrite the player's save.

signal saved

const DEFAULT_PATH := "user://save.json"

var profile: Profile = Profile.new()
var path: String = DEFAULT_PATH
## False: save() only keeps the profile in memory.
var persistent: bool = true


func _ready() -> void:
	load_from_disk()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		var level := get_tree().current_scene as LevelRoot
		if level != null:
			level.save_progress()


## Tests and tools: a fresh in-memory profile, never written to disk.
func use_memory_only() -> void:
	persistent = false
	profile = Profile.new()


func reset() -> void:
	profile = Profile.new()


func load_from_disk() -> void:
	profile = Profile.new()
	if not persistent or not FileAccess.file_exists(path):
		return
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) == OK and json.data is Dictionary:
		profile = Profile.from_dict(json.data as Dictionary)
	else:
		push_warning("SaveGame: %s is unreadable; starting a new save" % path)


func save() -> void:
	if persistent:
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f == null:
			push_warning("SaveGame: could not write %s (%s)" % [path, error_string(FileAccess.get_open_error())])
			return
		f.store_string(JSON.stringify(profile.to_dict(), "\t"))
		f.close()
	saved.emit()


## Deletes the save file and starts over.
func wipe() -> void:
	profile = Profile.new()
	if persistent and FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
