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
const NAMES: Dictionary = {
	GRAPPLE: "Brass Grapple-Tail",
	GLIDE: "Leaf-wing Cloak",
	BURROW: "Burrow Claws",
	CONDUIT: "Copper Conduit Gauntlet",
}
## Short labels for the HUD gadget bar.
const SHORT_NAMES: Dictionary = {GRAPPLE: "Grapple", GLIDE: "Glide", BURROW: "Burrow", CONDUIT: "Conduit"}
## How to use it, shown when it unlocks.
const HINTS: Dictionary = {
	GRAPPLE: "In the air, dodge at a highlighted brass ring",
	GLIDE: "After the double jump, hold jump to glide",
	BURROW: "Dodge onto soil to dig in",
	CONDUIT: "Staff a live barrier to charge, then a dead terminal to power it",
}

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
