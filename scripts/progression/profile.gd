class_name Profile
extends RefCounted
## The saved campaign state (SaveGame.profile): glimmer, owned weapons and their
## levels, unlocked gadgets, Heartsprings, collected level pickups and the last
## checkpoint. Live state stays on the Player; LevelRoot calls apply() on load
## and capture() before every save. Things a level only lends (starting_gadgets,
## lend_all_weapons) are passed to capture() so they are not saved as owned.

const VERSION := 1
## A new save owns these; the rest are bought from a Magpie Peddler.
const STARTER_WEAPONS: Array[StringName] = [&"woodpecker_repeater", &"hornet_swarm", &"pufferfish_mortar"]

var glimmer: int = 0
var owned_weapons: Array[StringName] = STARTER_WEAPONS.duplicate()
## Weapon id -> [level, xp] (owned weapons only).
var weapon_progress: Dictionary = {}
var gadgets: Array[StringName] = []
var heartsprings: int = 0
## Level name (LevelRoot.level_name) -> ids (paths from the level root) of saved
## pickups already taken: Heartsprings and glimmer jars.
var collected: Dictionary = {}
## Scene path and node path (from the level root) of the last lit checkpoint.
var checkpoint_level: String = ""
var checkpoint_node: String = ""


func has_collected(level: String, id: String) -> bool:
	return collected.has(level) and id in (collected[level] as PackedStringArray)


func mark_collected(level: String, id: String) -> void:
	var ids: PackedStringArray = collected.get(level, PackedStringArray())
	if not (id in ids):
		ids.append(id)
	collected[level] = ids


func collected_count(level: String) -> int:
	return (collected.get(level, PackedStringArray()) as PackedStringArray).size()


func set_checkpoint(level_path: String, node_path: String) -> void:
	checkpoint_level = level_path
	checkpoint_node = node_path


func clear_checkpoint() -> void:
	checkpoint_level = ""
	checkpoint_node = ""


## Loads this profile into a freshly built player (before the HUD binds, so it
## raises no popups or sounds).
func apply(player: Player) -> void:
	player.glimmer = glimmer
	player.heartsprings = heartsprings
	player.refresh_max_health()
	player.gadgets.unlocked.clear()
	for id: StringName in gadgets:
		if id in Gadgets.ALL and not player.gadgets.has(id):
			player.gadgets.unlocked.append(id)
	for w: Weapon in player.weapons:
		w.owned = w.data.id in owned_weapons
		var progress: Array = weapon_progress.get(w.data.id, [])
		if w.owned and progress.size() == 2:
			w.set_progress(int(progress[0]), int(progress[1]))
	player.ensure_owned_weapon_selected()


## Copies the player's live state in. `lent_weapons` / `lent_gadgets` are what
## the level handed out for this visit only.
func capture(player: Player, lent_weapons: Array[StringName] = [], lent_gadgets: Array[StringName] = []) -> void:
	glimmer = player.glimmer
	heartsprings = player.heartsprings
	gadgets.clear()
	for id: StringName in player.gadgets.unlocked:
		if not (id in lent_gadgets):
			gadgets.append(id)
	owned_weapons.clear()
	for w: Weapon in player.weapons:
		if w.owned and not (w.data.id in lent_weapons):
			owned_weapons.append(w.data.id)
			weapon_progress[w.data.id] = [w.level, w.xp]


func to_dict() -> Dictionary:
	var progress := {}
	for id: StringName in weapon_progress:
		progress[String(id)] = weapon_progress[id]
	var taken := {}
	for level: String in collected:
		taken[level] = Array(collected[level] as PackedStringArray)
	return {
		"version": VERSION,
		"glimmer": glimmer,
		"owned_weapons": _strings(owned_weapons),
		"weapon_progress": progress,
		"gadgets": _strings(gadgets),
		"heartsprings": heartsprings,
		"collected": taken,
		"checkpoint_level": checkpoint_level,
		"checkpoint_node": checkpoint_node,
	}


## Missing or malformed fields fall back to a new save's values.
static func from_dict(d: Dictionary) -> Profile:
	var p := Profile.new()
	p.glimmer = maxi(0, int(d.get("glimmer", 0)))
	if d.get("owned_weapons") is Array:
		p.owned_weapons = _names(d["owned_weapons"] as Array)
	if d.get("weapon_progress") is Dictionary:
		var progress := d["weapon_progress"] as Dictionary
		for id: String in progress:
			var v: Variant = progress[id]
			if v is Array and (v as Array).size() == 2:
				p.weapon_progress[StringName(id)] = [int((v as Array)[0]), int((v as Array)[1])]
	if d.get("gadgets") is Array:
		p.gadgets = _names(d["gadgets"] as Array)
	p.heartsprings = maxi(0, int(d.get("heartsprings", 0)))
	if d.get("collected") is Dictionary:
		var taken := d["collected"] as Dictionary
		for level: String in taken:
			if taken[level] is Array:
				p.collected[level] = PackedStringArray(taken[level] as Array)
	p.checkpoint_level = str(d.get("checkpoint_level", ""))
	p.checkpoint_node = str(d.get("checkpoint_node", ""))
	return p


static func _strings(ids: Array[StringName]) -> Array:
	var out := []
	for id: StringName in ids:
		out.append(String(id))
	return out


static func _names(values: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for v: Variant in values:
		out.append(StringName(str(v)))
	return out
