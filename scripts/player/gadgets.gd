class_name Gadgets
extends RefCounted
## The player's gadget registry (Player.gadgets). Gadgets are traversal tools
## unlocked once and kept; gates in levels check `has(id)` (see GadgetGate).

signal unlocked_gadget(id: StringName)

const GRAPPLE := &"grapple"
const GLIDE := &"glide"
const BURROW := &"burrow"
const CONDUIT := &"conduit"
const ALL: Array[StringName] = [GRAPPLE, GLIDE, BURROW, CONDUIT]

var unlocked: Array[StringName] = []


func has(id: StringName) -> bool:
	return id in unlocked


## Returns true if this newly unlocked the gadget. Unknown ids are rejected.
func unlock(id: StringName) -> bool:
	if not (id in ALL):
		push_warning("Unknown gadget id %s" % id)
		return false
	if has(id):
		return false
	unlocked.append(id)
	unlocked_gadget.emit(id)
	return true


func unlock_all() -> void:
	for id: StringName in ALL:
		unlock(id)
