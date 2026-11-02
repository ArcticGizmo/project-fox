class_name SavedPickup
extends Node3D
## Base for level pickups that are taken once per save (Heartspring,
## GlimmerJar). The id is the node's path from its LevelRoot, so keep names
## stable once a level ships. LevelRoot frees the ones the profile has already
## collected and records new ones when `taken` fires.

signal taken(pickup: SavedPickup)

const GROUP := &"saved_pickups"

var is_taken: bool = false


func _enter_tree() -> void:
	add_to_group(GROUP)


## What the pause menu tallies it as (one id per subclass).
func kind() -> StringName:
	return &"pickup"


func _take() -> void:
	if is_taken:
		return
	is_taken = true
	taken.emit(self)
